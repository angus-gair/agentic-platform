#!/usr/bin/env python3
"""
Comprehensive ABS Agent Debugging Script
Tests all components and provides detailed diagnostics
"""

import asyncio
import sys
import os
import json
import subprocess
from datetime import datetime
import time

# Add backend to path
backend_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'backend')
sys.path.insert(0, backend_path)

def print_header(title):
    """Print formatted header"""
    print(f"\n{'='*60}")
    print(f"🔍 {title}")
    print(f"{'='*60}")

def print_section(title):
    """Print formatted section"""
    print(f"\n{'─'*40}")
    print(f"📋 {title}")
    print(f"{'─'*40}")

async def test_imports():
    """Test that all modules can be imported"""
    print_section("Testing Module Imports")
    
    try:
        from backend.integrations.abs_client import ABSDataClient
        print("✅ ABSDataClient imported successfully")
    except Exception as e:
        print(f"❌ Failed to import ABSDataClient: {e}")
        return False
    
    try:
        from backend.agents.data_agent import DataAnalysisAgent
        print("✅ DataAnalysisAgent imported successfully")
    except Exception as e:
        print(f"❌ Failed to import DataAnalysisAgent: {e}")
        return False
    
    try:
        from backend.agents.agent_registry import get_registry, process_query
        print("✅ Agent registry imported successfully")
    except Exception as e:
        print(f"❌ Failed to import agent registry: {e}")
        return False
    
    return True

async def test_agent_registration():
    """Test agent registration and discovery"""
    print_section("Testing Agent Registration")
    
    try:
        from backend.agents.agent_registry import get_registry
        registry = get_registry()
        
        agents = registry.list_agents()
        print(f"📊 Registered agents: {agents}")
        
        if 'DataAnalysisAgent' in agents:
            print("✅ DataAnalysisAgent is registered")
            
            # Test agent info
            info = registry.get_agent_info('DataAnalysisAgent')
            print(f"📋 Agent info: {json.dumps(info, indent=2)}")
            
            return True
        else:
            print("❌ DataAnalysisAgent not found in registry")
            return False
            
    except Exception as e:
        print(f"❌ Agent registration test failed: {e}")
        return False

async def test_abs_api_connectivity():
    """Test ABS API connectivity"""
    print_section("Testing ABS API Connectivity")
    
    try:
        from backend.integrations.abs_client import ABSDataClient
        client = ABSDataClient()
        
        print("🌐 Testing ABS API connection...")
        health = await client.test_connection_enhanced()
        
        print(f"📊 Connection result: {json.dumps(health, indent=2)}")
        
        if health.get('connection'):
            print("✅ ABS API is accessible")
            return True
        else:
            print("⚠️ ABS API connection failed (may be temporary)")
            return False
            
    except Exception as e:
        print(f"❌ ABS API test failed: {e}")
        return False

async def test_failing_queries():
    """Test the specific queries that were failing"""
    print_section("Testing Previously Failing Queries")
    
    failing_queries = [
        "What is the current population of New South Wales?",
        "Show me employment statistics for Australia",
        "Can you analyze housing price trends using ABS data?"
    ]
    
    try:
        from backend.agents.agent_registry import process_query
        
        results = []
        for i, query in enumerate(failing_queries, 1):
            print(f"\n🧪 Test {i}: {query}")
            
            start_time = time.time()
            result = await process_query(query, f"debug_test_{i}")
            end_time = time.time()
            
            response_time = end_time - start_time
            
            print(f"   Agent: {result.get('agent', 'unknown')}")
            print(f"   Intent: {result.get('intent', 'unknown')}")
            print(f"   Success: {result.get('success', False)}")
            print(f"   Response Time: {response_time:.2f}s")
            print(f"   Response Length: {len(str(result.get('response', '')))}")
            
            if result.get('response'):
                preview = str(result['response'])[:150]
                print(f"   Response Preview: {preview}...")
            
            if result.get('error'):
                print(f"   Error: {result['error']}")
            
            results.append({
                'query': query,
                'agent': result.get('agent', 'unknown'),
                'intent': result.get('intent', 'unknown'),
                'success': result.get('success', False),
                'response_time': response_time,
                'response_length': len(str(result.get('response', ''))),
                'error': result.get('error')
            })
        
        # Summary
        successful = sum(1 for r in results if r['success'])
        print(f"\n📊 Query Test Summary: {successful}/{len(results)} successful")
        
        return results
        
    except Exception as e:
        print(f"❌ Query testing failed: {e}")
        import traceback
        traceback.print_exc()
        return []

