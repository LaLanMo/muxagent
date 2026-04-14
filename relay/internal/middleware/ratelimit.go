package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/LaLanMo/muxagent/relay/internal/errs"
	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

type visitor struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// IPRateLimiter provides per-IP token bucket rate limiting.
type IPRateLimiter struct {
	mu       sync.Mutex
	visitors map[string]*visitor
	rate     rate.Limit
	burst    int
	done     chan struct{}
}

// NewIPRateLimiter creates a rate limiter allowing requestsPerMin requests per
// minute per IP. Burst is set to max(1, requestsPerMin/6) to allow short spikes.
// A background goroutine evicts stale entries every minute.
func NewIPRateLimiter(requestsPerMin int) *IPRateLimiter {
	burst := requestsPerMin / 6
	if burst < 1 {
		burst = 1
	}
	rl := &IPRateLimiter{
		visitors: make(map[string]*visitor),
		rate:     rate.Limit(float64(requestsPerMin) / 60),
		burst:    burst,
		done:     make(chan struct{}),
	}
	go rl.cleanup()
	return rl
}

func (rl *IPRateLimiter) cleanup() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			rl.mu.Lock()
			for ip, v := range rl.visitors {
				if time.Since(v.lastSeen) > 15*time.Minute {
					delete(rl.visitors, ip)
				}
			}
			rl.mu.Unlock()
		case <-rl.done:
			return
		}
	}
}

// Stop terminates the background cleanup goroutine.
func (rl *IPRateLimiter) Stop() {
	close(rl.done)
}

func (rl *IPRateLimiter) getLimiter(ip string) *rate.Limiter {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	v, ok := rl.visitors[ip]
	if !ok {
		v = &visitor{limiter: rate.NewLimiter(rl.rate, rl.burst)}
		rl.visitors[ip] = v
	}
	v.lastSeen = time.Now()
	return v.limiter
}

// rateLimitEnvelope is a minimal response type to avoid importing api (cycle).
type rateLimitEnvelope struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// Middleware returns a Gin middleware that rejects requests exceeding the rate
// limit with 429 + JSON envelope.
func (rl *IPRateLimiter) Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		limiter := rl.getLimiter(c.ClientIP())
		if !limiter.Allow() {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, rateLimitEnvelope{
				Code:    errs.CodeRateLimited,
				Message: "rate limit exceeded",
			})
			return
		}
		c.Next()
	}
}
