# Quick Start Guide

This guide will help you get the Portfolio Data Clearinghouse running locally for development and testing.

## Prerequisites

- Python 3.9 or higher
- PostgreSQL (or SQLite for simple testing)
- SSH key for SFTP access (if testing SFTP functionality)

## Local Setup

### 1. Clone and Install

```bash
# Install dependencies
pip install -r requirements.txt
```

### 2. Configure Environment

Copy `.env.example` to `.env` and update with your settings:

```bash
cp .env.example .env
```

For local development with SQLite:
```bash
DATABASE_URL=sqlite:///pdc.db
API_KEY=dev-api-key
```

### 3. Initialize Database

```bash
python -c "from app import create_app, db; app = create_app(); app.app_context().push(); db.create_all()"
```

### 4. Run the Application

```bash
python run.py
```

The API will be available at `http://localhost:5000`

### 5. Test the API

```bash
# Health check (no auth required)
curl http://localhost:5000/health

# Blotter endpoint (requires API key)
curl -H "X-API-Key: dev-api-key" \
  "http://localhost:5000/api/blotter?date=2025-01-15"
```

## Ingesting Sample Data

### Option 1: Using Example Files

```bash
# Ingest format 1 (CSV)
python -c "
from app import create_app
from app.services.file_ingestion import FileIngestionService
app = create_app()
with app.app_context():
    FileIngestionService.ingest_file('data/example_format1.csv')
"

# Ingest format 2 (pipe-delimited)
python -c "
from app import create_app
from app.services.file_ingestion import FileIngestionService
app = create_app()
with app.app_context():
    FileIngestionService.ingest_file('data/example_format2.txt')
"
```

### Option 2: Using the Ingestion Script

If you have SFTP configured:
```bash
python scripts/ingest_files.py
```

## Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_routes.py
```

## Testing Endpoints

### 1. Blotter Endpoint
Returns all trades for a given date:
```bash
curl -H "X-API-Key: dev-api-key" \
  "http://localhost:5000/api/blotter?date=2025-01-15"
```

### 2. Positions Endpoint
Returns position percentages by ticker:
```bash
curl -H "X-API-Key: dev-api-key" \
  "http://localhost:5000/api/positions?date=2025-01-15"
```

### 3. Alarms Endpoint
Returns compliance violations (>20% holdings):
```bash
curl -H "X-API-Key: dev-api-key" \
  "http://localhost:5000/api/alarms?date=2025-01-15"
```

## Testing Alert Service

### Start Mock Alert Service

In one terminal:
```bash
python scripts/mock_alert_service.py
```

### Test Alert Sending

In another terminal:
```bash
# Test compliance violation alert
python -c "
from app import create_app
from app.services.alerting_service import AlertingService
app = create_app()
with app.app_context():
    service = AlertingService()
    service.send_compliance_violation_alert('ACC001', 'AAPL', 25.5, '2025-01-15')
"
```

View received alerts:
```bash
curl http://localhost:5001/alerts
```

## Smoke Tests

Run the smoke test script to validate all endpoints:

```bash
export API_URL=http://localhost:5000
export API_KEY=dev-api-key
python scripts/smoketest.py
```

## Common Issues

### Database Connection Error
- Verify PostgreSQL is running
- Check DATABASE_URL in .env
- Ensure database exists: `createdb pdc_db`

### Import Errors
- Ensure you're in the project root directory
- Verify virtual environment is activated
- Reinstall dependencies: `pip install -r requirements.txt`

### SFTP Connection Errors
- Verify SSH key path in .env
- Check SFTP host and port
- Test SSH connection manually: `ssh -i ~/.ssh/id_ed25519 user@host`

## Next Steps

- Review [README.md](README.md) for project overview
- Check [DEPLOYMENT.md](DEPLOYMENT.md) for AWS deployment
- See [ALERTING.md](ALERTING.md) for alerting service details




