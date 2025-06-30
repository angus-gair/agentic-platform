#!/usr/bin/env python3
"""
Main API server for the ABS Agent system
Provides REST endpoints for query processing and health checks
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, Any, Optional
import logging
import asyncio
from datetime import datetime
import uvicorn

# Import agent system
from agents.agent_registry import process_query, system_health_check, list_available_agents

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# FastAPI app
app = FastAPI(
    title="ABS Agent API",
    description="Australian Bureau of Statistics Data Analysis Agent",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request/Response models
class QueryRequest(BaseModel):
    query: str
    session_id: Optional[str] = None

class QueryResponse(BaseModel):
    agent: str
    intent: str
    response: str
    success: bool
    timestamp: str
    session_id: Optional[str] = None
    error: Optional[str] = None

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "ABS Agent API",
        "version": "1.0.0",
        "status": "running",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        health = await system_health_check()
        return {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "details": health
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=500, detail=f"Health check failed: {str(e)}")

@app.get("/agents")
async def list_agents():
    """List available agents"""
    try:
        agents = list_available_agents()
        return {
            "agents": agents,
            "count": len(agents),
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Failed to list agents: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to list agents: {str(e)}")

@app.post("/query", response_model=QueryResponse)
async def process_user_query(request: QueryRequest):
    """Process a user query through the agent system"""
    try:
        logger.info(f"Processing query: {request.query[:100]}...")
        
        # Process query through agent registry
        result = await process_query(request.query, request.session_id)
        
        # Format response
        response = QueryResponse(
            agent=result.get('agent', 'unknown'),
            intent=result.get('intent', 'unknown'),
            response=result.get('response', 'No response generated'),
            success=result.get('success', False),
            timestamp=result.get('timestamp', datetime.now().isoformat()),
            session_id=request.session_id,
            error=result.get('error')
        )
        
        logger.info(f"Query processed: agent={response.agent}, success={response.success}")
        return response
        
    except Exception as e:
        logger.error(f"Error processing query: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing query: {str(e)}")

@app.get("/test/abs")
async def test_abs_queries():
    """Test endpoint for ABS queries"""
    test_queries = [
        "What is the current population of New South Wales?",
        "Show me employment statistics for Australia",
        "Can you analyze housing price trends using ABS data?"
    ]
    
    results = []
    for query in test_queries:
        try:
            result = await process_query(query, f"test_{int(datetime.now().timestamp())}")
            results.append({
                'query': query,
                'agent': result.get('agent', 'unknown'),
                'intent': result.get('intent', 'unknown'),
                'success': result.get('success', False),
                'response_length': len(str(result.get('response', ''))),
                'error': result.get('error')
            })
        except Exception as e:
            results.append({
                'query': query,
                'error': str(e),
                'success': False
            })
    
    return {
        'test_results': results,
        'timestamp': datetime.now().isoformat()
    }

@app.get("/debug/registry")
async def debug_registry():
    """Debug endpoint for agent registry information"""
    try:
        from agents.agent_registry import get_registry
        registry = get_registry()
        
        debug_info = {
            'registered_agents': registry.list_agents(),
            'agent_details': {}
        }
        
        for agent_name in registry.list_agents():
            debug_info['agent_details'][agent_name] = registry.get_agent_info(agent_name)
        
        return debug_info
        
    except Exception as e:
        logger.error(f"Debug registry failed: {e}")
        raise HTTPException(status_code=500, detail=f"Debug failed: {str(e)}")

# Error handlers
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {exc}")
    return {
        "error": "Internal server error",
        "detail": str(exc),
        "timestamp": datetime.now().isoformat()
    }

if __name__ == "__main__":
    # Run the server
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
