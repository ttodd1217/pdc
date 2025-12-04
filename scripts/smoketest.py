#!/usr/bin/env python3
"""
Smoke test script for PDC API endpoints.
Tests liveness and basic functionality of all endpoints.
"""
import sys
import requests
import os
from datetime import datetime, timedelta
from dotenv import load_dotenv

load_dotenv()

# Ensure local requests bypass corporate/system proxies
_NO_PROXY_DEFAULT = 'localhost,127.0.0.1,::1'
if not os.environ.get('NO_PROXY'):
    os.environ['NO_PROXY'] = _NO_PROXY_DEFAULT
if not os.environ.get('no_proxy'):
    os.environ['no_proxy'] = _NO_PROXY_DEFAULT

# Get API URL with fallback - strip whitespace and use default if empty
API_URL = (os.environ.get('API_URL') or '').strip() or 'http://localhost:5000'
API_KEY = (os.environ.get('API_KEY') or '').strip() or 'dev-api-key'

def test_health():
    """Test health check endpoint"""
    print("Testing /health endpoint...")
    try:
        response = requests.get(f"{API_URL}/health", timeout=5)
        assert response.status_code == 200
        data = response.json()
        assert 'status' in data
        assert 'database' in data
        print(f"[PASS] Health check passed: {data['status']}")
        return True
    except Exception as e:
        print(f"[FAIL] Health check failed: {str(e)}")
        return False

def test_metrics():
    """Test metrics endpoint"""
    print("Testing /metrics endpoint...")
    try:
        response = requests.get(f"{API_URL}/metrics", timeout=5)
        assert response.status_code == 200
        data = response.json()
        assert 'total_trades' in data
        print(f"[PASS] Metrics check passed: {data['total_trades']} total trades")
        return True
    except Exception as e:
        print(f"[FAIL] Metrics check failed: {str(e)}")
        return False

def test_blotter():
    """Test blotter endpoint"""
    print("Testing /api/blotter endpoint...")
    try:
        test_date = datetime.now().strftime('%Y-%m-%d')
        response = requests.get(
            f"{API_URL}/api/blotter",
            params={'date': test_date},
            headers={'X-API-Key': API_KEY},
            timeout=5
        )
        assert response.status_code == 200
        data = response.json()
        assert 'date' in data
        assert 'records' in data
        print(f"[PASS] Blotter check passed: {data['count']} records for {test_date}")
        return True
    except Exception as e:
        print(f"[FAIL] Blotter check failed: {str(e)}")
        return False

def test_positions():
    """Test positions endpoint"""
    print("Testing /api/positions endpoint...")
    try:
        test_date = datetime.now().strftime('%Y-%m-%d')
        response = requests.get(
            f"{API_URL}/api/positions",
            params={'date': test_date},
            headers={'X-API-Key': API_KEY},
            timeout=5
        )
        assert response.status_code == 200
        data = response.json()
        assert 'date' in data
        assert 'positions' in data
        print(f"[PASS] Positions check passed: {len(data['positions'])} positions for {test_date}")
        return True
    except Exception as e:
        print(f"[FAIL] Positions check failed: {str(e)}")
        return False

def test_alarms():
    """Test alarms endpoint"""
    print("Testing /api/alarms endpoint...")
    try:
        test_date = datetime.now().strftime('%Y-%m-%d')
        response = requests.get(
            f"{API_URL}/api/alarms",
            params={'date': test_date},
            headers={'X-API-Key': API_KEY},
            timeout=5
        )
        assert response.status_code == 200
        data = response.json()
        assert 'date' in data
        assert 'alarms' in data
        print(f"[PASS] Alarms check passed: {len(data['alarms'])} alarms for {test_date}")
        return True
    except Exception as e:
        print(f"[FAIL] Alarms check failed: {str(e)}")
        return False

def test_authentication():
    """Test API key authentication"""
    print("Testing API key authentication...")
    try:
        test_date = datetime.now().strftime('%Y-%m-%d')
        response = requests.get(
            f"{API_URL}/api/blotter",
            params={'date': test_date},
            timeout=5
        )
        assert response.status_code == 401
        print("[PASS] Authentication check passed: Unauthorized request correctly rejected")
        return True
    except Exception as e:
        print(f"[FAIL] Authentication check failed: {str(e)}")
        return False

def main():
    """Run all smoke tests"""
    print(f"Running smoke tests against {API_URL}")
    print("=" * 50)
    
    tests = [
        test_health,
        test_metrics,
        test_authentication,
        test_blotter,
        test_positions,
        test_alarms,
    ]
    
    results = []
    for test in tests:
        results.append(test())
        print()
    
    print("=" * 50)
    passed = sum(results)
    total = len(results)
    
    if passed == total:
        print(f"[SUCCESS] All {total} tests passed!")
        sys.exit(0)
    else:
        print(f"[FAILED] {total - passed} of {total} tests failed")
        sys.exit(1)

if __name__ == '__main__':
    main()




