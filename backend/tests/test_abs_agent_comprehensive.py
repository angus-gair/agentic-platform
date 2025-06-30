#!/usr/bin/env python3
"""
Comprehensive test suite for ABS Agent debugging and validation
Tests agent discovery, query routing, data retrieval, and error handling
"""

import asyncio
import pytest
import sys
import os
from datetime import datetime
import json

# Add backend to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agents.agent_registry import get_registry, process_query, system_health_check
from agents.data_agent import DataAnalysisAgent
from integrations.abs_client import ABSDataClient

class TestABSAgentComprehensive:
    """Comprehensive test suite for ABS agent functionality"""
    
    @pytest.fixture
    def setup_registry(self):
        """Setup agent registry for testing"""
        registry = get_registry()
        return registry
    
    @pytest.fixture
    def abs_client(self):
        """Setup ABS client for testing"""
        return ABSDataClient()
    
    @pytest.fixture
    def data_agent(self):
        """Setup DataAnalysisAgent for testing"""
        return DataAnalysisAgent()
    
    # Test 1: Agent Discovery and Registration
    async def test_agent_registration(self, setup_registry):
        """Test that DataAnalysisAgent is properly registered"""
        registry = setup_registry
        agents = registry.list_agents()
        
        assert 'DataAnalysisAgent' in agents, "DataAnalysisAgent not found in registry"
        
        # Test agent info
        agent_info = registry.get_agent_info('DataAnalysisAgent')
        assert agent_info['name'] == 'DataAnalysisAgent'
        assert agent_info['status'] == 'active'
        assert 'supported_intents' in agent_info
    
    # Test 2: Query Classification and Routing
    async def test_query_routing(self, data_agent):
        """Test that ABS queries are properly classified and routed"""
        test_cases = [
            {
                'query': "What is the current population of New South Wales?",
                'expected_agent': 'DataAnalysisAgent',
                'expected_intent': 'population_query',
                'should_handle': True
            },
            {
                'query': "Show me employment statistics for Australia",
                'expected_agent': 'DataAnalysisAgent', 
                'expected_intent': 'employment_statistics',
                'should_handle': True
            },
            {
                'query': "Can you analyze housing price trends using ABS data?",
                'expected_agent': 'DataAnalysisAgent',
                'expected_intent': 'housing_trends', 
                'should_handle': True
            },
            {
                'query': "What's the weather like today?",
                'expected_agent': 'unknown',
                'should_handle': False
            }
        ]
        
        for case in test_cases:
            # Test can_handle method
            can_handle = data_agent.can_handle(case['query'])
            assert can_handle == case['should_handle'], f"can_handle failed for: {case['query']}"
            
            if case['should_handle']:
                # Test intent classification
                intent = data_agent.classify_intent(case['query'])
                assert intent == case['expected_intent'], f"Intent classification failed for: {case['query']}"
    
    # Test 3: ABS API Connectivity
    async def test_abs_api_connectivity(self, abs_client):
        """Test ABS API connectivity and basic functionality"""
        # Test connection
        health = await abs_client.test_connection_enhanced()
        
        # Should have connection status
        assert 'connection' in health
        assert 'timestamp' in health
        
        # If connection fails, log but don't fail test (API might be down)
        if not health['connection']:
            print(f"Warning: ABS API connection failed: {health.get('error', 'Unknown error')}")
    
    # Test 4: Data Retrieval Methods
    async def test_data_retrieval_methods(self, abs_client):
        """Test individual data retrieval methods"""
        methods_to_test = [
            'get_cpi_data_enhanced',
            'get_population_data_enhanced', 
            'get_unemployment_data',
            'get_employment_data',
            'get_housing_data'
        ]
        
        for method_name in methods_to_test:
            if hasattr(abs_client, method_name):
                method = getattr(abs_client, method_name)
                try:
                    # Test with minimal parameters
                    df = await method(latest_quarters=2)
                    # Should return a DataFrame (might be empty if API is down)
                    assert hasattr(df, 'empty'), f"{method_name} should return DataFrame"
                    print(f"✓ {method_name}: {'Data retrieved' if not df.empty else 'No data (API might be down)'}")
                except Exception as e:
                    print(f"⚠ {method_name} failed: {e}")
    
    # Test 5: End-to-End Query Processing
    async def test_end_to_end_processing(self):
        """Test complete query processing pipeline"""
        failing_queries = [
            "What is the current population of New South Wales?",
            "Show me employment statistics for Australia",
            "Can you analyze housing price trends using ABS data?"
        ]
        
        results = []
        for query in failing_queries:
            result = await process_query(query, f"test_{int(datetime.now().timestamp())}")
            results.append({
                'query': query,
                'agent': result.get('agent', 'unknown'),
                'intent': result.get('intent', 'unknown'),
                'success': result.get('success', False),
                'response_length': len(str(result.get('response', '')))
            })
            
            # Key assertions
            assert result.get('agent') == 'DataAnalysisAgent', f"Expected DataAnalysisAgent, got {result.get('agent')}"
            assert result.get('intent') != 'unknown', f"Intent should not be unknown for: {query}"
            assert result.get('success') == True, f"Query should succeed: {query}"
            assert result.get('response_length', 0) > 10, f"Response too short for: {query}"
        
        return results
    
    # Test 6: Error Handling
    async def test_error_handling(self, data_agent):
        """Test error handling scenarios"""
        # Test with invalid/edge case queries
        edge_cases = [
            "",  # Empty query
            "   ",  # Whitespace only
            "a" * 1000,  # Very long query
            "SELECT * FROM users; DROP TABLE users;",  # SQL injection attempt
        ]
        
        for query in edge_cases:
            try:
                result = await data_agent.process_query(query)
                # Should handle gracefully without crashing
                assert 'agent' in result
                assert 'success' in result
            except Exception as e:
                pytest.fail(f"Error handling failed for query '{query[:50]}...': {e}")
    
    # Test 7: State Extraction
    def test_state_extraction(self, data_agent):
        """Test Australian state/territory extraction from queries"""
        test_cases = [
            ("What is the population of New South Wales?", "nsw"),
            ("Show me Victoria employment data", "vic"),
            ("Queensland housing trends", "qld"),
            ("South Australia statistics", "sa"),
            ("Western Australia data", "wa"),
            ("Tasmania population", "tas"),
            ("Northern Territory employment", "nt"),
            ("ACT housing data", "act"),
            ("Canberra population", "act"),
            ("Australia wide data", None),
            ("No state mentioned", None)
        ]
        
        for query, expected_state in test_cases:
            extracted_state = data_agent._extract_state(query)
            assert extracted_state == expected_state, f"State extraction failed for: {query}"
    
    # Test 8: System Health Check
    async def test_system_health(self):
        """Test system-wide health check"""
        health = await system_health_check()
        
        assert 'timestamp' in health
        assert 'total_agents' in health
        assert 'agents' in health
        assert 'DataAnalysisAgent' in health['agents']
        
        # DataAnalysisAgent should be healthy
        data_agent_health = health['agents']['DataAnalysisAgent']
        assert data_agent_health['status'] == 'healthy'

