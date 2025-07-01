#!/bin/bash

# Fix Monitoring Redirect - Remove drilldown redirect from production
# This script will deploy the updated nginx configuration to remove the redirect

set -e

# Configuration
SERVER="admin@thunder1.vps.webdock.cloud"
SCRIPT_NAME="nginx-comau-config.sh"

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

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

# Check if we can connect to the server
print_header "🔧 Fixing Monitoring Redirect on Production"

print_status "Checking connection to production server..."
if ! ssh -o ConnectTimeout=10 "$SERVER" "echo 'Connection successful'" >/dev/null 2>&1; then
    print_error "Cannot connect to production server: $SERVER"
    print_error "Please check your SSH connection and try again."
    exit 1
fi

print_status "✓ Connected to production server"

# Upload the updated nginx configuration script
print_status "Uploading updated nginx configuration script..."
scp "deployment-orchestrator/$SCRIPT_NAME" "$SERVER:/tmp/"

# Make it executable
ssh "$SERVER" "chmod +x /tmp/$SCRIPT_NAME"

print_status "✓ Configuration script uploaded"

# Run the nginx configuration script on the server
print_status "Running nginx configuration update on production server..."
print_warning "This will update the nginx configuration and reload nginx"

ssh "$SERVER" "sudo /tmp/$SCRIPT_NAME"

print_status "✓ Nginx configuration updated"

# Test the fix
print_status "Testing the fix..."
print_status "Checking if redirect has been removed..."

# Test with curl to see if we get a redirect
RESPONSE=$(curl -s -I https://monitoring.ajinsights.com.au/ | head -1)
if echo "$RESPONSE" | grep -q "302\|301"; then
    print_error "❌ Redirect is still present!"
    print_error "Response: $RESPONSE"
    exit 1
else
    print_status "✅ Redirect has been successfully removed!"
    print_status "Response: $RESPONSE"
fi

# Clean up
ssh "$SERVER" "rm -f /tmp/$SCRIPT_NAME"

print_header "🎉 Fix Completed Successfully!"
echo ""
echo -e "${GREEN}✅ The monitoring redirect has been removed${NC}"
echo -e "${GREEN}✅ https://monitoring.ajinsights.com.au/ now serves Grafana directly${NC}"
echo ""
echo -e "${BLUE}📊 Test the fix:${NC}"
echo "Visit: https://monitoring.ajinsights.com.au/"
echo "Expected: Direct access to Grafana (no redirect)"
echo ""
echo -e "${YELLOW}🔧 If you still see issues:${NC}"
echo "1. Clear your browser cache"
echo "2. Try an incognito/private window"
echo "3. Check Cloudflare cache settings"
