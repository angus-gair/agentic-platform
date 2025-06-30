# 🚀 ABS Agent Production Deployment Guide

## 📋 Overview

This guide will deploy our improved ABS agent to the live production environment at `agentic-ai.ajinsights.com.au`. The current system needs to be updated with our new backend implementation.

## 🔍 Current Production Environment

**Server**: thunder1.vps.webdock.cloud (65.109.1.180)
**Current System**: local-agentic-platform running on ports 30080-30800
**Target**: Replace/update the backend service with our improved ABS agent

## 📦 Deployment Options

### Option 1: Quick Backend Replacement (Recommended)
Replace just the backend service while keeping the existing infrastructure.

### Option 2: Full System Deployment
Deploy our complete new system alongside the existing one.

---

## 🚀 Option 1: Quick Backend Replacement

### Step 1: Access Production Server
```bash
ssh admin@thunder1.vps.webdock.cloud
# or
ssh admin@65.109.1.180
```

### Step 2: Check Current System Status
```bash
# Check running containers
docker ps

# Check the current platform location
ls -la /home/gairforce5/projects/local-agentic-platform/

# Check current backend health
curl http://localhost:30200/health
```

### Step 3: Backup Current System
```bash
# Create backup directory
mkdir -p /home/admin/backups/$(date +%Y%m%d_%H%M%S)
cd /home/admin/backups/$(date +%Y%m%d_%H%M%S)

# Backup current docker-compose and backend
cp -r /home/gairforce5/projects/local-agentic-platform ./current_system_backup

# Export current container images (optional)
docker save $(docker images -q) > current_images_backup.tar
```

### Step 4: Upload New Backend Code
```bash
# Create deployment directory
mkdir -p /home/admin/abs-agent-deployment
cd /home/admin/abs-agent-deployment

# Upload our backend code (you'll need to transfer these files)
# Option A: Use scp from your local machine
# scp -r backend/ admin@thunder1.vps.webdock.cloud:/home/admin/abs-agent-deployment/

# Option B: Use git (if you have a repository)
# git clone <your-repo-url> .

# Option C: Create the files manually (see file contents below)
```

### Step 5: Stop Current Backend Service
```bash
cd /home/gairforce5/projects/local-agentic-platform/

# Stop only the backend service
docker-compose stop backend

# Verify backend is stopped
docker ps | grep backend
```

### Step 6: Update Backend Configuration
```bash
# Backup original docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup

# Update the backend service configuration
# Edit docker-compose.yml to point to our new backend
```

### Step 7: Deploy New Backend
```bash
# Build and start new backend
docker-compose up -d --build backend

# Check logs
docker-compose logs -f backend

# Test health
curl http://localhost:30200/health
curl http://localhost:30200/agents
curl http://localhost:30200/test/abs
```

### Step 8: Verify Production Deployment
```bash
# Test from external
curl https://agentic-ai.ajinsights.com.au/health
curl https://agentic-ai.ajinsights.com.au/agents

# Test ABS queries
curl -X POST "https://agentic-ai.ajinsights.com.au/query" \
  -H "Content-Type: application/json" \
  -d '{"query": "What is the current population of New South Wales?"}'
```

---

## 🔧 Option 2: Full System Deployment

### Step 1: Deploy Complete New System
```bash
# Access server
ssh admin@thunder1.vps.webdock.cloud

# Create new deployment directory
mkdir -p /home/admin/new-abs-agent-system
cd /home/admin/new-abs-agent-system

# Upload all our files
# (backend/, deployment-orchestrator/docker-compose.yml, etc.)
```

### Step 2: Use Different Ports
```bash
# Modify docker-compose.yml to use different ports
# Backend: 30210 instead of 30200
# Frontend: 30110 instead of 30100
# This allows running both systems simultaneously
```

### Step 3: Deploy New System
```bash
# Start new system
docker-compose up -d

# Test new system
curl http://localhost:30210/health
curl http://localhost:30210/test/abs
```

### Step 4: Update Nginx Configuration
```bash
# Update nginx to route to new backend
sudo nano /etc/nginx/sites-available/agentic-ai.ajinsights.com.au

# Change backend upstream from :30200 to :30210
# Reload nginx
sudo nginx -t && sudo systemctl reload nginx
```

---

## 📁 Required Files for Deployment

### Backend Files to Upload:
```
backend/
├── agents/
│   ├── __init__.py
│   ├── data_agent.py
│   └── agent_registry.py
├── integrations/
│   ├── __init__.py
│   └── abs_client.py
├── tests/
│   ├── __init__.py
│   └── test_abs_agent_comprehensive.py
├── __init__.py
├── main.py
├── requirements.txt
├── Dockerfile
└── run_tests.py
```

### Docker Configuration:
```yaml
# Updated docker-compose.yml backend service
backend:
  build:
    context: ./backend
    dockerfile: Dockerfile
  container_name: abs-agent-backend
  ports:
    - "30200:8000"  # or 30210 for parallel deployment
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
```

---

## 🧪 Testing Checklist

### Pre-Deployment Tests:
- [ ] Local backend runs successfully
- [ ] All ABS queries work locally
- [ ] Docker build completes without errors
- [ ] Health checks pass

### Post-Deployment Tests:
- [ ] Backend container starts successfully
- [ ] Health endpoint responds: `/health`
- [ ] Agents endpoint responds: `/agents`
- [ ] ABS test endpoint works: `/test/abs`
- [ ] Sample queries work via `/query`
- [ ] Frontend can connect to new backend
- [ ] No errors in container logs

### Production Validation:
- [ ] https://agentic-ai.ajinsights.com.au loads
- [ ] ABS queries return proper responses
- [ ] Response times are acceptable (<5 seconds)
- [ ] No 500 errors in logs
- [ ] System remains stable for 10+ minutes

---

## 🔄 Rollback Plan

### If Deployment Fails:
```bash
# Stop new backend
docker-compose stop backend

# Restore original configuration
cp docker-compose.yml.backup docker-compose.yml

# Restart original backend
docker-compose up -d backend

# Verify rollback
curl http://localhost:30200/health
```

### If System is Unstable:
```bash
# Quick rollback to backup
cd /home/admin/backups/[timestamp]
cp -r current_system_backup/* /home/gairforce5/projects/local-agentic-platform/
cd /home/gairforce5/projects/local-agentic-platform/
docker-compose down && docker-compose up -d
```

---

## 📞 Support Commands

### Monitoring:
```bash
# Watch logs
docker-compose logs -f backend

# Check resource usage
docker stats

# Check disk space
df -h

# Check memory
free -h
```

### Debugging:
```bash
# Enter backend container
docker exec -it abs-agent-backend bash

# Test internal endpoints
docker exec abs-agent-backend curl http://localhost:8000/health

# Check Python dependencies
docker exec abs-agent-backend pip list
```

---

## ⚠️ Important Notes

1. **Backup First**: Always backup the current system before deployment
2. **Test Locally**: Ensure everything works in development first
3. **Monitor Closely**: Watch logs and metrics during deployment
4. **Have Rollback Ready**: Be prepared to quickly revert if issues arise
5. **Update DNS**: May need to clear CDN cache after deployment

## 🎯 Expected Results

After successful deployment:
- ABS queries will return detailed, formatted responses (400+ characters)
- Agent routing will work properly (DataAnalysisAgent instead of "unknown")
- All three failing test cases will now pass
- System will be more robust with better error handling

Ready to deploy! 🚀
