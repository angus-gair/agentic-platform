# Troubleshooting Plan: AJ Insights Application Stack

## Overview
This troubleshooting plan provides a systematic approach to getting the AJ Insights application stack running successfully. The stack consists of multiple components that need to be deployed and configured correctly.

## Prerequisites Check

### 1. Environment Setup
```bash
# Check Docker installation
docker --version
docker compose version

# Check current directory
pwd  # Should be /root/agentic-platform/deployment-orchestrator

# Verify .env file exists
ls -la .env

# Check if .env has required variables
cat .env | grep -E "(OPENAI_API_KEY|POSTGRES_PASSWORD|REDIS_PASSWORD)"
```

### 2. Required Environment Variables
Create `.env` file from `.env.example` if missing:
```bash
cp .env.example .env
# Edit .env and fill in required values:
# - OPENAI_API_KEY (required)
# - POSTGRES_PASSWORD (required)  
# - REDIS_PASSWORD (required)
# - GF_ADMIN_PASSWORD (if monitoring enabled)
```

## Step-by-Step Deployment Troubleshooting

### Phase 1: Network and Docker Preparation
```bash
# 1. Create Docker network if it doesn't exist
docker network create agentic-network 2>/dev/null || echo "Network already exists"

# 2. Stop any existing containers
docker stop $(docker ps -q) 2>/dev/null || echo "No containers to stop"

# 3. Clean up orphaned containers
docker system prune -f
```

### Phase 2: Individual Service Deployment

#### Documentation Site (Port 3103)
```bash
# Deploy documentation first (lightest service)
./deploy.sh docs

# Check status
docker ps | grep docs
curl -f http://localhost:3103/ || echo "Docs not responding"

# If failed, check logs
docker logs docs-ajinsights-docs
```

#### Company Website (Port 3102)
```bash
# Deploy company website
./deploy.sh website

# Check status
docker ps | grep website
curl -f http://localhost:3102/ || echo "Website not responding"

# If failed, check logs
docker logs ajinsights-website
```

#### AI Platform (Port 30080)
```bash
# This is the most complex service - deploy last
./deploy.sh platform

# Check all platform containers
docker ps | grep -E "(frontend|backend|postgres|redis|nginx)"

# Check individual components
curl -f http://localhost:3101/ || echo "Frontend not responding"
curl -f http://localhost:8000/health || echo "Backend not responding"
curl -f http://localhost:30080/ || echo "Nginx not responding"
```

### Phase 3: Health Verification
```bash
# Run comprehensive health check
./deploy.sh health

# Manual health checks
echo "=== Service Health Check ==="
echo "Documentation: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:3103/)"
echo "Website: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:3102/)"
echo "AI Platform: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:30080/)"
```

## Common Issues and Solutions

### Issue 1: Port Conflicts
**Symptoms**: Container fails to start, "port already in use" errors
```bash
# Check what's using the ports
sudo netstat -tlnp | grep -E ":3102|:3103|:30080|:3101|:8000"

# Kill processes using required ports
sudo fuser -k 3102/tcp 3103/tcp 30080/tcp 3101/tcp 8000/tcp
```

### Issue 2: Docker Build Failures
**Symptoms**: "No such file or directory", build context errors
```bash
# Verify repository structure
ls -la /root/
ls -la /root/local-agentic-ai-comprehensive-documentation/
ls -la /root/aj-insights_com_au/
ls -la /root/local-agentic-platform/

# Check Dockerfiles exist
find /root -name "Dockerfile" -type f
```

### Issue 3: Environment Variable Issues
**Symptoms**: Services start but fail functionally, database connection errors
```bash
# Verify .env file is properly formatted
cat /root/agentic-platform/deployment-orchestrator/.env | grep -v "^#" | grep "="

# Check if variables are being loaded
docker exec ajinsights-website env | grep NODE_ENV
```

### Issue 4: Database Connection Issues
**Symptoms**: Backend fails to connect to PostgreSQL/Redis
```bash
# Check database containers are running
docker ps | grep -E "(postgres|redis)"

# Test database connectivity
docker exec -it postgres-container psql -U admin -d agentic_platform -c "SELECT 1;"
docker exec -it redis-container redis-cli ping
```

### Issue 5: Nginx Configuration Issues
**Symptoms**: 502 Bad Gateway, upstream connection errors
```bash
# Check nginx container logs
docker logs nginx-container

# Verify upstream services are responding
curl -f http://localhost:3101/
curl -f http://localhost:8000/health

# Test nginx config inside container
docker exec nginx-container nginx -t
```

## Systematic Troubleshooting Steps

### 1. Quick Status Check
```bash
# One-liner status check
echo "Docker: $(docker --version | cut -d' ' -f3), Containers: $(docker ps -q | wc -l), Network: $(docker network ls | grep agentic | wc -l)"
```

### 2. Progressive Deployment
Deploy services in order of complexity:
1. Documentation (simplest)
2. Company Website (standalone)
3. AI Platform (most complex)

### 3. Log Analysis
```bash
# Create log analysis script
cat > check_logs.sh << 'EOF'
#!/bin/bash
echo "=== Recent Docker Logs ==="
for container in $(docker ps --format "{{.Names}}"); do
    echo "--- $container ---"
    docker logs --tail 10 $container 2>&1 | head -5
done
EOF
chmod +x check_logs.sh
./check_logs.sh
```

### 4. Resource Check
```bash
# Check system resources
df -h                    # Disk space
free -h                  # Memory
docker system df         # Docker space usage
```

## Recovery Procedures

### Complete Reset
```bash
# Nuclear option - complete reset
./deploy.sh stop all
docker system prune -a -f
docker volume prune -f
docker network prune -f

# Recreate network
docker network create agentic-network

# Redeploy from scratch
./deploy.sh all
```

### Partial Reset (Single Service)
```bash
# Reset specific service
./deploy.sh stop docs
docker rmi $(docker images | grep docs | awk '{print $3}')
./deploy.sh docs
```

## Validation Checklist

- [ ] All required repositories exist in /root/
- [ ] .env file exists with all required variables
- [ ] Docker and docker-compose are functional
- [ ] Ports 3102, 3103, 30080 are available
- [ ] Docker network 'agentic-network' exists
- [ ] All containers start without errors
- [ ] Health endpoints respond correctly
- [ ] Logs show no critical errors

## Success Criteria

The application is successfully running when:
1. **Documentation**: http://localhost:3103/ returns 200
2. **Company Website**: http://localhost:3102/ returns 200  
3. **AI Platform**: http://localhost:30080/ returns 200
4. All Docker containers show "Up" status
5. No critical errors in container logs

## Next Steps After Successful Deployment

1. Configure Nginx reverse proxy (if not using Cloudflare)
2. Set up SSL certificates (if not using Cloudflare)
3. Configure monitoring (if ENABLE_METRICS=true)
4. Set up automated backups
5. Configure log rotation
6. Test external domain access

---
*Generated on: $(date)*
*Environment: Multi-container Docker deployment*
*Orchestrator Version: 1.0.0*