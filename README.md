# Chinese Chess (Xiangqi) Application

A real-time online multiplayer Chinese Chess (Xiangqi) game for iOS with a Go backend.

## Overview

Chinese Chess is a fully-featured iOS application that allows players to enjoy the traditional game of Xiangqi online. The app features anonymous play (no account required), real-time matchmaking, and complete implementation of traditional Chinese Chess rules.

## Features

- **Anonymous Play**: No account required - uses device ID for identification
- **Real-Time Multiplayer**: WebSocket-based gameplay with <500ms latency
- **Complete Xiangqi Rules**: All traditional Chinese Chess rules implemented
  - Flying General detection
  - Check and Checkmate detection
  - All piece movement rules (General, Advisor, Elephant, Horse, Chariot, Cannon, Soldier)
- **Turn Timer**: Configurable turn timeout (1-10 minutes or unlimited)
- **Rollback System**: 3 rollback opportunities per player per game
- **Match History**: Track all completed games with replay functionality
- **Practice Mode**: Play locally without an opponent

## Architecture

```
Chinese-chess/
├── ios/                        # iOS application (SwiftUI)
│   └── ChineseChess/
│       ├── ChineseChess/       # Main app source
│       │   ├── Views/          # SwiftUI views
│       │   ├── ViewModels/     # View models (MVVM)
│       │   ├── Models/         # Data models
│       │   ├── Services/       # Service layer
│       │   ├── Engine/         # Game engine (rules, validators)
│       │   └── Info.plist      # App configuration
│       ├── ChineseChessTests/  # Unit tests
│       └── ChineseChessUITests/# UI tests
│
├── backend/                    # Go backend server
│   ├── cmd/server/             # Main entry point
│   ├── internal/
│   │   ├── config/             # Configuration management
│   │   ├── game/               # Game engine (rules, validators)
│   │   ├── handlers/           # HTTP/WebSocket handlers
│   │   ├── middleware/         # HTTP middleware
│   │   ├── models/             # Domain models
│   │   ├── repository/         # Database layer
│   │   ├── services/           # Business logic
│   │   └── websocket/          # WebSocket management
│   ├── db/migrations/          # Database migrations
│   ├── scripts/                # Deployment scripts
│   └── configs/                # Configuration files
│
├── docker-compose.yml          # Development environment
└── DEPLOYMENT.md               # Deployment documentation
```

## Requirements

### iOS App
- iOS 15.0+
- Xcode 15+
- Swift 5.9+

### Backend
- Go 1.21+
- PostgreSQL 16+
- Redis 7+
- Docker & Docker Compose (for development)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/Chinese-chess.git
cd Chinese-chess
```

### 2. Start Development Environment

```bash
# Start PostgreSQL and Redis containers
docker-compose up -d postgres redis

# Or start everything including the backend
docker-compose up -d
```

### 3. Setup the Backend

```bash
cd backend

# Download dependencies
make deps

# Run database migrations
make migrate-up

# Start the server (with hot reload)
make dev

# Or run directly
make run
```

The API will be available at `http://localhost:8080`.

### 4. Setup the iOS App

```bash
cd ios/ChineseChess

# Generate Xcode project (requires xcodegen)
# brew install xcodegen
xcodegen generate

# Open in Xcode
open ChineseChess.xcodeproj
```

In Xcode:
1. Select your development team in Signing & Capabilities
2. Build and run on a simulator or device

## Configuration

### Backend Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `XIANGQI_ENVIRONMENT` | Environment (development/production) | development |
| `XIANGQI_SERVER_PORT` | HTTP server port | 8080 |
| `XIANGQI_DATABASE_HOST` | PostgreSQL host | localhost |
| `XIANGQI_DATABASE_PORT` | PostgreSQL port | 5432 |
| `XIANGQI_DATABASE_USER` | Database user | postgres |
| `XIANGQI_DATABASE_PASSWORD` | Database password | postgres |
| `XIANGQI_DATABASE_DBNAME` | Database name | xiangqi |
| `XIANGQI_REDIS_HOST` | Redis host | localhost |
| `XIANGQI_REDIS_PORT` | Redis port | 6379 |

