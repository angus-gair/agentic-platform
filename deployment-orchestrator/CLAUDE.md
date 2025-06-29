# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Deployment orchestrator for ajinsights.app ecosystem - coordinates Docker deployments across multiple domains and services.

## Essential Commands

```bash
# Primary deployments
./deploy.sh all                    # Deploy all services
./deploy.sh website|platform|docs  # Deploy individual services
./deploy.sh health                 # Check service health
./deploy.sh logs <service>         # View logs
./deploy.sh stop [service]         # Stop services

# Infrastructure
sudo ./nginx-config.sh             # Configure Nginx reverse proxy
node index.js deploy --service <name>  # Advanced CLI operations
npm install                        # Install dependencies
```

## Architecture

**Domains (.com.au deployment active):**
- www.ajinsights.com.au (3102): Company website
- agentic-ai.ajinsights.com.au (30080): AI platform  
- docs.ajinsights.com.au (3103): Documentation
- monitoring.ajinsights.com.au (3000): Grafana (disabled)

**Key Files:**
- `enhanced-deployments.yml`: Master service registry, port allocation (30000-30999)
- `deploy.sh`: Main deployment orchestration
- `nginx-comau-config.sh`: .com.au domain nginx setup
- `nginx-config.sh`: Automated reverse proxy setup
- `.env`: Environment variables (copy from `.env.example`)

**Infrastructure:**
- Server: thunder1.vps.webdock.cloud (65.109.1.180) - NEW SERVER (migrated from 193.181.208.69)
- SSL: Cloudflare termination, HTTP internally
- Docker network: `agentic-network`
- Port ranges: 30000-30099 (public), 30100-30199 (frontend), 30200-30299 (backend)
- Metrics: ENABLE_METRICS=false (Grafana disabled)
- Network: 268.6 Mbps to Cloudflare, 14ms latency
- Nginx: Active and configured for all .com.au domains
- Status: Production deployment active as of 2025-06-29

## Critical Patterns

**Before adding services:** Check `enhanced-deployments.yml` port registry, use appropriate ranges
**Environment:** Required vars: OPENAI_API_KEY, POSTGRES_PASSWORD, REDIS_PASSWORD, GF_ADMIN_PASSWORD  
**Health checks:** Services expose endpoints at localhost ports for validation
**Secrets:** Use `.env` file, never commit credentials

Technology: Node.js ES modules, Docker Compose, Bash, targeting Ubuntu LEMP VPS