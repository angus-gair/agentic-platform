# Deployment Coordination Guide

**AJ Insights Ecosystem - ajinsights.com.au**

## Overview

This document defines the centrally managed deployment settings and coordination between the deployment orchestrator and individual project teams.

## Deployment Authority

**Deployment Orchestrator**: `/home/admin/projects/agentic-platform/deployment-orchestrator`
- **Responsible for**: Infrastructure, networking, domains, SSL, port allocation, NGINX configuration
- **Authority**: Final say on all production deployment settings

**Project Teams**: Individual repositories
- **Responsible for**: Application code, business logic, internal configurations
- **Authority**: Local development and application-level settings only

---

## 🚫 CENTRALLY MANAGED SETTINGS (DO NOT CHANGE)

### 1. Port Management
**Allocation Strategy**: 30000-30999 range for production services

| Service | Port | Domain | Purpose |
|---------|------|--------|---------|
| **AI Platform NGINX** | 30080 | agentic-ai.ajinsights.com.au | Public access point |
| **Company Website** | 3102 | www.ajinsights.com.au | Main company site |
| **Documentation** | 3103 | docs.ajinsights.com.au | Documentation site |
| **AI Platform Frontend** | 3101 | (internal) | Proxied via NGINX |
| **AI Platform Backend** | 8000 | (internal) | Proxied via NGINX |
| **Grafana** | 3000 | monitoring.ajinsights.com.au | Disabled |

### 2. Domain Configuration
**Base Domain**: ajinsights.com.au

| Subdomain | Target | Managed By |
|-----------|--------|------------|
| www.ajinsights.com.au | Port 3102 | Deployment Orchestrator |
| agentic-ai.ajinsights.com.au | Port 30080 | Deployment Orchestrator |
| docs.ajinsights.com.au | Port 3103 | Deployment Orchestrator |
| monitoring.ajinsights.com.au | Port 3000 | Deployment Orchestrator (disabled) |

### 3. SSL/TLS Strategy
- **SSL Termination**: Cloudflare (external)
- **Internal Communication**: HTTP-only
- **Certificates**: None required (Cloudflare handles all)
- **Security Headers**: Managed by deployment orchestrator

### 4. NGINX Configuration
**Reverse Proxy Rules** (managed by deployment orchestrator):
```nginx
# Company Website
server {
    listen 80;
    server_name www.ajinsights.com.au;
    location / {
        proxy_pass http://localhost:3102;
    }
}

# AI Platform
server {
    listen 80;
    server_name agentic-ai.ajinsights.com.au;
    location / {
        proxy_pass http://localhost:30080;
    }
}

# Documentation
server {
    listen 80;
    server_name docs.ajinsights.com.au;
    location / {
        proxy_pass http://localhost:3103;
    }
}
```

### 5. Docker Network Configuration
- **Network Name**: `agentic-network`
- **Driver**: bridge
- **Scope**: All services must join this network for orchestration

### 6. Container Naming Convention
**Required for orchestration:**

| Project | Container Name | Purpose |
|---------|----------------|---------|
| AI Platform Frontend | `agentic-frontend` | Service discovery |
| AI Platform Backend | `agentic-backend` | Service discovery |
| AI Platform NGINX | `agentic-nginx` | Load balancing |
| Company Website | `ajinsights-website` | Service discovery |
| Documentation | `docs-ajinsights-docs` | Service discovery |

### 7. Environment Variables (Production)
**Centrally managed:**
```bash
# Metrics Control
ENABLE_METRICS=false

# Domain Configuration
DOMAIN_BASE=ajinsights.com.au
WEBSITE_DOMAIN=www.ajinsights.com.au
PLATFORM_DOMAIN=agentic-ai.ajinsights.com.au
DOCS_DOMAIN=docs.ajinsights.com.au

# Server Configuration
SERVER_IP=193.181.208.69
SERVER_NAME=thunder1.vps.webdock.cloud
```

---

## ✅ PROJECT TEAM AUTONOMY

### What Teams CAN Change

1. **Application Code**
   - Business logic and functionality
   - Internal API routes and methods
   - Agent configurations and tools
   - UI components and styling

2. **Development Environment**
   - Local development ports (for dev only)
   - Development dependencies
   - Testing configurations
   - Local environment variables

