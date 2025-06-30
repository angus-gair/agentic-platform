#!/usr/bin/env python3
"""
Enhanced ABS Data Client for Australian Bureau of Statistics API
Supports multiple datasets, time filtering, and state-based filtering
Updated November 2024 - No API key required
"""

import asyncio
import httpx
import pandas as pd
import json
import logging
from typing import Dict, List, Optional, Union, Any
from datetime import datetime, timedelta
import time

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ABSDataClient:
    """Enhanced client for Australian Bureau of Statistics API"""
    
    def __init__(self):
        self.base_url = "https://data.api.abs.gov.au/rest/data/ABS"
        self.timeout = 30
        self.max_retries = 3
        
        # Dataset mappings (simplified for current ABS API)
        self.datasets = {
            'cpi': 'CPI',
            'population': 'ABS_ANNUAL_ERP_ASGS2016',  # Annual population estimates
            'unemployment': 'ABS_MONTHLY_LF_T1',
            'employment': 'ABS_MONTHLY_LF_T1',
            'labour_force': 'ABS_MONTHLY_LF_T1',
            'gdp': 'ABS_QUARTERLY_GDP',
            'housing': 'ABS_MONTHLY_BA_T1'
        }
        
        # State code mappings
        self.state_codes = {
            'nsw': '1',
            'vic': '2', 
            'qld': '3',
            'sa': '4',
            'wa': '5',
            'tas': '6',
            'nt': '7',
            'act': '8',
            'australia': '0'
        }
    
    async def test_connection_enhanced(self) -> Dict[str, Any]:
        """Test ABS API connectivity and return health status"""
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                # Test with a simple CPI query
                url = f"{self.base_url},CPI"
                response = await client.get(url)
                
                return {
                    'connection': response.status_code == 200,
                    'status_code': response.status_code,
                    'response_time': response.elapsed.total_seconds() if hasattr(response, 'elapsed') else 0,
                    'timestamp': datetime.now().isoformat()
                }
        except Exception as e:
            logger.error(f"Connection test failed: {e}")
            return {
                'connection': False,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    async def get_data_enhanced(self, dataset_id: str, **kwargs) -> pd.DataFrame:
        """Enhanced data retrieval with comprehensive error handling"""
        max_retries = kwargs.get('max_retries', self.max_retries)
        
        for attempt in range(max_retries):
            try:
                return await self._fetch_data_primary(dataset_id, **kwargs)
                
            except httpx.TimeoutException:
                if attempt < max_retries - 1:
                    await asyncio.sleep(2 ** attempt)  # Exponential backoff
                    continue
                raise Exception("Request timeout after all retries")
                
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 429:  # Rate limited
                    await asyncio.sleep(2 ** attempt)
                    continue
                elif e.response.status_code == 404:
                    return pd.DataFrame()  # Dataset not found
                else:
                    raise
                    
            except Exception as e:
                logger.error(f"Attempt {attempt + 1} failed: {e}")
                if attempt == max_retries - 1:
                    raise
                await asyncio.sleep(2 ** attempt)
    
    async def _fetch_data_primary(self, dataset_id: str, **kwargs) -> pd.DataFrame:
        """Primary data fetching method with improved error handling"""
        # Build URL with parameters
        url = f"{self.base_url},{dataset_id}"
        params = self._build_params(**kwargs)

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()

            # Handle different response types
            content_type = response.headers.get('content-type', '')

            if 'application/json' in content_type:
                try:
                    data = response.json()
                    return self._parse_sdmx_response(data)
                except json.JSONDecodeError:
                    logger.warning("Failed to parse JSON response, trying text parsing")
                    return self._parse_text_response(response.text)
            else:
                # Handle CSV or other text formats
                return self._parse_text_response(response.text)
    
    def _build_params(self, **kwargs) -> Dict[str, str]:
        """Build query parameters for ABS API"""
        params = {}
        
        # Time filtering
        if 'latest_quarters' in kwargs:
            params['lastNObservations'] = str(kwargs['latest_quarters'])
        elif 'first_quarters' in kwargs:
            params['firstNObservations'] = str(kwargs['first_quarters'])
        
        # Date filtering
        if 'updated_after' in kwargs:
            params['updatedAfter'] = kwargs['updated_after']
        
        # State filtering
        if 'state' in kwargs:
            state_code = self.state_codes.get(kwargs['state'].lower())
            if state_code:
                params['c[REGION]'] = state_code
        
        # Format
        if kwargs.get('format_type') == 'csv':
            params['format'] = 'csv'
        
        return params
    
    def _parse_sdmx_response(self, data: Dict) -> pd.DataFrame:
        """Parse SDMX-JSON response into pandas DataFrame"""
        try:
            # Extract observations from SDMX structure
            if 'data' not in data or 'dataSets' not in data['data']:
                return pd.DataFrame()
            
            dataset = data['data']['dataSets'][0]
            if 'observations' not in dataset:
                return pd.DataFrame()
            
            observations = dataset['observations']
            structure = data['data']['structure']
            
            # Build DataFrame from observations
            rows = []
            for key, values in observations.items():
                if isinstance(values, list) and len(values) > 0:
                    # Parse dimension keys
                    dimensions = key.split(':')
                    row = {'value': values[0]}
                    
                    # Add dimension information if available
                    if 'dimensions' in structure:
                        for i, dim in enumerate(structure['dimensions']['observation']):
                            if i < len(dimensions):
                                row[dim['id']] = dimensions[i]
                    
                    rows.append(row)
            
            return pd.DataFrame(rows)
            
        except Exception as e:
            logger.error(f"Error parsing SDMX response: {e}")
            return pd.DataFrame()

    def _parse_text_response(self, text: str) -> pd.DataFrame:
        """Parse text/CSV response into pandas DataFrame"""
        try:
            # Try to parse as CSV
            from io import StringIO
            df = pd.read_csv(StringIO(text))
            return df
        except Exception as e:
            logger.error(f"Error parsing text response: {e}")
            # Return a simple DataFrame with the raw data
            return pd.DataFrame({'raw_data': [text[:500]]})  # Truncate for safety
    
    async def get_cpi_data_enhanced(self, **kwargs) -> pd.DataFrame:
        """Get Consumer Price Index data with enhanced features"""
        return await self.get_data_enhanced('CPI', **kwargs)
    
    async def get_population_data_enhanced(self, **kwargs) -> pd.DataFrame:
        """Get population data with enhanced features"""
        return await self.get_data_enhanced('ERP_Q', **kwargs)
    
    async def get_unemployment_data(self, **kwargs) -> pd.DataFrame:
        """Get unemployment/labour force data"""
        return await self.get_data_enhanced('LF', **kwargs)
    
    async def get_employment_data(self, **kwargs) -> pd.DataFrame:
        """Get employment statistics"""
        return await self.get_data_enhanced('LF', **kwargs)
    
    async def get_housing_data(self, **kwargs) -> pd.DataFrame:
        """Get housing/building approvals data"""
        return await self.get_data_enhanced('BA', **kwargs)

# Backward compatibility
ABSDataClientEnhanced = ABSDataClient
