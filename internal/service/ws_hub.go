package service

import (
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

// lockedConn serialises all data-frame writes to a single websocket.Conn.
// gorilla/websocket requires that at most one goroutine calls WriteMessage /
// WriteJSON at a time.  Control frames (WriteControl) are explicitly safe for
// concurrent use and bypass this lock.
type lockedConn struct {
	mu   sync.Mutex
	conn *websocket.Conn
}

func (lc *lockedConn) WriteMessage(messageType int, data []byte) error {
	lc.mu.Lock()
	defer lc.mu.Unlock()
	return lc.conn.WriteMessage(messageType, data)
}

func (lc *lockedConn) WriteJSON(v any) error {
	lc.mu.Lock()
	defer lc.mu.Unlock()
	return lc.conn.WriteJSON(v)
}

type clientConn struct {
	ID                       uuid.UUID
	MasterID                 uuid.UUID
	MasterSignKeyFingerprint string
	conn                     *lockedConn
}

type machineConn struct {
	ID       uuid.UUID
	MasterID uuid.UUID
	Hostname string
	conn     *lockedConn
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

func (h *WSHub) RegisterClient(id uuid.UUID, masterID uuid.UUID, fingerprint string, conn *lockedConn) {
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

func (h *WSHub) RegisterMachine(id uuid.UUID, masterID uuid.UUID, hostname string, conn *lockedConn) {
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

func (h *WSHub) GetClientsByMasterID(masterID uuid.UUID) []*clientConn {
	h.mu.RLock()
	defer h.mu.RUnlock()
	var result []*clientConn
	for _, c := range h.clients {
		if c.MasterID == masterID {
			result = append(result, c)
		}
	}
	return result
}
