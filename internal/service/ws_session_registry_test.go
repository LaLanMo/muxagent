package service

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestSessionRegistry_BeginSession(t *testing.T) {
	machineID := uuid.New()
	clientID := uuid.New()

	tests := []struct {
		name      string
		seedEntry *sessionEntry
		wantErr   error
	}{
		{
			name:    "empty",
			wantErr: nil,
		},
		{
			name: "busy active",
			seedEntry: &sessionEntry{
				clientID:  uuid.New(),
				state:     sessionStateActive,
				createdAt: time.Now().Add(-2 * pendingSessionTTL),
			},
			wantErr: ErrMachineBusy,
		},
		{
			name: "expired pending replaced",
			seedEntry: &sessionEntry{
				clientID:  uuid.New(),
				state:     sessionStatePending,
				createdAt: time.Now().Add(-2 * pendingSessionTTL),
			},
			wantErr: nil,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			reg := NewSessionRegistry()
			if tt.seedEntry != nil {
				reg.machineToClient[machineID] = *tt.seedEntry
			}
			err := reg.BeginSession(machineID, clientID, false)
			if tt.wantErr != nil {
				require.Error(t, err)
				assert.ErrorIs(t, err, tt.wantErr)
				return
			}
			require.NoError(t, err)
			entry, ok := reg.machineToClient[machineID]
			require.True(t, ok)
			assert.Equal(t, clientID, entry.clientID)
			assert.Equal(t, sessionStatePending, entry.state)
		})
	}
}

func TestSessionRegistry_ActivateAndGet(t *testing.T) {
	machineID := uuid.New()
	clientID := uuid.New()

	tests := []struct {
		name         string
		seedEntry    sessionEntry
		activateErr  error
		activeClient bool
		getClientOK  bool
	}{
		{
			name: "activate pending",
			seedEntry: sessionEntry{
				clientID:  clientID,
				state:     sessionStatePending,
				createdAt: time.Now(),
			},
			activateErr:  nil,
			activeClient: true,
			getClientOK:  true,
		},
		{
			name: "activate expired pending",
			seedEntry: sessionEntry{
				clientID:  clientID,
				state:     sessionStatePending,
				createdAt: time.Now().Add(-2 * pendingSessionTTL),
			},
			activateErr:  ErrUnauthorizedSession,
			activeClient: false,
			getClientOK:  false,
		},
		{
			name: "active not expired",
			seedEntry: sessionEntry{
				clientID:  clientID,
				state:     sessionStateActive,
				createdAt: time.Now().Add(-2 * pendingSessionTTL),
			},
			activateErr:  nil,
			activeClient: true,
			getClientOK:  true,
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			reg := NewSessionRegistry()
			reg.machineToClient[machineID] = tt.seedEntry

			err := reg.ActivateSession(machineID)
			if tt.activateErr != nil {
				require.Error(t, err)
				assert.ErrorIs(t, err, tt.activateErr)
			} else {
				require.NoError(t, err)
			}

			_, ok := reg.GetActiveSessionClient(machineID)
			assert.Equal(t, tt.activeClient, ok)
			_, ok = reg.GetSessionClient(machineID)
			assert.Equal(t, tt.getClientOK, ok)
		})
	}
}

func TestSessionRegistry_BeginSession_ForceReplace(t *testing.T) {
	machineID := uuid.New()
	oldClient := uuid.New()
	newClient := uuid.New()

	reg := NewSessionRegistry()
	require.NoError(t, reg.BeginSession(machineID, oldClient, false))
	require.NoError(t, reg.ActivateSession(machineID))

	// Without force: busy
	require.ErrorIs(t, reg.BeginSession(machineID, newClient, false), ErrMachineBusy)

	// With force: replaces
	require.NoError(t, reg.BeginSession(machineID, newClient, true))
	entry, ok := reg.machineToClient[machineID]
	require.True(t, ok)
	assert.Equal(t, newClient, entry.clientID)
	assert.Equal(t, sessionStatePending, entry.state)
}

func TestSessionRegistry_EndSessionsForClient(t *testing.T) {
	reg := NewSessionRegistry()
	clientID := uuid.New()
	otherID := uuid.New()

	machineA := uuid.New()
	machineB := uuid.New()
	machineC := uuid.New()

	reg.machineToClient[machineA] = sessionEntry{clientID: clientID, state: sessionStatePending, createdAt: time.Now()}
	reg.machineToClient[machineB] = sessionEntry{clientID: clientID, state: sessionStateActive, createdAt: time.Now()}
	reg.machineToClient[machineC] = sessionEntry{clientID: otherID, state: sessionStateActive, createdAt: time.Now()}

	reg.EndSessionsForClient(clientID)

	_, ok := reg.machineToClient[machineA]
	assert.False(t, ok)
	_, ok = reg.machineToClient[machineB]
	assert.False(t, ok)
	_, ok = reg.machineToClient[machineC]
	assert.True(t, ok)
}
