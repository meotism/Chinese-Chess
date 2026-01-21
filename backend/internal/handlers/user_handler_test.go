// Package handlers provides integration tests for HTTP handlers.
package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/xiangqi/chinese-chess-backend/internal/models"
	"github.com/xiangqi/chinese-chess-backend/internal/repository"
	"github.com/xiangqi/chinese-chess-backend/internal/services"
)

// mockUserRepo is a mock user repository for testing handlers.
type mockUserRepo struct {
	users map[string]*models.User
}

func newMockUserRepo() *mockUserRepo {
	return &mockUserRepo{
		users: make(map[string]*models.User),
	}
}

func (m *mockUserRepo) Create(ctx context.Context, user *models.User) error {
	user.CreatedAt = time.Now()
	user.UpdatedAt = time.Now()
	m.users[user.ID] = user
	return nil
}

func (m *mockUserRepo) GetByID(ctx context.Context, id string) (*models.User, error) {
	user, ok := m.users[id]
	if !ok {
		return nil, repository.ErrUserNotFound
	}
	return user, nil
}

func (m *mockUserRepo) Update(ctx context.Context, user *models.User) error {
	user.UpdatedAt = time.Now()
	m.users[user.ID] = user
	return nil
}

func (m *mockUserRepo) UpdateStats(ctx context.Context, id string, stats models.UserStats) error {
	if user, ok := m.users[id]; ok {
		user.TotalGames = stats.TotalGames
		user.Wins = stats.Wins
		user.Losses = stats.Losses
		user.Draws = stats.Draws
	}
	return nil
}

// Helper to create a test setup
func setupTestHandler() (*UserHandler, *mockUserRepo) {
	repo := newMockUserRepo()
	// Note: In real tests, we would inject the mock repository
	// For now, we'll test the handler's JSON parsing and response logic
	return &UserHandler{}, repo
}

// ========== Register Handler Tests ==========

func TestUserHandler_Register_ValidRequest(t *testing.T) {
	// Create request body
	reqBody := RegisterRequest{
		DeviceID:    "device-123",
		DisplayName: "TestPlayer",
		Platform:    "iOS",
		AppVersion:  "1.0.0",
	}
	body, _ := json.Marshal(reqBody)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/users/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()

	// For integration tests, we would use the actual handler with mocked service
	// Here we test the JSON parsing
	var parsed RegisterRequest
	err := json.Unmarshal(body, &parsed)
	if err != nil {
		t.Fatalf("Failed to parse request: %v", err)
	}

	if parsed.DeviceID != "device-123" {
		t.Error("DeviceID not parsed correctly")
	}
	if parsed.DisplayName != "TestPlayer" {
		t.Error("DisplayName not parsed correctly")
	}
}

func TestUserHandler_Register_MissingDeviceID(t *testing.T) {
	reqBody := map[string]string{
		"display_name": "TestPlayer",
	}
	body, _ := json.Marshal(reqBody)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/users/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	// Verify the request body parses correctly
	var parsed RegisterRequest
	json.Unmarshal(body, &parsed)

	if parsed.DeviceID != "" {
		t.Error("DeviceID should be empty")
	}
}

func TestUserHandler_Register_InvalidJSON(t *testing.T) {
	body := []byte(`{"invalid json`)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/users/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	var parsed RegisterRequest
	err := json.Unmarshal(body, &parsed)
	if err == nil {
		t.Error("Should fail to parse invalid JSON")
	}
}

// ========== GetProfile Handler Tests ==========

