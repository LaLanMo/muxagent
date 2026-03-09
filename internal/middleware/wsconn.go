package middleware

import (
	"errors"
	"sync"
)

// WSConnLimiter tracks active WebSocket connections per IP and globally.
type WSConnLimiter struct {
	mu       sync.Mutex
	perIP    map[string]int
	total    int
	maxPerIP int
	maxTotal int
}

func NewWSConnLimiter(maxPerIP, maxTotal int) *WSConnLimiter {
	return &WSConnLimiter{
		perIP:    make(map[string]int),
		maxPerIP: maxPerIP,
		maxTotal: maxTotal,
	}
}

// Acquire increments the connection count for ip. Returns an error if either
// the per-IP or global limit would be exceeded.
func (l *WSConnLimiter) Acquire(ip string) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.total >= l.maxTotal {
		return errors.New("too many WebSocket connections")
	}
	if l.perIP[ip] >= l.maxPerIP {
		return errors.New("too many WebSocket connections from this IP")
	}
	l.perIP[ip]++
	l.total++
	return nil
}

// Release decrements the connection count for ip.
func (l *WSConnLimiter) Release(ip string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.perIP[ip] > 0 {
		l.perIP[ip]--
		if l.perIP[ip] == 0 {
			delete(l.perIP, ip)
		}
	}
	if l.total > 0 {
		l.total--
	}
}
