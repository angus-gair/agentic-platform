#!/bin/bash

# One-Command ABS Agent Production Deployment
# This script uploads files and deploys the ABS agent to production

set -e

# Configuration
SERVER="admin@thunder1.vps.webdock.cloud"
REMOTE_DIR="/home/admin/abs-agent-deployment"
LOCAL_BACKEND_DIR="./backend"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo -e "${BLUE}🚀 One-Command ABS Agent Production Deployment${NC}"
echo "=================================================="

# Step 1: Pre-flight checks
print_status "Step 1: Pre-flight checks..."

if [ ! -d "$LOCAL_BACKEND_DIR" ]; then
    print_error "Backend directory not found: $LOCAL_BACKEND_DIR"
    exit 1
fi

if ! ssh -o ConnectTimeout=10 "$SERVER" "echo 'SSH OK'" > /dev/null 2>&1; then
    print_error "Cannot connect to $SERVER"
    exit 1
fi

print_status "✓ Pre-flight checks passed"

# Step 2: Upload files
print_status "Step 2: Uploading files..."

# Create remote directories
ssh "$SERVER" "mkdir -p $REMOTE_DIR/backend/{agents,integrations,tests}"

# Upload all backend files
scp -r "$LOCAL_BACKEND_DIR/"* "$SERVER:$REMOTE_DIR/backend/"

# Upload deployment scripts
scp "./deploy_abs_agent.sh" "$SERVER:$REMOTE_DIR/"
scp "./PRODUCTION_DEPLOYMENT_GUIDE.md" "$SERVER:$REMOTE_DIR/"

# Make scripts executable
ssh "$SERVER" "chmod +x $REMOTE_DIR/deploy_abs_agent.sh"

print_status "✓ Files uploaded"

# Step 3: Run deployment on server
print_status "Step 3: Running deployment on server..."

ssh "$SERVER" "cd $REMOTE_DIR && ./deploy_abs_agent.sh continue"

print_status "🎉 Deployment completed!"

# Step 4: Final validation
print_status "Step 4: Final validation..."

print_status "Testing endpoints..."

# Test health endpoint
if curl -s https://agentic-ai.ajinsights.com.au/health > /dev/null; then
    print_status "✓ Health endpoint responding"
else
    print_warning "Health endpoint not responding"
fi

# Test ABS functionality
print_status "Testing ABS agent..."
RESPONSE=$(curl -s -X POST "https://agentic-ai.ajinsights.com.au/query" \
    -H "Content-Type: application/json" \
    -d '{"query": "What is the current population of New South Wales?"}' | jq -r '.agent' 2>/dev/null || echo "unknown")

if [ "$RESPONSE" = "DataAnalysisAgent" ]; then
    print_status "✅ ABS Agent is working! Query routed to DataAnalysisAgent"
else
    print_warning "⚠️ ABS Agent may not be working properly. Response: $RESPONSE"
fi

echo "=================================================="
echo -e "${GREEN}🎯 Deployment Summary:${NC}"
echo "• Backend files uploaded to production server"
echo "• New ABS agent backend deployed"
echo "• System health checks completed"
echo ""
echo -e "${BLUE}📊 Test the deployment:${NC}"
echo "curl https://agentic-ai.ajinsights.com.au/health"
echo "curl https://agentic-ai.ajinsights.com.au/agents"
echo "curl https://agentic-ai.ajinsights.com.au/test/abs"
echo ""
echo -e "${YELLOW}🔧 Monitoring:${NC}"
echo "ssh $SERVER 'docker logs -f abs-agent-backend'"
echo ""
echo -e "${RED}🔄 Rollback (if needed):${NC}"
echo "ssh $SERVER 'cd /home/gairforce5/projects/local-agentic-platform && cp docker-compose.yml.backup docker-compose.yml && docker-compose up -d backend'"

echo "=================================================="
echo -e "${BLUE}Deployment completed successfully! 🚀${NC}"