### iOS Configuration

Configure the API endpoint in `ios/ChineseChess/ChineseChess/Services/NetworkService.swift`:

```swift
struct NetworkConfig {
    static let baseURL = "http://localhost:8080"  // Development
    // static let baseURL = "https://api.yourdomain.com"  // Production
}
```

## API Endpoints

### User Management
- `POST /api/v1/users/register` - Register new user
- `GET /api/v1/users/{deviceId}` - Get user profile
- `PATCH /api/v1/users/{deviceId}` - Update display name

### Matchmaking
- `POST /api/v1/matchmaking/join` - Join matchmaking queue
- `DELETE /api/v1/matchmaking/leave` - Leave queue
- `GET /api/v1/matchmaking/status` - Get queue status

### Games
- `GET /api/v1/games/history` - Get match history
- `GET /api/v1/games/{gameId}` - Get game details
- `GET /api/v1/games/{gameId}/moves` - Get game moves

### WebSocket
- `WS /ws/games/{gameId}` - Real-time game connection

### Health Check
- `GET /health` - Service health status

## Testing

### Backend Tests

```bash
cd backend

# Run all tests
make test

# Run tests with coverage
make test-coverage

# Run benchmarks
make bench

# Run security scan
make security
```

### iOS Tests

```bash
cd ios/ChineseChess

# Run unit tests
xcodebuild test -scheme ChineseChess -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests
xcodebuild test -scheme ChineseChessUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

Or run tests directly in Xcode with Cmd+U.

## Deployment

### Backend Deployment

```bash
cd backend

# Build production binary
make build-prod

# Build Docker image
make docker-build-prod

# Deploy to staging
make deploy-staging

# Deploy to production
make deploy-production
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

### iOS Deployment (TestFlight)

See [ios/TESTFLIGHT.md](ios/TESTFLIGHT.md) for detailed TestFlight deployment instructions.

Quick steps:
1. Configure signing in Xcode
2. Create archive: Product > Archive
3. Upload to App Store Connect
4. Configure TestFlight and invite testers

## Game Rules

### Piece Movement

| Piece | Movement | Special Rules |
|-------|----------|---------------|
| General (帅/将) | One step orthogonally | Must stay in palace; cannot face opponent's General |
| Advisor (仕/士) | One step diagonally | Must stay in palace |
| Elephant (相/象) | Two steps diagonally | Cannot cross the river; can be blocked |
| Horse (马) | L-shape move | Can be blocked at the first step |
| Chariot (车) | Any distance orthogonally | Like a Rook in chess |
| Cannon (炮) | Moves like Chariot | Must jump over exactly one piece to capture |
| Soldier (兵/卒) | One step forward | Can also move sideways after crossing the river |

### Special Rules

- **Flying General**: The two Generals cannot face each other on the same file with no pieces between them.
- **Perpetual Check**: Continuously checking the opponent is forbidden.
- **Stalemate**: In Xiangqi, stalemate results in a loss for the stalemated player.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- **Go**: Follow standard Go conventions, use `make fmt` and `make lint`
- **Swift**: Follow Swift API Design Guidelines, use SwiftLint

## License

This project is for educational purposes.

## Acknowledgments

- [Xiangqi Rules - World Xiangqi Federation](https://www.wxf-xiangqi.org/)
- [GRDB.swift](https://github.com/groue/GRDB.swift) - SQLite toolkit for Swift
- [gorilla/websocket](https://github.com/gorilla/websocket) - WebSocket implementation for Go
- [chi](https://github.com/go-chi/chi) - Lightweight HTTP router for Go

## Support

For questions or issues:
- Open a GitHub issue
- Email: support@example.com

## Roadmap

- [ ] AI opponent for practice mode
- [ ] Tournament system
- [ ] Friend list and direct challenges
- [ ] ELO rating system
- [ ] Game analysis and replay annotations
- [ ] Android version
