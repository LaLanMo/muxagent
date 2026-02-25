package service

import (
	"sync"
	"time"

	"github.com/google/uuid"
)

const pendingSessionTTL = 30 * time.Second

type SessionRegistry struct {
	mu              sync.RWMutex
	machineToClient map[uuid.UUID]sessionEntry
}

func NewSessionRegistry() *SessionRegistry {
	return &SessionRegistry{
		machineToClient: make(map[uuid.UUID]sessionEntry),
	}
}

func (r *SessionRegistry) BeginSession(machineID uuid.UUID, clientID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	entry, exists := r.machineToClient[machineID]
	if exists {
		if r.isExpired(entry) {
			delete(r.machineToClient, machineID)
		} else {
			return ErrMachineBusy
		}
	}
	r.machineToClient[machineID] = sessionEntry{clientID: clientID, state: sessionStatePending, createdAt: time.Now()}
	return nil
}

func (r *SessionRegistry) ActivateSession(machineID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	entry, exists := r.machineToClient[machineID]
	if !exists {
		return ErrUnauthorizedSession
	}
	if r.isExpired(entry) {
		delete(r.machineToClient, machineID)
		return ErrUnauthorizedSession
	}
	entry.state = sessionStateActive
	r.machineToClient[machineID] = entry
	return nil
}

func (r *SessionRegistry) EndSession(machineID uuid.UUID) {
	r.mu.Lock()
	delete(r.machineToClient, machineID)
	r.mu.Unlock()
}

func (r *SessionRegistry) EndSessionsForClient(clientID uuid.UUID) {
	r.mu.Lock()
	for machineID, entry := range r.machineToClient {
		if entry.clientID == clientID {
			delete(r.machineToClient, machineID)
		}
	}
	r.mu.Unlock()
}

func (r *SessionRegistry) GetSessionClient(machineID uuid.UUID) (uuid.UUID, bool) {
	r.mu.RLock()
	entry, ok := r.machineToClient[machineID]
	r.mu.RUnlock()
	if !ok {
		return uuid.UUID{}, false
	}
	if r.isExpired(entry) {
		r.EndSession(machineID)
		return uuid.UUID{}, false
	}
	return entry.clientID, true
}

func (r *SessionRegistry) GetActiveSessionClient(machineID uuid.UUID) (uuid.UUID, bool) {
	r.mu.RLock()
	entry, ok := r.machineToClient[machineID]
	r.mu.RUnlock()
	if !ok || entry.state != sessionStateActive {
		return uuid.UUID{}, false
	}
	if r.isExpired(entry) {
		r.EndSession(machineID)
		return uuid.UUID{}, false
	}
	return entry.clientID, true
}

func (r *SessionRegistry) isExpired(entry sessionEntry) bool {
	if entry.state != sessionStatePending {
		return false
	}
	return time.Since(entry.createdAt) > pendingSessionTTL
}

type sessionState int

const (
	sessionStatePending sessionState = iota
	sessionStateActive
)

type sessionEntry struct {
	clientID  uuid.UUID
	state     sessionState
	createdAt time.Time
}
