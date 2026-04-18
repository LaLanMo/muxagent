package daemon

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/config"
	"github.com/LaLanMo/muxagent/cli/internal/control"
	"github.com/spf13/cobra"
)

func newAttachSessionCmd() *cobra.Command {
	var runtimeID string

	cmd := &cobra.Command{
		Use:   "attach-session <session-id>",
		Short: "Attach a local runtime session so mobile can continue it",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			state, err := config.LoadState()
			if err != nil {
				if os.IsNotExist(err) {
					return fmt.Errorf("daemon is not running (no state file)")
				}
				return err
			}
			if state.PID > 0 && !isProcessAlive(state.PID) {
				return fmt.Errorf("daemon is not running (stale state, pid %d dead)", state.PID)
			}

			req := control.AttachSessionRequest{
				SessionID: args[0],
				Runtime:   runtimeID,
			}
			resp, err := sendAttachSessionRequest(
				context.Background(),
				state,
				req,
				&http.Client{Timeout: 30 * time.Second},
			)
			if err != nil {
				return err
			}

			fmt.Fprintf(cmd.OutOrStdout(), "Attached session %s\n", resp.SessionID)
			fmt.Fprintf(cmd.OutOrStdout(), "Runtime: %s\n", resp.Runtime)
			fmt.Fprintf(cmd.OutOrStdout(), "CWD: %s\n", resp.CWD)
			if strings.TrimSpace(resp.Title) != "" {
				fmt.Fprintf(cmd.OutOrStdout(), "Title: %s\n", resp.Title)
			}
			fmt.Fprintf(cmd.OutOrStdout(), "Status: %s\n", resp.Status)
			return nil
		},
	}

	cmd.Flags().StringVar(&runtimeID, "runtime", "", "Runtime that owns the session to attach")
	_ = cmd.MarkFlagRequired("runtime")
	return cmd
}

func sendAttachSessionRequest(
	ctx context.Context,
	state config.DaemonState,
	req control.AttachSessionRequest,
	client *http.Client,
) (control.AttachSessionResponse, error) {
	token, err := state.GetToken()
	if err != nil {
		return control.AttachSessionResponse{}, fmt.Errorf("daemon has incompatible state format, run: muxagent daemon stop and follow its output")
	}
	return sendAttachSessionRequestWithToken(
		ctx,
		state.Address,
		token,
		req,
		client,
	)
}

func sendAttachSessionRequestWithToken(
	ctx context.Context,
	address string,
	token string,
	req control.AttachSessionRequest,
	client *http.Client,
) (control.AttachSessionResponse, error) {
	body, err := json.Marshal(req)
	if err != nil {
		return control.AttachSessionResponse{}, err
	}
	httpReq, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		fmt.Sprintf("http://%s/remote/attach-session", address),
		bytes.NewReader(body),
	)
	if err != nil {
		return control.AttachSessionResponse{}, err
	}
	httpReq.Header.Set("Authorization", "Bearer "+token)
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(httpReq)
	if err != nil {
		return control.AttachSessionResponse{}, err
	}
	defer resp.Body.Close()

	var failure struct {
		Error string `json:"error"`
	}
	if resp.StatusCode != http.StatusOK {
		if err := json.NewDecoder(resp.Body).Decode(&failure); err == nil && strings.TrimSpace(failure.Error) != "" {
			return control.AttachSessionResponse{}, errors.New(failure.Error)
		}
		return control.AttachSessionResponse{}, fmt.Errorf("attach-session failed: %s", resp.Status)
	}

	var decoded control.AttachSessionResponse
	if err := json.NewDecoder(resp.Body).Decode(&decoded); err != nil {
		return control.AttachSessionResponse{}, fmt.Errorf("decode attach response: %w", err)
	}
	if !decoded.OK {
		return control.AttachSessionResponse{}, fmt.Errorf("attach-session was not acknowledged")
	}
	return decoded, nil
}
