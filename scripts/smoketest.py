#!/usr/bin/env python3
"""
Smoke test script for PDC API endpoints.
Tests liveness and basic functionality of all endpoints.
Reports failures to the AlertingService.
"""
import sys
import requests
import os
import time
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Only load .env for local development, not in CI/deployment environments
# In CI, environment variables should be set explicitly by the workflow
if not os.environ.get('GITHUB_ACTIONS') and not os.environ.get('CI'):
    load_dotenv()

# Ensure local requests bypass corporate/system proxies
_NO_PROXY_DEFAULT = 'localhost,127.0.0.1,::1'
if not os.environ.get('NO_PROXY'):
    os.environ['NO_PROXY'] = _NO_PROXY_DEFAULT
if not os.environ.get('no_proxy'):
    os.environ['no_proxy'] = _NO_PROXY_DEFAULT

# Get API URL with fallback - strip whitespace and use default if empty
API_URL = (os.environ.get('API_URL') or '').strip() or 'http://localhost:5001'
API_KEY = (os.environ.get('API_KEY') or '').strip() or 'dev-api-key'

# Retry configuration
MAX_RETRIES = 3
RETRY_DELAY = 10  # seconds between retries

# Import AlertingService for failure reporting
try:
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sys.path.insert(0, project_root)
    from app import create_app
    from app.config import Config
    from app.services.alerting_service import AlertingService
    ALERTING_AVAILABLE = True
except Exception as e:
    print(f"[WARNING] AlertingService not available: {str(e)}")
    ALERTING_AVAILABLE = False

def send_alert(test_name, error_message, severity="high"):
    """Send alert via AlertingService if available"""
    if not ALERTING_AVAILABLE:
        return
    
    try:
        app = create_app(Config)
        with app.app_context():
            alerting = AlertingService()
            alert_msg = f"Smoketest '{test_name}' failed: {error_message}"
            alerting.send_alert(alert_msg, severity=severity)
            print(f"[ALERT] Sent alert to AlertingService: {alert_msg}")
    except Exception as e:
        print(f"[WARNING] Failed to send alert: {str(e)}")

def test_health():
    """Test health check endpoint"""
    print("Testing /health endpoint...")
    try:
        response = requests.get(f"{API_URL}/health", timeout=5)
        if response.status_code == 503:
            error_msg = "ALB returned 503 - ECS tasks not ready yet"
            print(f"[FAIL] Health check failed: {error_msg}")
            send_alert("health_check", error_msg, severity="warning")
            return False
        assert response.status_code == 200
        data = response.json()
        assert 'status' in data
        assert 'database' in data
        print(f"[PASS] Health check passed: {data['status']}")
        return True
    except Exception as e:
        error_str = str(e)
        if '503' in error_str:
            print(f"[FAIL] Health check failed: ALB returned 503")
            send_alert("health_check", "ALB returned 503 - ECS tasks initializing", severity="warning")
        else:
            print(f"[FAIL] Health check failed: {error_str}")
            send_alert("health_check", error_str, severity="high")
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
    """Run all smoke tests with retry logic"""
    print(f"Running smoke tests against {API_URL}")
    print("=" * 50)
    
    # Retry loop
    for attempt in range(1, MAX_RETRIES + 1):
        if attempt > 1:
            print(f"\n[INFO] Retry attempt {attempt} of {MAX_RETRIES}...")
            print(f"[INFO] Waiting {RETRY_DELAY} seconds before retry...\n")
            time.sleep(RETRY_DELAY)
        
        # Check if ALB is responding
        try:
            response = requests.head(f"{API_URL}/health", timeout=5)
            if response.status_code == 503:
                if attempt == 1:
                    print("[INFO] ALB is responding but ECS tasks are initializing...")
                    print("[INFO] This is normal after deployment. Tasks will be ready shortly...\n")
                else:
                    print(f"[INFO] Attempt {attempt}: Still waiting for ECS tasks to become healthy...")
            elif response.status_code >= 500:
                print(f"[INFO] Attempt {attempt}: ALB returned {response.status_code} - tasks are starting up...")
        except Exception as e:
            if attempt == 1:
                print(f"[ERROR] Cannot reach ALB: {str(e)}")
                print("[ERROR] The application may not be deployed yet or the URL may be incorrect\n")
            else:
                print(f"[INFO] Attempt {attempt}: Still unable to reach ALB, retrying...\n")
        
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
        
        passed = sum(results)
        total = len(results)
        
        # If all tests pass, exit successfully
        if passed == total:
            print("=" * 50)
            print(f"[SUCCESS] All {total} tests passed!")
            print("[INFO] Application is healthy and all endpoints are working!")
            sys.exit(0)
        
        # If this isn't the last attempt and all tests failed, retry
        if attempt < MAX_RETRIES and passed == 0:
            print("=" * 50)
            print(f"[INFO] All tests failed (attempt {attempt}/{MAX_RETRIES}). Retrying...\n")
            continue
        
        # If last attempt or some tests passed, show results and exit
        print("=" * 50)
        failed = total - passed
        if passed == total:
            print(f"[SUCCESS] All {total} tests passed!")
            print("[INFO] Application is healthy and all endpoints are working!")
            sys.exit(0)
        else:
            print(f"[FAILED] {failed} of {total} tests failed (attempt {attempt}/{MAX_RETRIES})")
            if attempt == MAX_RETRIES and passed == 0:
                print("[INFO] Maximum retries reached. ECS tasks may still be initializing.")
                print("[INFO] Manual retry after 1-2 minutes may succeed.")
            sys.exit(1)
    
    # Should not reach here, but exit with error if we do
    print("[ERROR] Unexpected exit from retry loop")
    sys.exit(1)

if __name__ == '__main__':
    main()




