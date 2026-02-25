package service

import (
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

type clientConn struct {
	ID                       uuid.UUID
	MasterID                 uuid.UUID
	MasterSignKeyFingerprint string
	conn                     *websocket.Conn
}

type machineConn struct {
	ID       uuid.UUID
	MasterID uuid.UUID
	Hostname string
	conn     *websocket.Conn
}

type WSHub struct {
	mu       sync.RWMutex
	clients  map[uuid.UUID]*clientConn
	machines map[uuid.UUID]*machineConn
}

func NewWSHub() *WSHub {
	return &WSHub{
		clients:  make(map[uuid.UUID]*clientConn),
		machines: make(map[uuid.UUID]*machineConn),
	}
}

func (h *WSHub) RegisterClient(id uuid.UUID, masterID uuid.UUID, fingerprint string, conn *websocket.Conn) {
	h.mu.Lock()
	h.clients[id] = &clientConn{
		ID:                       id,
		MasterID:                 masterID,
		MasterSignKeyFingerprint: fingerprint,
		conn:                     conn,
	}
	h.mu.Unlock()
}

func (h *WSHub) UnregisterClient(id uuid.UUID) {
	h.mu.Lock()
	delete(h.clients, id)
	h.mu.Unlock()
}

func (h *WSHub) RegisterMachine(id uuid.UUID, masterID uuid.UUID, hostname string, conn *websocket.Conn) {
	h.mu.Lock()
	h.machines[id] = &machineConn{
		ID:       id,
		MasterID: masterID,
		Hostname: hostname,
		conn:     conn,
	}
	h.mu.Unlock()
}

func (h *WSHub) UnregisterMachine(id uuid.UUID) {
	h.mu.Lock()
	delete(h.machines, id)
	h.mu.Unlock()
}

func (h *WSHub) GetClient(id uuid.UUID) (*clientConn, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	conn, ok := h.clients[id]
	return conn, ok
}

func (h *WSHub) GetMachine(id uuid.UUID) (*machineConn, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	conn, ok := h.machines[id]
	return conn, ok
}
