#!/bin/bash

# Deployment Script for ajinsights.app
# This script manages the deployment of all components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base directory
BASE_DIR="/home/admin/projects/agentic-platform"
ORCHESTRATOR_DIR="$BASE_DIR/deployment-orchestrator"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    # Check docker compose
    if ! docker compose version &> /dev/null; then
        print_error "docker compose is not available"
        exit 1
    fi
    
    # Check if .env file exists
    if [ ! -f "$ORCHESTRATOR_DIR/.env" ]; then
        print_error ".env file not found in $ORCHESTRATOR_DIR"
        print_warning "Copy .env.example to .env and fill in the required values"
        exit 1
    fi
    
    print_status "All prerequisites met"
}

# Function to deploy company website
deploy_website() {
    print_status "Deploying company website (www.ajinsights.app)..."
    cd "$BASE_DIR/aj-insights_com_au"
    
    # Build and start the container
    docker build -t ajinsights-website .
    docker stop ajinsights-website 2>/dev/null || true
    docker rm ajinsights-website 2>/dev/null || true
    docker run -d \
        --name ajinsights-website \
        --restart unless-stopped \
        -p 3102:3102 \
        -e NODE_ENV=production \
        -e NEXT_TELEMETRY_DISABLED=1 \
        ajinsights-website
    
    print_status "Company website deployed on port 3102"
}

# Function to deploy AI platform
deploy_platform() {
    print_status "Deploying AI platform (agentic-ai.ajinsights.app)..."
    cd "$BASE_DIR/local-agentic-platform"
    
    # Load environment variables
    set -a
    source "$ORCHESTRATOR_DIR/.env"
    set +a
    
    # Start all platform services
    docker compose up -d --build
    
    print_status "AI platform deployed"
    print_status "Frontend: http://localhost:3101"
    print_status "Backend: http://localhost:8000"
    print_status "Nginx: http://localhost:30080"
}

# Function to deploy documentation
deploy_docs() {
    print_status "Deploying documentation (docs.ajinsights.app)..."
    cd "$BASE_DIR/local-agentic-ai-comprehensive-documentation"
    
    # Use the existing docker compose
    docker compose up -d --build
    
    print_status "Documentation deployed on port 80"
}

# Function to check service health
check_health() {
    print_status "Checking service health..."
    
    # Check company website
    if curl -f -s http://localhost:3102/ > /dev/null; then
        print_status "✓ Company website is healthy"
    else
        print_error "✗ Company website is not responding"
    fi
    
    # Check AI platform
    if curl -f -s http://localhost:30080/ > /dev/null; then
        print_status "✓ AI platform is healthy"
    else
        print_error "✗ AI platform is not responding"
    fi
    
    # Check documentation
    if curl -f -s http://localhost:80/ > /dev/null; then
        print_status "✓ Documentation is healthy"
    else
        print_error "✗ Documentation is not responding"
    fi
}

# Function to show logs
show_logs() {
    service=$1
    case $service in
        website)
            docker logs -f ajinsights-website
            ;;
        platform)
            cd "$BASE_DIR/local-agentic-platform"
            docker compose logs -f
            ;;
        docs)
            cd "$BASE_DIR/local-agentic-ai-comprehensive-documentation"
            docker compose logs -f
            ;;
        *)
            print_error "Unknown service: $service"
            print_status "Available services: website, platform, docs"
            ;;
    esac
}

# Function to stop services
stop_services() {
    service=$1
    case $service in
        website)
            docker stop ajinsights-website
            print_status "Company website stopped"
            ;;
        platform)
            cd "$BASE_DIR/local-agentic-platform"
            docker compose down
            print_status "AI platform stopped"
            ;;
        docs)
            cd "$BASE_DIR/local-agentic-ai-comprehensive-documentation"
            docker compose down
            print_status "Documentation stopped"
            ;;
        all)
            stop_services website
            stop_services platform
            stop_services docs
            ;;
        *)
            print_error "Unknown service: $service"
            ;;
    esac
}

# Main deployment function
deploy_all() {
    check_prerequisites
    deploy_website
    deploy_platform
    deploy_docs
    check_health
}

# Parse command line arguments
case "$1" in
    all)
        deploy_all
        ;;
    website)
        check_prerequisites
        deploy_website
        ;;
    platform)
        check_prerequisites
        deploy_platform
        ;;
    docs)
        check_prerequisites
        deploy_docs
        ;;
    health)
        check_health
        ;;
    logs)
        show_logs "$2"
        ;;
    stop)
        stop_services "${2:-all}"
        ;;
    *)
        echo "Usage: $0 {all|website|platform|docs|health|logs <service>|stop [service]}"
        echo ""
        echo "Commands:"
        echo "  all      - Deploy all services"
        echo "  website  - Deploy company website only"
        echo "  platform - Deploy AI platform only"
        echo "  docs     - Deploy documentation only"
        echo "  health   - Check health of all services"
        echo "  logs     - Show logs for a service (website|platform|docs)"
        echo "  stop     - Stop services (default: all)"
        exit 1
        ;;
esac