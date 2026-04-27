package agentchat

import (
	"context"
	"errors"
	"sync"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	"github.com/LaLanMo/muxagent/cli/internal/domain"
	"github.com/LaLanMo/muxagent/cli/internal/sessionattach"
	"github.com/LaLanMo/muxagent/cli/internal/worktree"
)

var ErrEventTransportUnavailable = errors.New("event transport unavailable")

type EventTransport interface {
	DeliverEvent(event appwire.Event) error
	DeliverLiveEvent(event appwire.Event) error
}

type Config struct {
	Context              context.Context
	MachineID            string
	Runtime              Runtime
	EventBuffer          *EventBuffer
	WorktreeStore        *worktree.Store
	Transport            EventTransport
	AttachRegistry       *sessionattach.Registry
	SessionCWD           map[string]string
	SessionStatus        map[string]domain.SessionStatus
	IgnoreTransportError func(error) bool
}

type Service struct {
	machineID string
	runtime   Runtime

	transport      EventTransport
	eventBuf       *EventBuffer
	wtStore        *worktree.Store
	attachRegistry *sessionattach.Registry

	ignoreTransportError func(error) bool

	ctx    context.Context
	cancel context.CancelFunc
	bgMu   sync.Mutex
	closed bool
	bgWG   sync.WaitGroup

	sessionCWDMu sync.RWMutex
	sessionCWD   map[string]string

	statusMu      sync.RWMutex
	sessionStatus map[string]domain.SessionStatus

	mutationMu    sync.Mutex
	sessionMutate map[string]*sync.Mutex
}

func New(cfg Config) *Service {
	baseCtx := cfg.Context
	if baseCtx == nil {
		baseCtx = context.Background()
	}
	serviceCtx, cancel := context.WithCancel(baseCtx)
	sessionCWD := cfg.SessionCWD
	if sessionCWD == nil {
		sessionCWD = make(map[string]string)
	}
	sessionStatus := cfg.SessionStatus
	if sessionStatus == nil {
		sessionStatus = make(map[string]domain.SessionStatus)
	}
	return &Service{
		machineID:            cfg.MachineID,
		runtime:              cfg.Runtime,
		transport:            cfg.Transport,
		eventBuf:             cfg.EventBuffer,
		wtStore:              cfg.WorktreeStore,
		attachRegistry:       cfg.AttachRegistry,
		ignoreTransportError: cfg.IgnoreTransportError,
		ctx:                  serviceCtx,
		cancel:               cancel,
		sessionCWD:           sessionCWD,
		sessionStatus:        sessionStatus,
		sessionMutate:        make(map[string]*sync.Mutex),
	}
}

