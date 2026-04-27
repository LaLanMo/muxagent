package appserver

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/config"
)

type agentChatClient interface {
	Call(ctx context.Context, req appwire.RPCRequest) (appwire.RPCResponse, error)
	Subscribe(ctx context.Context, streamEpoch, afterSeq uint64) (<-chan appwire.EventStreamItem, error)
}

type daemonAgentChatClient struct {
	httpClient *http.Client
	loadState  func() (config.DaemonState, error)
}

const agentChatDaemonProbeTimeout = 750 * time.Millisecond

const (
	agentChatEventReconnectInitialBackoff = 100 * time.Millisecond
	agentChatEventReconnectMaxBackoff     = 5 * time.Second
)

func newDaemonAgentChatClient() *daemonAgentChatClient {
	return &daemonAgentChatClient{
		httpClient: &http.Client{Timeout: 30 * time.Second},
		loadState:  config.LoadState,
	}
}

func (c *daemonAgentChatClient) Call(ctx context.Context, req appwire.RPCRequest) (appwire.RPCResponse, error) {
	state, token, err := c.daemonAccess(ctx)
	if err != nil {
		return appwire.RPCResponse{}, err
	}
	body, err := json.Marshal(req)
	if err != nil {
		return appwire.RPCResponse{}, err
	}
	httpReq, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		fmt.Sprintf("http://%s/agentchat/rpc", state.Address),
		bytes.NewReader(body),
	)
	if err != nil {
		return appwire.RPCResponse{}, err
	}
	httpReq.Header.Set("Authorization", "Bearer "+token)
	httpReq.Header.Set("Content-Type", "application/json")

	client := c.httpClient
	if client == nil {
		client = http.DefaultClient
	}
	resp, err := client.Do(httpReq)
	if err != nil {
		return appwire.RPCResponse{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return appwire.RPCResponse{}, decodeControlError(resp, "agentchat rpc")
	}
	var decoded appwire.RPCResponse
	if err := json.NewDecoder(resp.Body).Decode(&decoded); err != nil {
		return appwire.RPCResponse{}, fmt.Errorf("decode agentchat rpc response: %w", err)
	}
	return decoded, nil
}

func (c *daemonAgentChatClient) Subscribe(ctx context.Context, streamEpoch, afterSeq uint64) (<-chan appwire.EventStreamItem, error) {
	state, token, err := c.daemonAccess(ctx)
	if err != nil {
		return nil, err
	}
	values := url.Values{}
	if streamEpoch != 0 {
		values.Set("streamEpoch", strconv.FormatUint(streamEpoch, 10))
	}
	if afterSeq != 0 {
		values.Set("afterSeq", strconv.FormatUint(afterSeq, 10))
	}
	endpoint := fmt.Sprintf("http://%s/agentchat/events", state.Address)
	if encoded := values.Encode(); encoded != "" {
		endpoint += "?" + encoded
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Authorization", "Bearer "+token)

	client := c.httpClient
	if client == nil {
		client = http.DefaultClient
	}
	streamClient := *client
	streamClient.Timeout = 0
	resp, err := streamClient.Do(httpReq)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		defer resp.Body.Close()
		return nil, decodeControlError(resp, "agentchat events")
	}

	items := make(chan appwire.EventStreamItem, 128)
	go func() {
		defer close(items)
		defer resp.Body.Close()

		scanner := bufio.NewScanner(resp.Body)
		scanner.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
		for scanner.Scan() {
			item, ok := decodeAgentChatStreamItem(scanner.Bytes())
			if !ok {
				continue
			}
			select {
			case items <- item:
			case <-ctx.Done():
				return
			}
		}
	}()
	return items, nil
}

func decodeAgentChatStreamItem(raw []byte) (appwire.EventStreamItem, bool) {
	var item appwire.EventStreamItem
	if err := json.Unmarshal(raw, &item); err == nil && item.Kind != "" {
		return item, true
	}
	return appwire.EventStreamItem{}, false
}

func (c *daemonAgentChatClient) daemonAccess(ctx context.Context) (config.DaemonState, string, error) {
	if c == nil || c.loadState == nil {
		return config.DaemonState{}, "", errors.New("agentchat daemon client unavailable")
	}
	state, err := c.loadState()
	if err != nil {
		return config.DaemonState{}, "", fmt.Errorf("load daemon state: %w", err)
	}
	if strings.TrimSpace(state.Address) == "" {
		return config.DaemonState{}, "", errors.New("daemon address missing")
	}
	token, err := state.GetToken()
	if err != nil {
		return config.DaemonState{}, "", fmt.Errorf("daemon token unavailable: %w", err)
	}
	if err := c.probeDaemon(ctx, state, token); err != nil {
		return config.DaemonState{}, "", fmt.Errorf("daemon unavailable: %w", err)
	}
	return state, token, nil
}