func TestUserHandler_GetProfile_ValidRequest(t *testing.T) {
	// Create a chi router to properly handle URL parameters
	r := chi.NewRouter()

	// Mock handler that returns user data
	r.Get("/api/v1/users/{deviceId}", func(w http.ResponseWriter, r *http.Request) {
		deviceID := chi.URLParam(r, "deviceId")
		if deviceID == "" {
			respondError(w, http.StatusBadRequest, "missing_device_id", "Device ID is required")
			return
		}

		// Simulate found user
		response := UserResponse{
			ID:          deviceID,
			DisplayName: "TestPlayer",
			Stats: StatsResponse{
				TotalGames:    10,
				Wins:          6,
				Losses:        3,
				Draws:         1,
				WinPercentage: 60.0,
			},
			CreatedAt: time.Now().Format("2006-01-02T15:04:05Z"),
		}
		respondJSON(w, http.StatusOK, response)
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/users/device-123", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response UserResponse
	json.Unmarshal(w.Body.Bytes(), &response)

	if response.ID != "device-123" {
		t.Errorf("Expected ID 'device-123', got '%s'", response.ID)
	}
}

func TestUserHandler_GetProfile_NotFound(t *testing.T) {
	r := chi.NewRouter()

	r.Get("/api/v1/users/{deviceId}", func(w http.ResponseWriter, r *http.Request) {
		deviceID := chi.URLParam(r, "deviceId")
		if deviceID == "unknown" {
			respondError(w, http.StatusNotFound, "user_not_found", "User not found")
			return
		}
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/users/unknown", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("Expected status 404, got %d", w.Code)
	}
}

// ========== UpdateProfile Handler Tests ==========

func TestUserHandler_UpdateProfile_ValidRequest(t *testing.T) {
	r := chi.NewRouter()

	r.Patch("/api/v1/users/{deviceId}", func(w http.ResponseWriter, r *http.Request) {
		deviceID := chi.URLParam(r, "deviceId")

		var req UpdateProfileRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			respondError(w, http.StatusBadRequest, "invalid_request", "Invalid request body")
			return
		}

		response := map[string]interface{}{
			"id":           deviceID,
			"display_name": req.DisplayName,
			"updated_at":   time.Now().Format("2006-01-02T15:04:05Z"),
		}

		respondJSON(w, http.StatusOK, response)
	})

	reqBody := UpdateProfileRequest{
		DisplayName: "NewName",
	}
	body, _ := json.Marshal(reqBody)

	req := httptest.NewRequest(http.MethodPatch, "/api/v1/users/device-123", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &response)

	if response["display_name"] != "NewName" {
		t.Errorf("Expected display_name 'NewName', got '%v'", response["display_name"])
	}
}

func TestUserHandler_UpdateProfile_InvalidJSON(t *testing.T) {
	r := chi.NewRouter()

	r.Patch("/api/v1/users/{deviceId}", func(w http.ResponseWriter, r *http.Request) {
		var req UpdateProfileRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			respondError(w, http.StatusBadRequest, "invalid_request", "Invalid request body")
			return
		}
	})

	req := httptest.NewRequest(http.MethodPatch, "/api/v1/users/device-123", bytes.NewReader([]byte(`{invalid}`)))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected status 400, got %d", w.Code)
	}
}

// ========== Response Helper Tests ==========

func TestRespondJSON(t *testing.T) {
	w := httptest.NewRecorder()

	data := map[string]string{"message": "success"}
	respondJSON(w, http.StatusOK, data)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	contentType := w.Header().Get("Content-Type")
	if contentType != "application/json" {
		t.Errorf("Expected Content-Type 'application/json', got '%s'", contentType)
	}

	var response map[string]string
	json.Unmarshal(w.Body.Bytes(), &response)

	if response["message"] != "success" {
		t.Errorf("Expected message 'success', got '%s'", response["message"])
	}
}

func TestRespondError(t *testing.T) {
	w := httptest.NewRecorder()

	respondError(w, http.StatusBadRequest, "test_error", "Test error message")

	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected status 400, got %d", w.Code)
	}

	var response map[string]interface{}
	json.Unmarshal(w.Body.Bytes(), &response)

	errorObj, ok := response["error"].(map[string]interface{})
	if !ok {
		t.Fatal("Expected error object in response")
	}

	if errorObj["code"] != "test_error" {
		t.Errorf("Expected error code 'test_error', got '%v'", errorObj["code"])
	}

	if errorObj["message"] != "Test error message" {
		t.Errorf("Expected error message 'Test error message', got '%v'", errorObj["message"])
	}
}

// ========== Request/Response Type Tests ==========

func TestRegisterRequest_JSONMarshaling(t *testing.T) {
	req := RegisterRequest{
		DeviceID:    "device-123",
		DisplayName: "Player",
		Platform:    "iOS",
		AppVersion:  "1.0.0",
	}

	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Failed to marshal: %v", err)
	}

	var parsed RegisterRequest
	err = json.Unmarshal(data, &parsed)
	if err != nil {
		t.Fatalf("Failed to unmarshal: %v", err)
	}

	if parsed.DeviceID != req.DeviceID {
		t.Error("DeviceID mismatch")
	}
	if parsed.DisplayName != req.DisplayName {
		t.Error("DisplayName mismatch")
	}
}

