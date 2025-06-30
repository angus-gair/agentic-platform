#!/usr/bin/env python3
"""
Test runner for ABS Agent debugging
Runs comprehensive tests to validate the implementation
"""

import asyncio
import sys
import os
import json
from datetime import datetime

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

async def main():
    """Main test execution"""
    print("🚀 ABS Agent Debugging Test Suite")
    print("=" * 50)
    
    try:
        # Import test functions
        from tests.test_abs_agent_comprehensive import run_failing_query_tests, run_comprehensive_health_check
        
        print("\n📊 Testing failing queries...")
        query_results = await run_failing_query_tests()
        
        print("\n🏥 Running health checks...")
        health_results = await run_comprehensive_health_check()
        
        # Summary
        print("\n📋 Test Summary:")
        print("-" * 30)
        
        successful_queries = sum(1 for r in query_results if r.get('success', False))
        total_queries = len(query_results)
        
        print(f"Query Tests: {successful_queries}/{total_queries} passed")
        
        if health_results['system']['agents'].get('DataAnalysisAgent', {}).get('status') == 'healthy':
            print("Agent Health: ✅ Healthy")
        else:
            print("Agent Health: ❌ Unhealthy")
        
        if health_results['abs_api'].get('connection', False):
            print("ABS API: ✅ Connected")
        else:
            print("ABS API: ⚠️ Connection issues")
        
        # Save results
        results = {
            'timestamp': datetime.now().isoformat(),
            'query_tests': query_results,
            'health_check': health_results,
            'summary': {
                'successful_queries': successful_queries,
                'total_queries': total_queries,
                'agent_healthy': health_results['system']['agents'].get('DataAnalysisAgent', {}).get('status') == 'healthy',
                'api_connected': health_results['abs_api'].get('connection', False)
            }
        }
        
        with open('test_results.json', 'w') as f:
            json.dump(results, f, indent=2)
        
        print(f"\n💾 Results saved to test_results.json")
        
        # Return success status
        return successful_queries == total_queries
        
    except Exception as e:
        print(f"❌ Test execution failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)
