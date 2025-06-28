#!/bin/bash

# Nginx Configuration Setup for ajinsights.com.au domains
# This script creates nginx server blocks for .com.au domains

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

print_status "Setting up Nginx configuration for ajinsights.com.au domains..."

# Create nginx config for www.ajinsights.com.au (Company Website)
cat > /etc/nginx/sites-available/www.ajinsights.com.au << 'EOF'
server {
    listen 80;
    server_name www.ajinsights.com.au;
    
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

# Create nginx config for ajinsights.com.au (redirect to www)
cat > /etc/nginx/sites-available/ajinsights.com.au << 'EOF'
server {
    listen 80;
    server_name ajinsights.com.au;
    return 301 https://www.ajinsights.com.au$request_uri;
}
EOF

# Create nginx config for agentic-ai.ajinsights.com.au (AI Platform)
cat > /etc/nginx/sites-available/agentic-ai.ajinsights.com.au << 'EOF'
server {
    listen 80;
    server_name agentic-ai.ajinsights.com.au;
    
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

# Create nginx config for docs.ajinsights.com.au (Documentation)
cat > /etc/nginx/sites-available/docs.ajinsights.com.au << 'EOF'
server {
    listen 80;
    server_name docs.ajinsights.com.au;
    
    location / {
        proxy_pass http://localhost:3103;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Create nginx config for monitoring.ajinsights.com.au (Grafana)
cat > /etc/nginx/sites-available/monitoring.ajinsights.com.au << 'EOF'
server {
    listen 80;
    server_name monitoring.ajinsights.com.au;
    
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

# Create temporary hello world config for testing
cat > /etc/nginx/sites-available/hello.ajinsights.com.au << 'EOF'
server {
    listen 80;
    server_name hello.ajinsights.com.au;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable sites by creating symlinks
print_status "Enabling .com.au sites..."
ln -sf /etc/nginx/sites-available/www.ajinsights.com.au /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/ajinsights.com.au /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/agentic-ai.ajinsights.com.au /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/docs.ajinsights.com.au /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/monitoring.ajinsights.com.au /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/hello.ajinsights.com.au /etc/nginx/sites-enabled/

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

print_status "Nginx has been configured for .com.au domains:"
print_status "  - www.ajinsights.com.au (Company Website)"
print_status "  - ajinsights.com.au (Redirect to www)"
print_status "  - agentic-ai.ajinsights.com.au (AI Platform)"
print_status "  - docs.ajinsights.com.au (Documentation)"
print_status "  - monitoring.ajinsights.com.au (Grafana)"
print_status "  - hello.ajinsights.com.au (Hello World Test)"

print_status "Make sure your DNS records point to this server's IP: $(curl -4 -s ifconfig.me)"