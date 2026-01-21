.PHONY: all build run test clean docker-build docker-run lint fmt help

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod
GOFMT=$(GOCMD) fmt
BINARY_NAME=xiangqi-server
BINARY_PATH=bin/$(BINARY_NAME)
MAIN_PATH=./cmd/server

# Docker parameters
DOCKER_IMAGE=xiangqi-backend
DOCKER_TAG=latest

all: test build

# Build the application
build:
	@echo "Building..."
	@mkdir -p bin
	$(GOBUILD) -o $(BINARY_PATH) -v $(MAIN_PATH)

# Run the application
run:
	@echo "Running..."
	$(GOCMD) run $(MAIN_PATH)

# Run the application with hot reload (requires air)
dev:
	@echo "Starting development server with hot reload..."
	@which air > /dev/null || (echo "Installing air..." && go install github.com/cosmtrek/air@latest)
	air

# Run tests
test:
	@echo "Testing..."
	$(GOTEST) -v ./...

# Run tests with coverage
test-coverage:
	@echo "Testing with coverage..."
	$(GOTEST) -v -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html

# Clean build files
clean:
	@echo "Cleaning..."
	@rm -rf bin/
	@rm -f coverage.out coverage.html

# Download dependencies
deps:
	@echo "Downloading dependencies..."
	$(GOMOD) download
	$(GOMOD) tidy

# Format code
fmt:
	@echo "Formatting..."
	$(GOFMT) ./...

# Lint code (requires golangci-lint)
lint:
	@echo "Linting..."
	@which golangci-lint > /dev/null || (echo "Please install golangci-lint: https://golangci-lint.run/usage/install/" && exit 1)
	golangci-lint run

# Build Docker image
docker-build:
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

# Run Docker container
docker-run:
	@echo "Running Docker container..."
	docker run -p 8080:8080 $(DOCKER_IMAGE):$(DOCKER_TAG)

# Start development environment with Docker Compose
docker-dev:
	@echo "Starting development environment..."
	docker-compose up -d

# Stop development environment
docker-stop:
	@echo "Stopping development environment..."
	docker-compose down

# Run database migrations
migrate-up:
	@echo "Running migrations..."
	@which migrate > /dev/null || (echo "Please install golang-migrate: https://github.com/golang-migrate/migrate" && exit 1)
	migrate -path db/migrations -database "postgres://postgres:postgres@localhost:5432/xiangqi?sslmode=disable" up

# Rollback database migrations
migrate-down:
	@echo "Rolling back migrations..."
	migrate -path db/migrations -database "postgres://postgres:postgres@localhost:5432/xiangqi?sslmode=disable" down

# Create a new migration
migrate-create:
	@read -p "Enter migration name: " name; \
	migrate create -ext sql -dir db/migrations -seq $$name

# Production build (optimized, no debug info)
build-prod:
	@echo "Building for production..."
	@mkdir -p bin
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) -ldflags="-w -s" -o $(BINARY_PATH) -v $(MAIN_PATH)

# Build for different platforms
build-darwin:
	@echo "Building for macOS..."
	@mkdir -p bin
	GOOS=darwin GOARCH=amd64 $(GOBUILD) -o bin/$(BINARY_NAME)-darwin -v $(MAIN_PATH)

build-linux:
	@echo "Building for Linux..."
	@mkdir -p bin
	GOOS=linux GOARCH=amd64 $(GOBUILD) -o bin/$(BINARY_NAME)-linux -v $(MAIN_PATH)

build-all: build-darwin build-linux
	@echo "Built for all platforms"

# Deployment targets
deploy-staging:
	@echo "Deploying to staging..."
	@./scripts/deploy.sh staging

deploy-production:
	@echo "Deploying to production..."
	@./scripts/deploy.sh production

# Docker production targets
docker-build-prod:
	@echo "Building production Docker image..."
	docker build -f Dockerfile.prod -t $(DOCKER_IMAGE):$(DOCKER_TAG) .
	docker tag $(DOCKER_IMAGE):$(DOCKER_TAG) $(DOCKER_IMAGE):$$(git rev-parse --short HEAD)

docker-push:
	@echo "Pushing Docker image..."
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)

# Health check
health:
	@echo "Checking service health..."
	@curl -s http://localhost:8080/health || echo "Service not responding"

# Benchmark tests
bench:
	@echo "Running benchmarks..."
	$(GOTEST) -bench=. -benchmem ./...

# Security scan (requires gosec)
security:
	@echo "Running security scan..."
	@which gosec > /dev/null || (echo "Installing gosec..." && go install github.com/securego/gosec/v2/cmd/gosec@latest)
	gosec ./...

# Generate API documentation (requires swag)
docs:
	@echo "Generating API documentation..."
	@which swag > /dev/null || (echo "Installing swag..." && go install github.com/swaggo/swag/cmd/swag@latest)
	swag init -g cmd/server/main.go

# Help
help:
	@echo "Available targets:"
	@echo ""
	@echo "Development:"
	@echo "  all           - Test and build the application"
	@echo "  build         - Build the application"
	@echo "  run           - Run the application"
	@echo "  dev           - Run with hot reload (requires air)"
	@echo "  test          - Run tests"
	@echo "  test-coverage - Run tests with coverage report"
	@echo "  bench         - Run benchmarks"
	@echo "  clean         - Clean build files"
	@echo "  deps          - Download and tidy dependencies"
	@echo "  fmt           - Format code"
	@echo "  lint          - Lint code"
	@echo "  security      - Run security scan"
	@echo "  docs          - Generate API documentation"
	@echo ""
	@echo "Docker:"
	@echo "  docker-build  - Build Docker image"
	@echo "  docker-run    - Run Docker container"
	@echo "  docker-dev    - Start development environment"
	@echo "  docker-stop   - Stop development environment"
	@echo "  docker-build-prod - Build production Docker image"
	@echo "  docker-push   - Push Docker image to registry"
	@echo ""
	@echo "Database:"
	@echo "  migrate-up    - Run database migrations"
	@echo "  migrate-down  - Rollback database migrations"
	@echo "  migrate-create - Create a new migration"
	@echo ""
	@echo "Deployment:"
	@echo "  build-prod    - Build optimized production binary"
	@echo "  build-all     - Build for all platforms"
	@echo "  deploy-staging    - Deploy to staging"
	@echo "  deploy-production - Deploy to production"
	@echo "  health        - Check service health"
	@echo ""
	@echo "  help          - Show this help"