func (c *daemonAgentChatClient) probeDaemon(ctx context.Context, state config.DaemonState, token string) error {
	if ctx == nil {
		ctx = context.Background()
	}
	probeCtx, cancel := context.WithTimeout(ctx, agentChatDaemonProbeTimeout)
	defer cancel()

	req, err := http.NewRequestWithContext(
		probeCtx,
		http.MethodGet,
		fmt.Sprintf("http://%s/health", state.Address),
		nil,
	)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	client := c.httpClient
	if client == nil {
		client = http.DefaultClient
	}
	probeClient := *client
	probeClient.Timeout = agentChatDaemonProbeTimeout
	resp, err := probeClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("health failed: %s", resp.Status)
	}
	var health struct {
		InstanceID string `json:"instance_id"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&health); err != nil {
		return fmt.Errorf("decode health: %w", err)
	}
	if state.InstanceID != "" && health.InstanceID != state.InstanceID {
		return errors.New("daemon instance mismatch")
	}
	return nil
}

func decodeControlError(resp *http.Response, operation string) error {
	var failure struct {
		Error string `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&failure); err == nil && strings.TrimSpace(failure.Error) != "" {
		return fmt.Errorf("%s failed: %s", operation, failure.Error)
	}
	return fmt.Errorf("%s failed: %s", operation, resp.Status)
}

func (s *Server) startAgentChatEventProxy(session *connectionSession) {
	if s == nil || session == nil || s.agentChatClient == nil {
		return
	}
	go func() {
		ctx := session.ctx
		if ctx == nil {
			ctx = context.Background()
		}
		streamEpoch, afterSeq := s.agentChatInitialCursor(ctx, true)
		backoff := agentChatEventReconnectInitialBackoff
		for ctx.Err() == nil {
			items, err := s.agentChatClient.Subscribe(ctx, streamEpoch, afterSeq)
			if err != nil {
				if !sleepContext(ctx, backoff) {
					return
				}
				backoff = min(backoff*2, agentChatEventReconnectMaxBackoff)
				continue
			}
			backoff = agentChatEventReconnectInitialBackoff
			for item := range items {
				if item.StreamEpoch != 0 {
					streamEpoch = item.StreamEpoch
				}
				switch item.Kind {
				case appwire.EventStreamItemReplay:
					afterSeq = item.ReplayedThroughSeq
				case appwire.EventStreamItemEvent:
					if item.Event != nil && item.Event.Seq > afterSeq {
						afterSeq = item.Event.Seq
					}
				default:
					continue
				}
				s.forwardAgentChatStreamItem(session, item)
			}
			if !sleepContext(ctx, backoff) {
				return
			}
			backoff = min(backoff*2, agentChatEventReconnectMaxBackoff)
		}
	}()
}

func (s *Server) forwardAgentChatStreamItem(session *connectionSession, item appwire.EventStreamItem) {
	if session == nil {
		return
	}
	session.enqueueNotification(notification{
		JSONRPC: jsonRPCVersion,
		Method:  notificationAgentChatStreamItem,
		Params:  item,
	})
}

func (s *Server) agentChatInitialCursor(ctx context.Context, replay bool) (uint64, uint64) {
	if s == nil || s.agentChatClient == nil {
		return 0, 0
	}
	resp, err := s.agentChatClient.Call(ctx, appwire.RPCRequest{Method: "events.head"})
	if err != nil || resp.Error != "" || len(resp.Result) == 0 {
		return 0, 0
	}
	var head appwire.ReplayHeadResult
	if err := json.Unmarshal(resp.Result, &head); err != nil {
		return 0, 0
	}
	if replay {
		return head.StreamEpoch, 0
	}
	return head.StreamEpoch, head.ReplayedThroughSeq
}

func sleepContext(ctx context.Context, delay time.Duration) bool {
	timer := time.NewTimer(delay)
	defer timer.Stop()
	select {
	case <-timer.C:
		return true
	case <-ctx.Done():
		return false
	}
}
