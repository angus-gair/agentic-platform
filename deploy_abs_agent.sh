#!/bin/bash

# ABS Agent Production Deployment Script
# Run this on thunder1.vps.webdock.cloud as admin user

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="/home/admin/backups/$(date +%Y%m%d_%H%M%S)"
DEPLOYMENT_DIR="/home/admin/abs-agent-deployment"
PLATFORM_DIR="/home/gairforce5/projects/local-agentic-platform"

echo -e "${BLUE}🚀 ABS Agent Production Deployment${NC}"
echo "=================================================="

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Pre-deployment checks
print_status "Step 1: Pre-deployment checks..."

# Check if running as admin
if [ "$USER" != "admin" ]; then
    print_error "Please run this script as admin user"
    exit 1
fi

# Check if platform directory exists
if [ ! -d "$PLATFORM_DIR" ]; then
    print_error "Platform directory not found: $PLATFORM_DIR"
    exit 1
fi

# Check if docker is running
if ! docker ps > /dev/null 2>&1; then
    print_error "Docker is not running or accessible"
    exit 1
fi

print_status "✓ Pre-deployment checks passed"

# Step 2: Create backup
print_status "Step 2: Creating backup..."

mkdir -p "$BACKUP_DIR"
cp -r "$PLATFORM_DIR" "$BACKUP_DIR/platform_backup"

# Backup current docker images
docker save $(docker images -q) > "$BACKUP_DIR/images_backup.tar" 2>/dev/null || true

print_status "✓ Backup created at: $BACKUP_DIR"

# Step 3: Check current system status
print_status "Step 3: Checking current system status..."

cd "$PLATFORM_DIR"

# Check running containers
print_status "Current running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Test current backend
if curl -s http://localhost:30200/health > /dev/null; then
    print_status "✓ Current backend is responding"
else
    print_warning "Current backend is not responding"
fi

# Step 4: Prepare deployment directory
print_status "Step 4: Preparing deployment directory..."

mkdir -p "$DEPLOYMENT_DIR"
cd "$DEPLOYMENT_DIR"

# Create backend directory structure
mkdir -p backend/{agents,integrations,tests}

print_status "✓ Deployment directory prepared"

# Step 5: Create backend files
print_status "Step 5: Creating backend files..."

# Note: In a real deployment, you would upload these files
# For now, we'll create placeholder instructions

cat > "$DEPLOYMENT_DIR/UPLOAD_INSTRUCTIONS.md" << 'EOF'
# File Upload Instructions

You need to upload the following files to this directory:

## Required Files:
1. backend/main.py
2. backend/requirements.txt
3. backend/Dockerfile
4. backend/agents/data_agent.py
5. backend/agents/agent_registry.py
6. backend/integrations/abs_client.py
7. backend/tests/test_abs_agent_comprehensive.py

## Upload Methods:

### Option A: SCP from local machine
```bash
scp -r backend/ admin@thunder1.vps.webdock.cloud:/home/admin/abs-agent-deployment/
```

### Option B: Create files manually
Copy the file contents from the development environment and paste them here.

### Option C: Git clone (if repository exists)
```bash
git clone <repository-url> .
```

After uploading files, run:
```bash
./deploy_abs_agent.sh continue
```
EOF

# Check if this is a continuation run
if [ "$1" = "continue" ]; then
    print_status "Continuing deployment with uploaded files..."
    
    # Verify required files exist
    REQUIRED_FILES=(
        "backend/main.py"
        "backend/requirements.txt" 
        "backend/Dockerfile"
        "backend/agents/data_agent.py"
        "backend/agents/agent_registry.py"
        "backend/integrations/abs_client.py"
    )
    
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$DEPLOYMENT_DIR/$file" ]; then
            print_error "Required file missing: $file"
            print_error "Please upload all required files first"
            exit 1
        fi
    done
    
    print_status "✓ All required files found"
    
    # Step 6: Stop current backend
    print_status "Step 6: Stopping current backend..."
    
    cd "$PLATFORM_DIR"
    docker-compose stop backend || true
    
    print_status "✓ Current backend stopped"
    
    # Step 7: Update docker-compose configuration
    print_status "Step 7: Updating docker-compose configuration..."
    
    # Backup original docker-compose.yml
    cp docker-compose.yml docker-compose.yml.backup
    
    # Create updated docker-compose.yml with our backend
    cat > docker-compose.yml.new << 'EOF'
version: '3.8'

services:
  # Keep existing services and add/update backend
  backend:
    build:
      context: /home/admin/abs-agent-deployment/backend
      dockerfile: Dockerfile
    container_name: abs-agent-backend
    ports:
      - "30200:8000"
    environment:
      - NODE_ENV=production
      - PYTHONPATH=/app
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - agentic-network

networks:
  agentic-network:
    external: true
EOF
    
    # Merge with existing configuration (simplified approach)
    # In production, you'd want to properly merge the configurations
    print_warning "Please manually update docker-compose.yml with the new backend configuration"
    print_status "New backend configuration saved as docker-compose.yml.new"
    
    # Step 8: Build and deploy new backend
    print_status "Step 8: Building and deploying new backend..."
    
    # Build the new backend image
    cd "$DEPLOYMENT_DIR"
    docker build -t abs-agent-backend:latest backend/
    
    # Start the new backend
    cd "$PLATFORM_DIR"
    docker-compose up -d backend
    
    print_status "✓ New backend deployed"
    
    # Step 9: Health checks
    print_status "Step 9: Running health checks..."
    
    # Wait for backend to start
    sleep 10
    
    # Test health endpoint
    for i in {1..30}; do
        if curl -s http://localhost:30200/health > /dev/null; then
            print_status "✓ Backend health check passed"
            break
        fi
        if [ $i -eq 30 ]; then
            print_error "Backend health check failed after 30 attempts"
            print_error "Check logs: docker-compose logs backend"
            exit 1
        fi
        sleep 2
    done
    
    # Test ABS endpoints
    if curl -s http://localhost:30200/agents > /dev/null; then
        print_status "✓ Agents endpoint responding"
    else
        print_warning "Agents endpoint not responding"
    fi
    
    if curl -s http://localhost:30200/test/abs > /dev/null; then
        print_status "✓ ABS test endpoint responding"
    else
        print_warning "ABS test endpoint not responding"
    fi
    
    # Step 10: Final validation
    print_status "Step 10: Final validation..."
    
    # Test external access
    if curl -s https://agentic-ai.ajinsights.com.au/health > /dev/null; then
        print_status "✓ External health check passed"
    else
        print_warning "External health check failed - check nginx configuration"
    fi
    
    print_status "🎉 Deployment completed successfully!"
    print_status "Backend logs: docker-compose logs -f backend"
    print_status "Rollback command: cp docker-compose.yml.backup docker-compose.yml && docker-compose up -d backend"
    
else
    print_status "📁 Files need to be uploaded before continuing deployment"
    print_status "Please check: $DEPLOYMENT_DIR/UPLOAD_INSTRUCTIONS.md"
    print_status "After uploading files, run: ./deploy_abs_agent.sh continue"
fi

echo "=================================================="
echo -e "${BLUE}Deployment script completed${NC}"
