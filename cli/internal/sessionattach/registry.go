package sessionattach

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/claudesession"
	"github.com/LaLanMo/muxagent/cli/internal/codexsession"
	"github.com/LaLanMo/muxagent/cli/internal/config"
)

var (
	ErrUnsupportedRuntime = errors.New("runtime does not support local attach-session")
	ErrSessionNotFound    = errors.New("session not found in local runtime transcript store")
	ErrMissingCWD         = errors.New("missing cwd for session attach")
)

type Metadata struct {
	SessionID string
	CWD       string
	Title     string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type Resolver interface {
	ResolveLocalSession(sessionID string) (Metadata, error)
}

type ResolverFunc func(sessionID string) (Metadata, error)

func (f ResolverFunc) ResolveLocalSession(sessionID string) (Metadata, error) {
	return f(sessionID)
}

type Registry struct {
	resolvers map[config.RuntimeID]Resolver
}

func NewRegistry() *Registry {
	r := &Registry{resolvers: make(map[config.RuntimeID]Resolver)}
	r.Register(config.RuntimeClaudeCode, ResolverFunc(resolveClaudeLocalSession))
	r.Register(config.RuntimeCodex, ResolverFunc(resolveCodexLocalSession))
	return r
}

func (r *Registry) Register(runtimeID config.RuntimeID, resolver Resolver) {
	if r == nil || runtimeID == "" || resolver == nil {
		return
	}
	r.resolvers[runtimeID] = resolver
}

func (r *Registry) Resolve(runtimeID string, sessionID string) (Metadata, error) {
	if r == nil {
		return Metadata{}, fmt.Errorf("%w: %s", ErrUnsupportedRuntime, strings.TrimSpace(runtimeID))
	}
	rid := config.RuntimeID(strings.TrimSpace(runtimeID))
	resolver, ok := r.resolvers[rid]
	if !ok {
		return Metadata{}, fmt.Errorf("%w: %s", ErrUnsupportedRuntime, strings.TrimSpace(runtimeID))
	}
	return resolver.ResolveLocalSession(sessionID)
}

func resolveCodexLocalSession(sessionID string) (Metadata, error) {
	meta, err := codexsession.ResolveLocalSession(sessionID)
	if err != nil {
		if errors.Is(err, codexsession.ErrSessionNotFound) {
			return Metadata{}, fmt.Errorf("%w: %v", ErrSessionNotFound, err)
		}
		return Metadata{}, err
	}
	return Metadata{
		SessionID: meta.SessionID,
		CWD:       meta.CWD,
		Title:     meta.Title,
		CreatedAt: meta.CreatedAt,
		UpdatedAt: meta.UpdatedAt,
	}, nil
}

func resolveClaudeLocalSession(sessionID string) (Metadata, error) {
	meta, err := claudesession.ResolveLocalSession(sessionID)
	if err != nil {
		if errors.Is(err, claudesession.ErrSessionNotFound) {
			return Metadata{}, fmt.Errorf("%w: %v", ErrSessionNotFound, err)
		}
		return Metadata{}, err
	}
	return Metadata{
		SessionID: meta.SessionID,
		CWD:       meta.CWD,
		Title:     meta.Title,
		CreatedAt: meta.CreatedAt,
		UpdatedAt: meta.UpdatedAt,
	}, nil
}
