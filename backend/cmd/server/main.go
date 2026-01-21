// Package main is the entry point for the Chinese Chess backend server.
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"github.com/xiangqi/chinese-chess-backend/internal/config"
	"github.com/xiangqi/chinese-chess-backend/internal/handlers"
	custommiddleware "github.com/xiangqi/chinese-chess-backend/internal/middleware"
	"github.com/xiangqi/chinese-chess-backend/internal/repository"
	"github.com/xiangqi/chinese-chess-backend/internal/services"
	"github.com/xiangqi/chinese-chess-backend/internal/websocket"
)

func main() {
	// Initialize logger
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	if os.Getenv("APP_ENV") != "production" {
		log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr})
	}

	log.Info().Msg("Starting Chinese Chess Backend Server")

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to load configuration")
	}

	log.Info().
		Str("env", cfg.Environment).
		Int("port", cfg.Server.Port).
		Msg("Configuration loaded")

	// Initialize database connection
	db, err := repository.NewPostgresDB(cfg.Database)
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to connect to database")
	}
	defer db.Close()

	// Initialize Redis client
	redisClient, err := repository.NewRedisClient(cfg.Redis)
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to connect to Redis")
	}
	defer redisClient.Close()

	// Initialize repositories
	userRepo := repository.NewUserRepository(db)
	gameRepo := repository.NewGameRepository(db)
	moveRepo := repository.NewMoveRepository(db)

	// Initialize services
	userService := services.NewUserService(userRepo)
	gameService := services.NewGameService(gameRepo, moveRepo, userRepo)
	matchmakingService := services.NewMatchmakingService(redisClient, gameService)

	// Initialize WebSocket hub
	wsHub := websocket.NewHub(gameService)
	go wsHub.Run()

	// Initialize handlers
	userHandler := handlers.NewUserHandler(userService)
	matchmakingHandler := handlers.NewMatchmakingHandler(matchmakingService)
	gameHandler := handlers.NewGameHandlerWithUserService(gameService, userService, wsHub)
	wsHandler := handlers.NewWebSocketHandler(wsHub, gameService)

	// Setup router
	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))

	// Request body size limit (1MB max)
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1MB limit
			next.ServeHTTP(w, r)
		})
	})

	// CORS configuration - restrict origins in production
	allowedOrigins := []string{
		"https://xiangqi-app.com",
		"https://www.xiangqi-app.com",
		"capacitor://localhost",
		"ionic://localhost",
	}
	// Allow localhost in development
	if cfg.Environment == "development" || cfg.Environment == "" {
		allowedOrigins = append(allowedOrigins,
			"http://localhost:3000",
			"http://localhost:8080",
			"http://127.0.0.1:3000",
			"http://127.0.0.1:8080",
		)
	}
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   allowedOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Device-ID", "X-App-Version"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Health check endpoint
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"healthy"}`))
	})

	// API routes
	r.Route("/api/v1", func(r chi.Router) {
		// Apply authentication middleware to all API routes
		r.Use(custommiddleware.DeviceAuth)
		r.Use(custommiddleware.RateLimiter(100)) // 100 requests per minute

		// User routes
		r.Route("/users", func(r chi.Router) {
			r.Post("/register", userHandler.Register)
			r.Get("/{deviceId}", userHandler.GetProfile)
			r.Patch("/{deviceId}", userHandler.UpdateProfile)
		})

		// Matchmaking routes
		r.Route("/matchmaking", func(r chi.Router) {
			r.Post("/join", matchmakingHandler.JoinQueue)
			r.Delete("/leave", matchmakingHandler.LeaveQueue)
			r.Get("/status", matchmakingHandler.GetStatus)
		})

		// Game routes
		r.Route("/games", func(r chi.Router) {
			r.Get("/history", gameHandler.GetHistory)
			r.Get("/active", gameHandler.GetActiveGames)
			r.Get("/{gameId}", gameHandler.GetGame)
			r.Get("/{gameId}/moves", gameHandler.GetMoves)
			r.Get("/{gameId}/full", gameHandler.GetGameWithMoves)
		})

		// User stats route
		r.Get("/users/{userId}/stats", gameHandler.GetUserStats)
	})

	// WebSocket route (outside API route group)
	r.Get("/ws/games/{gameId}", wsHandler.HandleConnection)

	// Create server
	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Server.Port),
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in a goroutine
	go func() {
		log.Info().Msgf("Server listening on port %d", cfg.Server.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal().Err(err).Msg("Server failed")
		}
	}()

	// Wait for interrupt signal to gracefully shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info().Msg("Shutting down server...")

	// Create shutdown context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Shutdown WebSocket hub
	wsHub.Shutdown()

	// Shutdown HTTP server
	if err := server.Shutdown(ctx); err != nil {
		log.Error().Err(err).Msg("Server forced to shutdown")
	}

	log.Info().Msg("Server stopped")
}
