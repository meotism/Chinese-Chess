#!/bin/bash

# Deployment script for Chinese Chess Backend
# Usage: ./deploy.sh [staging|production]

set -e

# Configuration
ENVIRONMENT=${1:-staging}
APP_NAME="xiangqi-backend"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io}"
DOCKER_IMAGE="${DOCKER_REGISTRY}/${APP_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate environment
validate_environment() {
    if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
        log_error "Invalid environment: $ENVIRONMENT"
        echo "Usage: $0 [staging|production]"
        exit 1
    fi
    log_info "Deploying to: $ENVIRONMENT"
}

# Run pre-deployment checks
pre_deploy_checks() {
    log_info "Running pre-deployment checks..."

    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running"
        exit 1
    fi

    # Check if tests pass
    log_info "Running tests..."
    make test
    if [ $? -ne 0 ]; then
        log_error "Tests failed. Aborting deployment."
        exit 1
    fi

    # Check for uncommitted changes
    if [[ -n $(git status --porcelain) ]]; then
        log_warn "There are uncommitted changes"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Build the application
build_app() {
    log_info "Building application..."

    # Get version info
    GIT_COMMIT=$(git rev-parse --short HEAD)
    BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    VERSION="${ENVIRONMENT}-${GIT_COMMIT}"

    log_info "Version: $VERSION"
    log_info "Build time: $BUILD_TIME"

    # Build production binary
    make build-prod

    # Build Docker image
    docker build \
        --build-arg GIT_COMMIT="$GIT_COMMIT" \
        --build-arg BUILD_TIME="$BUILD_TIME" \
        --build-arg VERSION="$VERSION" \
        -t "$DOCKER_IMAGE:$VERSION" \
        -t "$DOCKER_IMAGE:latest" \
        .
}

# Push Docker image
push_image() {
    log_info "Pushing Docker image..."

    GIT_COMMIT=$(git rev-parse --short HEAD)
    VERSION="${ENVIRONMENT}-${GIT_COMMIT}"

    docker push "$DOCKER_IMAGE:$VERSION"
    docker push "$DOCKER_IMAGE:latest"
}

# Run database migrations
run_migrations() {
    log_info "Running database migrations..."

    if [ "$ENVIRONMENT" == "production" ]; then
        # For production, use environment variables for database connection
        DATABASE_URL=${PROD_DATABASE_URL:-""}
        if [ -z "$DATABASE_URL" ]; then
            log_error "PROD_DATABASE_URL not set"
            exit 1
        fi
    else
        DATABASE_URL=${STAGING_DATABASE_URL:-"postgres://postgres:postgres@localhost:5432/xiangqi_staging?sslmode=disable"}
    fi

    migrate -path db/migrations -database "$DATABASE_URL" up
}

# Deploy to Kubernetes (if using k8s)
deploy_k8s() {
    log_info "Deploying to Kubernetes..."

    NAMESPACE="xiangqi-$ENVIRONMENT"
    GIT_COMMIT=$(git rev-parse --short HEAD)
    VERSION="${ENVIRONMENT}-${GIT_COMMIT}"

    # Update image tag in deployment
    kubectl set image deployment/$APP_NAME \
        $APP_NAME="$DOCKER_IMAGE:$VERSION" \
        -n "$NAMESPACE"

    # Wait for rollout
    kubectl rollout status deployment/$APP_NAME -n "$NAMESPACE" --timeout=300s
}

# Deploy using Docker Compose (for simpler setups)
deploy_docker_compose() {
    log_info "Deploying with Docker Compose..."

    GIT_COMMIT=$(git rev-parse --short HEAD)
    VERSION="${ENVIRONMENT}-${GIT_COMMIT}"

    # Use environment-specific compose file
    COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"

    if [ ! -f "$COMPOSE_FILE" ]; then
        log_warn "No $COMPOSE_FILE found, using default docker-compose.yml"
        COMPOSE_FILE="docker-compose.yml"
    fi

    export IMAGE_TAG="$VERSION"
    docker-compose -f "$COMPOSE_FILE" up -d --force-recreate
}

# Health check
health_check() {
    log_info "Running health check..."

    if [ "$ENVIRONMENT" == "production" ]; then
        HEALTH_URL=${PROD_HEALTH_URL:-"http://localhost:8080/health"}
    else
        HEALTH_URL=${STAGING_HEALTH_URL:-"http://localhost:8080/health"}
    fi

    # Wait for service to be healthy
    for i in {1..30}; do
        if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
            log_info "Service is healthy!"
            return 0
        fi
        log_info "Waiting for service... ($i/30)"
        sleep 2
    done

    log_error "Health check failed"
    exit 1
}

# Rollback function
rollback() {
    log_warn "Rolling back deployment..."

    if [ "$DEPLOY_METHOD" == "k8s" ]; then
        NAMESPACE="xiangqi-$ENVIRONMENT"
        kubectl rollout undo deployment/$APP_NAME -n "$NAMESPACE"
    else
        # For docker-compose, we would need to track previous versions
        log_error "Manual rollback required for Docker Compose deployments"
    fi
}

# Post-deployment notifications
notify() {
    log_info "Sending deployment notification..."

    GIT_COMMIT=$(git rev-parse --short HEAD)
    COMMIT_MSG=$(git log -1 --pretty=%B)

    # Slack notification (if webhook is configured)
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{
                \"text\": \"Deployment to $ENVIRONMENT completed\",
                \"attachments\": [{
                    \"color\": \"good\",
                    \"fields\": [
                        {\"title\": \"Commit\", \"value\": \"$GIT_COMMIT\", \"short\": true},
                        {\"title\": \"Message\", \"value\": \"$COMMIT_MSG\", \"short\": false}
                    ]
                }]
            }" \
            "$SLACK_WEBHOOK" > /dev/null 2>&1
    fi
}

# Main deployment flow
main() {
    log_info "Starting deployment to $ENVIRONMENT..."

    validate_environment
    pre_deploy_checks
    build_app

    # Determine deployment method
    DEPLOY_METHOD=${DEPLOY_METHOD:-"docker-compose"}

    case $DEPLOY_METHOD in
        "k8s"|"kubernetes")
            push_image
            run_migrations
            deploy_k8s
            ;;
        "docker-compose"|"compose")
            run_migrations
            deploy_docker_compose
            ;;
        *)
            log_error "Unknown deployment method: $DEPLOY_METHOD"
            exit 1
            ;;
    esac

    health_check
    notify

    log_info "Deployment completed successfully!"
}

# Handle signals
trap 'log_error "Deployment interrupted"; exit 1' INT TERM

# Run main
main
