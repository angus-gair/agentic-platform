#!/bin/bash

# Upload Backend Files to Production Server
# Run this from your local machine where the backend files are located

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

echo -e "${BLUE}📤 Uploading ABS Agent Backend Files${NC}"
echo "=================================================="

# Check if backend directory exists locally
if [ ! -d "$LOCAL_BACKEND_DIR" ]; then
    print_error "Backend directory not found: $LOCAL_BACKEND_DIR"
    print_error "Please run this script from the directory containing the backend folder"
    exit 1
fi

# Check required files
REQUIRED_FILES=(
    "main.py"
    "requirements.txt"
    "Dockerfile"
    "agents/data_agent.py"
    "agents/agent_registry.py"
    "integrations/abs_client.py"
    "agents/__init__.py"
    "integrations/__init__.py"
    "__init__.py"
)

print_status "Checking required files..."
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$LOCAL_BACKEND_DIR/$file" ]; then
        print_error "Required file missing: $LOCAL_BACKEND_DIR/$file"
        exit 1
    fi
done
print_status "✓ All required files found locally"

# Test SSH connection
print_status "Testing SSH connection to $SERVER..."
if ! ssh -o ConnectTimeout=10 "$SERVER" "echo 'SSH connection successful'" > /dev/null 2>&1; then
    print_error "Cannot connect to $SERVER"
    print_error "Please check:"
    print_error "1. SSH key is configured"
    print_error "2. Server is accessible"
    print_error "3. Username and hostname are correct"
    exit 1
fi
print_status "✓ SSH connection successful"

# Create remote directory structure
print_status "Creating remote directory structure..."
ssh "$SERVER" "mkdir -p $REMOTE_DIR/backend/{agents,integrations,tests}"

# Upload files
print_status "Uploading backend files..."

# Upload main backend files
scp "$LOCAL_BACKEND_DIR/main.py" "$SERVER:$REMOTE_DIR/backend/"
scp "$LOCAL_BACKEND_DIR/requirements.txt" "$SERVER:$REMOTE_DIR/backend/"
scp "$LOCAL_BACKEND_DIR/Dockerfile" "$SERVER:$REMOTE_DIR/backend/"
scp "$LOCAL_BACKEND_DIR/__init__.py" "$SERVER:$REMOTE_DIR/backend/"

# Upload agents
scp "$LOCAL_BACKEND_DIR/agents/"*.py "$SERVER:$REMOTE_DIR/backend/agents/"

# Upload integrations
scp "$LOCAL_BACKEND_DIR/integrations/"*.py "$SERVER:$REMOTE_DIR/backend/integrations/"

# Upload tests (optional)
if [ -d "$LOCAL_BACKEND_DIR/tests" ]; then
    scp "$LOCAL_BACKEND_DIR/tests/"*.py "$SERVER:$REMOTE_DIR/backend/tests/" 2>/dev/null || true
fi

# Upload additional files if they exist
if [ -f "$LOCAL_BACKEND_DIR/run_tests.py" ]; then
    scp "$LOCAL_BACKEND_DIR/run_tests.py" "$SERVER:$REMOTE_DIR/backend/"
fi

print_status "✓ Files uploaded successfully"

# Verify upload
print_status "Verifying uploaded files..."
ssh "$SERVER" "ls -la $REMOTE_DIR/backend/"
ssh "$SERVER" "ls -la $REMOTE_DIR/backend/agents/"
ssh "$SERVER" "ls -la $REMOTE_DIR/backend/integrations/"

# Make deployment script executable
print_status "Making deployment script executable..."
scp "./deploy_abs_agent.sh" "$SERVER:$REMOTE_DIR/"
ssh "$SERVER" "chmod +x $REMOTE_DIR/deploy_abs_agent.sh"

print_status "🎉 Upload completed successfully!"
print_status ""
print_status "Next steps:"
print_status "1. SSH to the server: ssh $SERVER"
print_status "2. Run deployment: cd $REMOTE_DIR && ./deploy_abs_agent.sh continue"
print_status ""
print_status "Or run the deployment remotely:"
print_status "ssh $SERVER 'cd $REMOTE_DIR && ./deploy_abs_agent.sh continue'"

echo "=================================================="
echo -e "${BLUE}Upload script completed${NC}"
