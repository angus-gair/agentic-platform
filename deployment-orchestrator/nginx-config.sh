#!/bin/bash

# Nginx Configuration Setup for ajinsights.app
# This script creates the necessary nginx server blocks

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

print_status "Setting up Nginx configuration for ajinsights.app..."

# Create nginx config for www.ajinsights.app (Company Website)
cat > /etc/nginx/sites-available/www.ajinsights.app << 'EOF'
server {
    listen 80;
    server_name www.ajinsights.app;
    
    location / {
        proxy_pass http://localhost:3102;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
}
EOF

# Create nginx config for agentic-ai.ajinsights.app (AI Platform)
cat > /etc/nginx/sites-available/agentic-ai.ajinsights.app << 'EOF'
server {
    listen 80;
    server_name agentic-ai.ajinsights.app;
    
    # Increase client max body size for file uploads
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://localhost:30080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # WebSocket support for real-time features
    location /ws {
        proxy_pass http://localhost:30080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Create nginx config for docs.ajinsights.app (Documentation)
cat > /etc/nginx/sites-available/docs.ajinsights.app << 'EOF'
server {
    listen 80;
    server_name docs.ajinsights.app;
    
    location / {
        proxy_pass http://localhost:3103;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Create nginx config for monitoring.ajinsights.app (Grafana)
cat > /etc/nginx/sites-available/monitoring.ajinsights.app << 'EOF'
server {
    listen 80;
    server_name monitoring.ajinsights.app;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Prometheus access (optional, can be restricted)
    location /prometheus {
        proxy_pass http://localhost:30090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Basic auth for security (optional)
        # auth_basic "Monitoring Access";
        # auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
EOF

# Enable sites by creating symlinks
print_status "Enabling sites..."
ln -sf /etc/nginx/sites-available/www.ajinsights.app /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/agentic-ai.ajinsights.app /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/docs.ajinsights.app /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/monitoring.ajinsights.app /etc/nginx/sites-enabled/

# Remove default nginx site if it exists
if [ -f /etc/nginx/sites-enabled/default ]; then
    print_status "Removing default nginx site..."
    rm /etc/nginx/sites-enabled/default
fi

# Test nginx configuration
print_status "Testing nginx configuration..."
if nginx -t; then
    print_status "Nginx configuration is valid"
    print_status "Reloading nginx..."
    systemctl reload nginx
    print_status "Nginx configuration complete!"
else
    print_error "Nginx configuration test failed"
    exit 1
fi

print_status "Nginx has been configured for:"
print_status "  - www.ajinsights.app (Company Website)"
print_status "  - agentic-ai.ajinsights.app (AI Platform)"
print_status "  - docs.ajinsights.app (Documentation)"
print_status "  - monitoring.ajinsights.app (Grafana)"

print_status "Make sure your DNS records point to this server's IP: $(curl -s ifconfig.me)"