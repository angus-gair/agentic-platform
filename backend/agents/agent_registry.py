#!/usr/bin/env python3
"""
Agent Registry System for managing and routing queries to appropriate agents
Handles agent discovery, intent classification, and query routing
"""

import logging
from typing import Dict, List, Optional, Any, Type
from datetime import datetime
import asyncio

# Import agents
from .data_agent import DataAnalysisAgent

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AgentRegistry:
    """Central registry for managing all agents in the system"""
    
    def __init__(self):
        self.agents = {}
        self.agent_instances = {}
        self._initialize_agents()
    
    def _initialize_agents(self):
        """Initialize and register all available agents"""
        try:
            # Register DataAnalysisAgent
            self.register_agent('DataAnalysisAgent', DataAnalysisAgent)
            logger.info("Successfully registered DataAnalysisAgent")
            
        except Exception as e:
            logger.error(f"Error initializing agents: {e}")
    
    def register_agent(self, name: str, agent_class: Type):
        """Register an agent class"""
        self.agents[name] = agent_class
        logger.info(f"Registered agent: {name}")
    
    def get_agent_instance(self, name: str):
        """Get or create an agent instance"""
        if name not in self.agent_instances:
            if name in self.agents:
                self.agent_instances[name] = self.agents[name]()
                logger.info(f"Created instance of {name}")
            else:
                raise ValueError(f"Agent {name} not found in registry")
        
        return self.agent_instances[name]
    
    async def route_query(self, query: str, session_id: str = None) -> Dict[str, Any]:
        """Route a query to the appropriate agent"""
        try:
            # Find the best agent for this query
            best_agent = self._find_best_agent(query)
            
            if not best_agent:
                return {
                    'agent': 'unknown',
                    'intent': 'unknown', 
                    'response': 'No suitable agent found for this query',
                    'success': False
                }
            
            # Get agent instance and process query
            agent_instance = self.get_agent_instance(best_agent)
            result = await agent_instance.process_query(query, session_id)
            
            logger.info(f"Query routed to {best_agent}: {result.get('success', False)}")
            return result
            
        except Exception as e:
            logger.error(f"Error routing query: {e}")
            return {
                'agent': 'error',
                'intent': 'error',
                'response': f'Error processing query: {str(e)}',
                'success': False,
                'error': str(e)
            }
    
    def _find_best_agent(self, query: str) -> Optional[str]:
        """Find the best agent to handle a given query"""
        try:
            # Check each registered agent
            for agent_name, agent_class in self.agents.items():
                # Get or create instance
                agent_instance = self.get_agent_instance(agent_name)
                
                # Check if agent can handle this query
                if hasattr(agent_instance, 'can_handle') and agent_instance.can_handle(query):
                    return agent_name
            
            return None
            
        except Exception as e:
            logger.error(f"Error finding best agent: {e}")
            return None
    
    def list_agents(self) -> List[str]:
        """List all registered agents"""
        return list(self.agents.keys())
    
    def get_agent_info(self, agent_name: str) -> Dict[str, Any]:
        """Get information about a specific agent"""
        if agent_name not in self.agents:
            return {'error': f'Agent {agent_name} not found'}
        
        try:
            agent_instance = self.get_agent_instance(agent_name)
            
            info = {
                'name': agent_name,
                'class': self.agents[agent_name].__name__,
                'status': 'active'
            }
            
            # Add supported intents if available
            if hasattr(agent_instance, 'supported_intents'):
                info['supported_intents'] = agent_instance.supported_intents
            
            return info
            
        except Exception as e:
            return {
                'name': agent_name,
                'status': 'error',
                'error': str(e)
            }
    
    async def health_check(self) -> Dict[str, Any]:
        """Perform health check on all agents"""
        health_status = {
            'timestamp': datetime.now().isoformat(),
            'total_agents': len(self.agents),
            'agents': {}
        }
        
        for agent_name in self.agents.keys():
            try:
                agent_instance = self.get_agent_instance(agent_name)
                
                # Basic health check
                health_status['agents'][agent_name] = {
                    'status': 'healthy',
                    'instance_created': agent_name in self.agent_instances
                }
                
                # Additional health checks if agent supports them
                if hasattr(agent_instance, 'health_check'):
                    agent_health = await agent_instance.health_check()
                    health_status['agents'][agent_name].update(agent_health)
                    
            except Exception as e:
                health_status['agents'][agent_name] = {
                    'status': 'unhealthy',
                    'error': str(e)
                }
        
        return health_status

# Global registry instance
_registry = None

def get_registry() -> AgentRegistry:
    """Get the global agent registry instance"""
    global _registry
    if _registry is None:
        _registry = AgentRegistry()
    return _registry

async def process_query(query: str, session_id: str = None) -> Dict[str, Any]:
    """Convenience function to process a query through the registry"""
    registry = get_registry()
    return await registry.route_query(query, session_id)

def list_available_agents() -> List[str]:
    """List all available agents"""
    registry = get_registry()
    return registry.list_agents()

async def system_health_check() -> Dict[str, Any]:
    """Perform system-wide health check"""
    registry = get_registry()
    return await registry.health_check()

# Test function for debugging
async def test_abs_queries():
    """Test the ABS agent with sample queries"""
    test_queries = [
        "What is the current population of New South Wales?",
        "Show me employment statistics for Australia", 
        "Can you analyze housing price trends using ABS data?"
    ]
    
    results = []
    for query in test_queries:
        result = await process_query(query, f"test_{int(datetime.now().timestamp())}")
        results.append({
            'query': query,
            'result': result
        })
        logger.info(f"Test query: {query} -> Agent: {result.get('agent', 'unknown')}")
    
    return results

if __name__ == "__main__":
    # Run test queries
    asyncio.run(test_abs_queries())