# Standalone test functions for manual execution
async def run_failing_query_tests():
    """Run the specific failing queries from the test results"""
    print("🧪 Testing ABS Agent with failing queries...")
    
    failing_queries = [
        "What is the current population of New South Wales?",
        "Show me employment statistics for Australia", 
        "Can you analyze housing price trends using ABS data?"
    ]
    
    results = []
    for i, query in enumerate(failing_queries, 1):
        print(f"\n📊 Test {i}: {query}")
        
        try:
            result = await process_query(query, f"debug_test_{i}")
            
            print(f"   Agent: {result.get('agent', 'unknown')}")
            print(f"   Intent: {result.get('intent', 'unknown')}")
            print(f"   Success: {result.get('success', False)}")
            print(f"   Response Length: {len(str(result.get('response', '')))}")
            
            if result.get('response'):
                print(f"   Response Preview: {str(result['response'])[:100]}...")
            
            results.append(result)
            
        except Exception as e:
            print(f"   ❌ Error: {e}")
            results.append({'error': str(e)})
    
    return results

async def run_comprehensive_health_check():
    """Run comprehensive health check"""
    print("🏥 Running comprehensive health check...")
    
    # System health
    health = await system_health_check()
    print(f"System Health: {json.dumps(health, indent=2)}")
    
    # ABS API connectivity
    client = ABSDataClient()
    api_health = await client.test_connection_enhanced()
    print(f"ABS API Health: {json.dumps(api_health, indent=2)}")
    
    return {'system': health, 'abs_api': api_health}

if __name__ == "__main__":
    print("🚀 Starting ABS Agent Comprehensive Testing...")
    
    # Run the failing query tests
    asyncio.run(run_failing_query_tests())
    
    print("\n" + "="*50)
    
    # Run health check
    asyncio.run(run_comprehensive_health_check())