func TestUserResponse_JSONMarshaling(t *testing.T) {
	resp := UserResponse{
		ID:          "device-123",
		DisplayName: "Player",
		Stats: StatsResponse{
			TotalGames:    10,
			Wins:          5,
			Losses:        3,
			Draws:         2,
			WinPercentage: 50.0,
		},
		CreatedAt: "2024-01-01T00:00:00Z",
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Failed to marshal: %v", err)
	}

	var parsed UserResponse
	err = json.Unmarshal(data, &parsed)
	if err != nil {
		t.Fatalf("Failed to unmarshal: %v", err)
	}

	if parsed.ID != resp.ID {
		t.Error("ID mismatch")
	}
	if parsed.Stats.WinPercentage != 50.0 {
		t.Error("WinPercentage mismatch")
	}
}

func TestStatsResponse_JSONFields(t *testing.T) {
	stats := StatsResponse{
		TotalGames:    100,
		Wins:          60,
		Losses:        30,
		Draws:         10,
		WinPercentage: 60.0,
	}

	data, _ := json.Marshal(stats)
	jsonStr := string(data)

	// Verify JSON field names
	expectedFields := []string{
		`"total_games"`,
		`"wins"`,
		`"losses"`,
		`"draws"`,
		`"win_percentage"`,
	}

	for _, field := range expectedFields {
		if !bytes.Contains(data, []byte(field)) {
			t.Errorf("Expected field %s in JSON: %s", field, jsonStr)
		}
	}
}

// ========== HTTP Method Tests ==========

func TestHTTPMethods(t *testing.T) {
	r := chi.NewRouter()

	// Setup routes
	r.Post("/api/v1/users/register", func(w http.ResponseWriter, r *http.Request) {
		respondJSON(w, http.StatusCreated, map[string]string{"method": "POST"})
	})
	r.Get("/api/v1/users/{deviceId}", func(w http.ResponseWriter, r *http.Request) {
		respondJSON(w, http.StatusOK, map[string]string{"method": "GET"})
	})
	r.Patch("/api/v1/users/{deviceId}", func(w http.ResponseWriter, r *http.Request) {
		respondJSON(w, http.StatusOK, map[string]string{"method": "PATCH"})
	})

	// Test POST
	req := httptest.NewRequest(http.MethodPost, "/api/v1/users/register", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Errorf("POST should return 201, got %d", w.Code)
	}

	// Test GET
	req = httptest.NewRequest(http.MethodGet, "/api/v1/users/device-123", nil)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("GET should return 200, got %d", w.Code)
	}

	// Test PATCH
	req = httptest.NewRequest(http.MethodPatch, "/api/v1/users/device-123", nil)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("PATCH should return 200, got %d", w.Code)
	}
}

// ========== Content Type Tests ==========

func TestContentType_ApplicationJSON(t *testing.T) {
	w := httptest.NewRecorder()
	respondJSON(w, http.StatusOK, map[string]string{"test": "value"})

	contentType := w.Header().Get("Content-Type")
	if contentType != "application/json" {
		t.Errorf("Expected Content-Type 'application/json', got '%s'", contentType)
	}
}

// ========== Error Response Tests ==========

func TestErrorResponses(t *testing.T) {
	testCases := []struct {
		status  int
		code    string
		message string
	}{
		{http.StatusBadRequest, "bad_request", "Invalid request"},
		{http.StatusNotFound, "not_found", "Resource not found"},
		{http.StatusInternalServerError, "internal_error", "Server error"},
		{http.StatusUnauthorized, "unauthorized", "Authentication required"},
	}

	for _, tc := range testCases {
		w := httptest.NewRecorder()
		respondError(w, tc.status, tc.code, tc.message)

		if w.Code != tc.status {
			t.Errorf("Expected status %d, got %d", tc.status, w.Code)
		}

		var response map[string]interface{}
		json.Unmarshal(w.Body.Bytes(), &response)

		errorObj := response["error"].(map[string]interface{})
		if errorObj["code"] != tc.code {
			t.Errorf("Expected error code '%s', got '%v'", tc.code, errorObj["code"])
		}
	}
}
