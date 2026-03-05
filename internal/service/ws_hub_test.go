package service

import (
	"testing"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
)

func TestWSHub_RegisterGetUnregister(t *testing.T) {
	tests := []struct {
		name string
		run  func(t *testing.T, hub *WSHub)
	}{
		{
			name: "client lifecycle",
			run: func(t *testing.T, hub *WSHub) {
				clientID := uuid.New()
				masterID := uuid.New()
				hub.RegisterClient(clientID, masterID, "fp", &lockedConn{conn: &websocket.Conn{}})
				client, ok := hub.GetClient(clientID)
				assert.True(t, ok)
				assert.Equal(t, clientID, client.ID)
				hub.UnregisterClient(clientID)
				_, ok = hub.GetClient(clientID)
				assert.False(t, ok)
			},
		},
		{
			name: "machine lifecycle",
			run: func(t *testing.T, hub *WSHub) {
				machineID := uuid.New()
				masterID := uuid.New()
				hub.RegisterMachine(machineID, masterID, "host", &lockedConn{conn: &websocket.Conn{}})
				machine, ok := hub.GetMachine(machineID)
				assert.True(t, ok)
				assert.Equal(t, machineID, machine.ID)
				hub.UnregisterMachine(machineID)
				_, ok = hub.GetMachine(machineID)
				assert.False(t, ok)
			},
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			hub := NewWSHub()
			tt.run(t, hub)
		})
	}
}