func (s *Service) Close(ctx context.Context) error {
	if s == nil {
		return nil
	}
	s.bgMu.Lock()
	if !s.closed {
		s.closed = true
		if s.cancel != nil {
			s.cancel()
		}
	}
	s.bgMu.Unlock()

	done := make(chan struct{})
	go func() {
		s.bgWG.Wait()
		close(done)
	}()
	if ctx == nil {
		<-done
		return nil
	}
	select {
	case <-done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (s *Service) startBackground(fn func(context.Context)) bool {
	if s == nil || fn == nil {
		return false
	}
	s.bgMu.Lock()
	defer s.bgMu.Unlock()
	if s.closed {
		return false
	}
	ctx := s.ctx
	if ctx == nil {
		ctx = context.Background()
	}
	s.bgWG.Add(1)
	go func() {
		defer s.bgWG.Done()
		fn(ctx)
	}()
	return true
}

func (s *Service) withSessionMutation(sessionID string, fn func() (any, string)) (any, string) {
	if s == nil || fn == nil || sessionID == "" {
		if fn == nil {
			return nil, "mutation unavailable"
		}
		return fn()
	}
	lock := s.sessionMutationLock(sessionID)
	lock.Lock()
	defer lock.Unlock()
	return fn()
}

func (s *Service) sessionMutationLock(sessionID string) *sync.Mutex {
	s.mutationMu.Lock()
	defer s.mutationMu.Unlock()
	if s.sessionMutate == nil {
		s.sessionMutate = make(map[string]*sync.Mutex)
	}
	lock := s.sessionMutate[sessionID]
	if lock == nil {
		lock = &sync.Mutex{}
		s.sessionMutate[sessionID] = lock
	}
	return lock
}

func (s *Service) MachineID() string {
	if s == nil {
		return ""
	}
	return s.machineID
}

func (s *Service) EventBuffer() *EventBuffer {
	if s == nil {
		return nil
	}
	return s.eventBuf
}

func (s *Service) WorktreeStore() *worktree.Store {
	if s == nil {
		return nil
	}
	return s.wtStore
}

func (s *Service) SetSessionCWD(sessionID, cwd string) {
	if s == nil || sessionID == "" {
		return
	}
	s.sessionCWDMu.Lock()
	defer s.sessionCWDMu.Unlock()
	if s.sessionCWD == nil {
		s.sessionCWD = make(map[string]string)
	}
	s.sessionCWD[sessionID] = cwd
}

func (s *Service) SessionCWD(sessionID string) (string, bool) {
	if s == nil || sessionID == "" {
		return "", false
	}
	s.sessionCWDMu.RLock()
	defer s.sessionCWDMu.RUnlock()
	cwd, ok := s.sessionCWD[sessionID]
	return cwd, ok
}

func (s *Service) SetSessionStatus(sessionID string, status domain.SessionStatus) {
	if s == nil || sessionID == "" {
		return
	}
	s.statusMu.Lock()
	defer s.statusMu.Unlock()
	if s.sessionStatus == nil {
		s.sessionStatus = make(map[string]domain.SessionStatus)
	}
	s.sessionStatus[sessionID] = status
}

func (s *Service) EnsureSessionStatus(sessionID string, status domain.SessionStatus) {
	if s == nil || sessionID == "" {
		return
	}
	s.statusMu.Lock()
	defer s.statusMu.Unlock()
	if s.sessionStatus == nil {
		s.sessionStatus = make(map[string]domain.SessionStatus)
	}
	if _, ok := s.sessionStatus[sessionID]; ok {
		return
	}
	s.sessionStatus[sessionID] = status
}

func (s *Service) ResolvedSessionStatus(sessionID string) domain.SessionStatus {
	if s == nil {
		return domain.SessionStatusIdle
	}
	s.statusMu.RLock()
	defer s.statusMu.RUnlock()
	if status, ok := s.sessionStatus[sessionID]; ok {
		return status
	}
	return domain.SessionStatusIdle
}

func (s *Service) ClearSessionStatus(sessionID string) {
	if s == nil || sessionID == "" {
		return
	}
	s.statusMu.Lock()
	defer s.statusMu.Unlock()
	delete(s.sessionStatus, sessionID)
}

func (s *Service) SendEvent(event appwire.Event) error {
	if s == nil {
		return ErrEventTransportUnavailable
	}
	s.applyEventStatus(event)
	event = NormalizeEventForTransport(event)
	if s.eventBuf != nil {
		event = s.eventBuf.Push(event)
	}
	if s.transport == nil {
		return ErrEventTransportUnavailable
	}
	return s.transport.DeliverEvent(event)
}

func (s *Service) SendLiveEvent(event appwire.Event) error {
	if s == nil {
		return ErrEventTransportUnavailable
	}
	event = NormalizeEventForTransport(event)
	if s.transport == nil {
		return ErrEventTransportUnavailable
	}
	if err := s.transport.DeliverLiveEvent(event); err != nil {
		return err
	}
	s.applyEventStatus(event)
	return nil
}

func (s *Service) applyEventStatus(event appwire.Event) {
	if event.SessionID == "" {
		return
	}
	switch event.Type {
	case appwire.EventSessionStatus:
		if event.SessionInfo != nil {
			s.SetSessionStatus(event.SessionID, domain.SessionStatus(event.SessionInfo.App.Status))
		}
	}
}