3. **Internal Configuration**
   - Application-specific settings
   - Database schemas and models
   - Internal service communication
   - Logging and debugging

4. **Build Process**
   - Dockerfile content (excluding EXPOSE port)
   - Package dependencies
   - Build optimization
   - Asset management

### Development vs Production

| Setting | Development | Production |
|---------|-------------|------------|
| **Ports** | ✅ Flexible | 🚫 Fixed by orchestrator |
| **Domains** | ✅ localhost | 🚫 Fixed by orchestrator |
| **Networks** | ✅ Custom | 🚫 agentic-network required |
| **SSL** | ✅ None/self-signed | 🚫 Cloudflare managed |
| **Container Names** | ✅ Custom | 🚫 Fixed by orchestrator |

---

## Project-Specific Coordination

### 1. AJ Insights Company Website
**Location**: `/home/admin/projects/agentic-platform/aj-insights_com_au`

**Fixed Settings**:
- Port: 3102
- Domain: www.ajinsights.com.au
- Container: ajinsights-website

**Team Autonomy**:
- Website content and pages
- UI components and styling
- Internal routing and pages

### 2. AI Platform
**Location**: `/home/admin/projects/agentic-platform/local-agentic-platform`

**Fixed Settings**:
- Frontend Port: 3101
- Backend Port: 8000
- NGINX Port: 30080
- Domain: agentic-ai.ajinsights.com.au
- Network: agentic-network

**Team Autonomy**:
- Agent logic and functionality
- API routes and WebSocket handling
- Database schemas and models
- Internal service configuration

### 3. Documentation Site
**Location**: `/home/admin/projects/agentic-platform/local-agentic-ai-comprehensive-documentation`

**Fixed Settings**:
- Port: 3103
- Domain: docs.ajinsights.com.au
- Container: docs-ajinsights-docs

**Team Autonomy**:
- Documentation content
- UI components and navigation
- Internal page structure

---

## Deployment Workflow

### 1. Development Phase
```bash
# Teams can use any ports locally
cd /project-directory
docker-compose up -d  # Local development

# Test locally on any port
curl http://localhost:3000  # Example
```

### 2. Production Deployment
```bash
# Only deployment orchestrator executes
cd /home/admin/projects/agentic-platform/deployment-orchestrator
./deploy.sh all

# Or individual services
./deploy.sh website|platform|docs
```

### 3. Coordination Process

1. **Development**: Teams work independently with local configurations
2. **Testing**: Teams ensure compatibility with assigned ports/networks
3. **Deployment Request**: Teams notify deployment orchestrator
4. **Production Deploy**: Orchestrator handles production deployment
5. **Verification**: All parties verify service functionality

---

## Emergency Procedures

### Service Down
1. **Immediate**: Deployment orchestrator restarts affected services
2. **Investigation**: Teams investigate application-level issues
3. **Resolution**: Collaborative fix with clear authority boundaries

### Configuration Conflicts
1. **Authority**: Deployment orchestrator has final say on infrastructure
2. **Process**: Teams raise concerns, orchestrator evaluates and decides
3. **Documentation**: All changes documented in this guide

### Port Conflicts
1. **Resolution**: Deployment orchestrator reassigns ports
2. **Communication**: Teams notified of any port changes
3. **Update**: Teams update development configurations

---

## Contact & Responsibilities

### Deployment Orchestrator
- **Infrastructure Management**: Ports, domains, SSL, NGINX
- **Service Orchestration**: Docker networks, container coordination
- **Production Deployment**: Final deployment authority
- **Emergency Response**: Service restoration and infrastructure fixes

### Project Teams
- **Application Development**: Code, logic, internal configuration
- **Local Testing**: Development environment management
- **Issue Reporting**: Application-level problems and bugs
- **Collaboration**: Working within orchestrator constraints

---

## Change Management

### Infrastructure Changes
**Process**: Deployment orchestrator proposes → Teams review → Implementation

### Application Changes
**Process**: Teams develop → Test with fixed constraints → Deploy via orchestrator

### Emergency Changes
**Authority**: Deployment orchestrator can make immediate infrastructure changes
**Follow-up**: Documentation update and team notification within 24 hours

---

This coordination ensures smooth operations while maintaining clear boundaries between infrastructure management and application development responsibilities.