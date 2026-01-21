// Package middleware contains HTTP middleware functions.
package middleware

import (
	"net/http"
	"regexp"
	"sync"
	"time"

	"github.com/rs/zerolog/log"
)

// uuidRegex validates UUID format (with or without hyphens).
var uuidRegex = regexp.MustCompile(`^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$`)

// validateDeviceID checks if the device ID is a valid UUID format.
func validateDeviceID(deviceID string) bool {
	return uuidRegex.MatchString(deviceID)
}

// DeviceAuth middleware validates the X-Device-ID header.
func DeviceAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		deviceID := r.Header.Get("X-Device-ID")

		// Allow registration endpoint without device ID validation
		// (since new users won't have registered yet)
		if r.URL.Path == "/api/v1/users/register" && r.Method == "POST" {
			next.ServeHTTP(w, r)
			return
		}

		if deviceID == "" {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			w.Write([]byte(`{"error":{"code":"missing_device_id","message":"X-Device-ID header is required"}}`))
			return
		}

		// Validate device ID format (must be valid UUID)
		if !validateDeviceID(deviceID) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			w.Write([]byte(`{"error":{"code":"invalid_device_id","message":"Device ID must be a valid UUID format"}}`))
			return
		}

		log.Debug().Str("device_id", deviceID).Str("path", r.URL.Path).Msg("Request authenticated")
		next.ServeHTTP(w, r)
	})
}

// rateLimitEntry tracks request counts for rate limiting.
type rateLimitEntry struct {
	count     int
	resetTime time.Time
}

// rateLimiter stores rate limit data per device.
type rateLimiter struct {
	mu      sync.Mutex
	entries map[string]*rateLimitEntry
	limit   int
	window  time.Duration
}

// newRateLimiter creates a new rate limiter.
func newRateLimiter(limit int, window time.Duration) *rateLimiter {
	rl := &rateLimiter{
		entries: make(map[string]*rateLimitEntry),
		limit:   limit,
		window:  window,
	}

	// Start cleanup goroutine
	go rl.cleanup()

	return rl
}

// allow checks if a request should be allowed.
func (rl *rateLimiter) allow(deviceID string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	entry, exists := rl.entries[deviceID]

	if !exists || now.After(entry.resetTime) {
		// New entry or expired, create new
		rl.entries[deviceID] = &rateLimitEntry{
			count:     1,
			resetTime: now.Add(rl.window),
		}
		return true
	}

	if entry.count >= rl.limit {
		return false
	}

	entry.count++
	return true
}

// cleanup removes expired entries periodically.
func (rl *rateLimiter) cleanup() {
	ticker := time.NewTicker(rl.window)
	defer ticker.Stop()

	for range ticker.C {
		rl.mu.Lock()
		now := time.Now()
		for deviceID, entry := range rl.entries {
			if now.After(entry.resetTime) {
				delete(rl.entries, deviceID)
			}
		}
		rl.mu.Unlock()
	}
}

// globalRateLimiter is the shared rate limiter instance.
var globalRateLimiter *rateLimiter

// RateLimiter middleware limits requests per device.
func RateLimiter(requestsPerMinute int) func(http.Handler) http.Handler {
	if globalRateLimiter == nil {
		globalRateLimiter = newRateLimiter(requestsPerMinute, time.Minute)
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			deviceID := r.Header.Get("X-Device-ID")
			if deviceID == "" {
				// If no device ID, use IP address
				deviceID = r.RemoteAddr
			}

			if !globalRateLimiter.allow(deviceID) {
				w.Header().Set("Content-Type", "application/json")
				w.Header().Set("Retry-After", "60")
				w.WriteHeader(http.StatusTooManyRequests)
				w.Write([]byte(`{"error":{"code":"rate_limited","message":"Too many requests. Please wait before trying again."}}`))
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