async def test_data_retrieval():
    """Test individual data retrieval methods"""
    print_section("Testing Data Retrieval Methods")
    
    try:
        from backend.integrations.abs_client import ABSDataClient
        client = ABSDataClient()
        
        methods = [
            ('get_cpi_data_enhanced', 'CPI Data'),
            ('get_population_data_enhanced', 'Population Data'),
            ('get_employment_data', 'Employment Data'),
            ('get_housing_data', 'Housing Data')
        ]
        
        for method_name, description in methods:
            print(f"\n🔍 Testing {description}...")
            
            try:
                method = getattr(client, method_name)
                df = await method(latest_quarters=2)
                
                if hasattr(df, 'empty'):
                    if df.empty:
                        print(f"   ⚠️ {description}: No data returned (API may be down)")
                    else:
                        print(f"   ✅ {description}: {len(df)} records retrieved")
                else:
                    print(f"   ❌ {description}: Invalid response type")
                    
            except Exception as e:
                print(f"   ❌ {description}: Error - {e}")
        
        return True
        
    except Exception as e:
        print(f"❌ Data retrieval testing failed: {e}")
        return False

async def run_comprehensive_diagnostics():
    """Run all diagnostic tests"""
    print_header("ABS Agent Comprehensive Diagnostics")
    
    results = {
        'timestamp': datetime.now().isoformat(),
        'tests': {}
    }
    
    # Test 1: Module imports
    results['tests']['imports'] = await test_imports()
    
    # Test 2: Agent registration
    results['tests']['registration'] = await test_agent_registration()
    
    # Test 3: ABS API connectivity
    results['tests']['api_connectivity'] = await test_abs_api_connectivity()
    
    # Test 4: Failing queries
    query_results = await test_failing_queries()
    results['tests']['queries'] = query_results
    results['tests']['query_success'] = len([r for r in query_results if r.get('success')]) > 0
    
    # Test 5: Data retrieval
    results['tests']['data_retrieval'] = await test_data_retrieval()
    
    # Overall summary
    print_header("Diagnostic Summary")
    
    passed_tests = sum(1 for test, result in results['tests'].items() 
                      if test != 'queries' and result)
    total_tests = len([t for t in results['tests'].keys() if t != 'queries'])
    
    print(f"📊 Core Tests: {passed_tests}/{total_tests} passed")
    
    if query_results:
        successful_queries = sum(1 for r in query_results if r.get('success'))
        print(f"📊 Query Tests: {successful_queries}/{len(query_results)} successful")
    
    # Recommendations
    print_section("Recommendations")
    
    if not results['tests']['imports']:
        print("🔧 Fix module import issues first")
    elif not results['tests']['registration']:
        print("🔧 Fix agent registration system")
    elif not results['tests']['api_connectivity']:
        print("🔧 Check ABS API connectivity (may be temporary)")
    elif not results['tests']['query_success']:
        print("🔧 Debug query processing pipeline")
    else:
        print("✅ All core systems appear to be working!")
    
    # Save results
    with open('diagnostic_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n💾 Detailed results saved to diagnostic_results.json")
    
    return results

if __name__ == "__main__":
    print("🚀 Starting ABS Agent Comprehensive Diagnostics...")
    
    try:
        results = asyncio.run(run_comprehensive_diagnostics())
        
        # Exit with appropriate code
        if results['tests']['imports'] and results['tests']['registration']:
            print("\n✅ Diagnostics completed successfully")
            sys.exit(0)
        else:
            print("\n❌ Critical issues found")
            sys.exit(1)
            
    except Exception as e:
        print(f"\n💥 Diagnostic execution failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
