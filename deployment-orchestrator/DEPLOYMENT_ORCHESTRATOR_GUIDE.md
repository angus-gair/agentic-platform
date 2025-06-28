# Deployment Orchestrator Guide for ajinsights.com.au

## Overview

This guide provides comprehensive documentation for deploying and managing all components of the ajinsights.com.au ecosystem. It is designed to be self-contained, assuming no prior knowledge of the project.

## Current Deployment Status

**Active Deployment**: ajinsights.com.au domains
- ✅ **www.ajinsights.com.au** - Company website (Port 3102) - Working
- ✅ **agentic-ai.ajinsights.com.au** - Agentic AI Platform (Port 30080) - Working
- ✅ **docs.ajinsights.com.au** - Documentation site - Working
- ⚠️ **monitoring.ajinsights.com.au** - Grafana dashboard (Disabled - ENABLE_METRICS=false)

**Infrastructure Performance**:
- Network: 268.6 Mbps to Cloudflare, 14ms latency (Excellent)
- SSL: Cloudflare termination (no Let's Encrypt)
- Metrics: Disabled to improve performance

## Domain Structure

- **www.ajinsights.com.au** - Company website
- **agentic-ai.ajinsights.com.au** - Agentic AI Platform  
- **docs.ajinsights.com.au** - Documentation site
- **monitoring.ajinsights.com.au** - Grafana monitoring dashboard (disabled)

## Server Information

- **Provider**: Webdock.io
- **Server**: thunder1.vps.webdock.cloud (193.181.208.69)
- **OS**: Ubuntu Noble LEMP 8.3
- **Admin User**: admin
- **Web Root**: /var/www/html

## Project Structure

```
/home/admin/projects/agentic-platform/
├── aj-insights_com_au/              # Company website (www.ajinsights.app)
├── local-agentic-platform/          # AI Platform (agentic-ai.ajinsights.app)
├── local-agentic-ai-comprehensive-documentation/  # Docs (docs.ajinsights.app)
├── deployment-orchestrator/         # Deployment management (this directory)
├── mcp-server-cloudflare/          # Cloudflare documentation
└── webdock-cli/                    # Webdock server management tools
```

## Technology Stack Summary

### Company Website (www.ajinsights.app)
- **Framework**: Next.js 15.2.4
- **Port**: 3102
- **Build**: `pnpm install && pnpm build`
- **Start**: `pnpm start`

### AI Platform (agentic-ai.ajinsights.app)
- **Frontend**: Next.js 15.2.4 (Port 3101)
- **Backend**: FastAPI Python 3.11 (Port 8000)
- **Databases**: PostgreSQL 13, Redis, ChromaDB
- **Reverse Proxy**: Nginx (Port 30080)
- **Monitoring**: Prometheus (30090), Grafana (3000)

### Documentation (docs.ajinsights.app)
- **Framework**: Next.js 15.2.4
- **Server**: Nginx
- **Port**: 80 (internal)

## SSL/TLS Strategy

All SSL/TLS termination is handled by Cloudflare. Applications run HTTP-only internally.

## Port Allocation Strategy

Ports are allocated in the 30000-30999 range to avoid conflicts:
- 30080: Nginx (AI Platform)
- 30090: Prometheus
- 3000: Grafana (proxied through Nginx)
- 3101: AI Platform Frontend
- 3102: Company Website

## Environment Variables

### Required Secrets
```bash
# LLM API Keys
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
XAI_API_KEY=

# Database Credentials
POSTGRES_USER=admin
POSTGRES_PASSWORD=
POSTGRES_DB=agentic_platform
REDIS_PASSWORD=

# Monitoring
PROMETHEUS_USER=prom
PROMETHEUS_PASSWORD=
GF_ADMIN_USER=admin
GF_ADMIN_PASSWORD=

# Optional MCP Keys
BRAVE_API_KEY=
SENTRY_AUTH_TOKEN=
```

## Docker Deployment Commands

### Deploy All Services
```bash
cd /home/admin/projects/agentic-platform/deployment-orchestrator
./deploy.sh all
```

### Deploy Individual Services
```bash
# Company Website
./deploy.sh website

# AI Platform
./deploy.sh platform

# Documentation
./deploy.sh docs
```

### Service Management
```bash
# Check status
docker ps

# View logs
docker logs <container_name>

# Restart service
docker restart <container_name>

# Stop all services
docker-compose down

# Start all services
docker-compose up -d
```

## Nginx Configuration

Nginx serves as the reverse proxy for all services. Main configuration locations:
- `/etc/nginx/sites-available/`
- `/etc/nginx/sites-enabled/`

### Required Server Blocks

**Note**: Current deployment uses .com.au domains. Configuration managed by nginx-comau-config.sh

1. **www.ajinsights.com.au**
   ```nginx
   server {
       listen 80;
       server_name www.ajinsights.com.au;
       
       location / {
           proxy_pass http://localhost:3102;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
   }
   ```

2. **agentic-ai.ajinsights.com.au**
   ```nginx
   server {
       listen 80;
       server_name agentic-ai.ajinsights.com.au;
       
       location / {
           proxy_pass http://localhost:30080;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
   }
   ```

3. **docs.ajinsights.com.au**
   ```nginx
   server {
       listen 80;
       server_name docs.ajinsights.com.au;
       
       location / {
           proxy_pass http://localhost:3103;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

## Health Checks

### Service Health Endpoints
- Company Website: `http://localhost:3102/`
- AI Platform Frontend: `http://localhost:3101/`
- AI Platform Backend: `http://localhost:8000/health`
- Documentation: `http://localhost:80/`

### Monitoring URLs
- Prometheus: `http://monitoring.ajinsights.app:30090`
- Grafana: `http://monitoring.ajinsights.app`

## Deployment Checklist

### Pre-deployment
- [ ] Verify Docker and docker-compose are installed
- [ ] Confirm environment variables are set
- [ ] Check DNS records point to server IP
- [ ] Ensure Cloudflare proxy is enabled for all domains

### Deployment Steps
1. [ ] Clone repository to server
2. [ ] Set up environment variables
3. [ ] Build Docker images
4. [ ] Start services with docker-compose
5. [ ] Configure Nginx reverse proxy
6. [ ] Test health endpoints
7. [ ] Verify external access through domains

### Post-deployment
- [ ] Monitor logs for errors
- [ ] Set up automated backups
- [ ] Configure monitoring alerts
- [ ] Document any custom configurations

## Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # Check port usage
   sudo netstat -tlnp | grep :PORT_NUMBER
   ```

2. **Docker Issues**
   ```bash
   # View container logs
   docker logs --tail 50 -f <container_name>
   
   # Restart Docker service
   sudo systemctl restart docker
   ```

3. **Nginx Issues**
   ```bash
   # Test configuration
   sudo nginx -t
   
   # Reload configuration
   sudo systemctl reload nginx
   ```

4. **DNS Issues**
   ```bash
   # Check DNS resolution
   dig www.ajinsights.app
   dig agentic-ai.ajinsights.app
   dig docs.ajinsights.app
   ```

## Maintenance

### Regular Tasks
- Daily: Check service health endpoints
- Weekly: Review logs for errors
- Monthly: Update dependencies and Docker images
- Quarterly: Review and rotate secrets

### Backup Strategy
- Database: Daily PostgreSQL dumps
- Application data: Weekly snapshots
- Configuration: Git repository commits

## Contact & Support

- Server Provider: Webdock.io
- DNS/CDN: Cloudflare
- Repository: /home/admin/projects/agentic-platform

## Performance Notes

Based on recent testing (2025-06-27):
- **Cloudflare Connection**: Excellent - 14ms latency, 268.6 Mbps download
- **Site Response Times**: 
  - DNS lookup: 27.7ms
  - TLS handshake: 125ms  
  - Total response: 184.3ms
- **Optimization**: Metrics disabled (ENABLE_METRICS=false) for improved performance

---

Last Updated: 2025-06-27