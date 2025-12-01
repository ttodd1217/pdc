# Portfolio Data Clearinghouse - Project Summary

## Overview

This project implements a complete data clearinghouse system that ingests trade files from an SFTP server and provides REST API endpoints for querying portfolio data and compliance violations.

## Deliverables Completed

### ✅ 1. Robust Unit Testing
- **Location**: `tests/` directory
- **Coverage**: 
  - File ingestion tests (`test_file_ingestion.py`)
  - API endpoint tests (`test_routes.py`)
  - Alerting service tests (`test_alerting.py`)
- **Test Framework**: pytest with coverage reporting
- **CI Integration**: Tests run automatically in GitHub Actions

### ✅ 2. Working Code
- **Flask Application**: `app/` directory
  - REST API with 3 main endpoints
  - Database models and migrations
  - File ingestion service supporting 2 formats
  - SFTP integration with SSH key authentication
  - API key authentication middleware
- **Entry Point**: `run.py`
- **Configuration**: Environment-based config in `app/config.py`

### ✅ 3. CI/CD Pipeline
- **GitHub Actions**: `.github/workflows/`
  - **CI Pipeline** (`ci.yml`): Runs tests, linting, and code quality checks
  - **Deploy Pipeline** (`deploy.yml`): Terraform deployment to AWS with smoke tests
- **Terraform Infrastructure**: `terraform/` directory
  - VPC, subnets, security groups
  - RDS PostgreSQL database
  - ECS Fargate cluster
  - Application Load Balancer
  - ECR repository
  - CloudWatch logs
  - Scheduled ingestion tasks

### ✅ 4. Observability
- **Health Check Endpoint**: `GET /health`
  - Database connectivity check
  - Status reporting
- **Metrics Endpoint**: `GET /metrics`
  - Total trades count
  - Latest trade date
- **Smoke Tests**: `scripts/smoketest.py`
  - Validates all endpoints
  - Tests authentication
  - Can be run in CI/CD pipeline

### ✅ 5. Basic Alerting
- **Alert Service**: `app/services/alerting_service.py`
- **Alert Types**:
  1. **Compliance Violation**: When holdings exceed 20% threshold
  2. **Ingestion Failure**: When file processing fails
  3. **Data Quality**: When data quality issues are detected
- **Mock Service**: `scripts/mock_alert_service.py` for testing
- **Documentation**: `ALERTING.md` with examples and integration guides

## API Endpoints

### 1. GET /api/blotter?date=YYYY-MM-DD
Returns all trade records for the specified date in a simplified format.

**Example Response**:
```json
{
  "date": "2025-01-15",
  "count": 10,
  "records": [
    {
      "trade_date": "2025-01-15",
      "account_id": "ACC001",
      "ticker": "AAPL",
      "quantity": 100,
      "price": 185.50,
      "market_value": 18550.00,
      "trade_type": "BUY"
    }
  ]
}
```

### 2. GET /api/positions?date=YYYY-MM-DD
Returns position percentages by ticker for each account.

**Example Response**:
```json
{
  "date": "2025-01-15",
  "positions": [
    {
      "account_id": "ACC001",
      "ticker": "AAPL",
      "market_value": 18550.00,
      "percentage": 34.5
    }
  ]
}
```

### 3. GET /api/alarms?date=YYYY-MM-DD
Returns accounts with holdings exceeding 20% threshold.

**Example Response**:
```json
{
  "date": "2025-01-15",
  "alarms": [
    {
      "account_id": "ACC003",
      "ticker": "NVDA",
      "percentage": 91.4,
      "violation": true
    }
  ]
}
```

## File Formats Supported

### Format 1: CSV
```
TradeDate,AccountID,Ticker,Quantity,Price,TradeType,SettlementDate
2025-01-15,ACC001,AAPL,100,185.50,BUY,2025-01-17
```

### Format 2: Pipe-delimited
```
REPORT_DATE|ACCOUNT_ID|SECURITY_TICKER|SHARES|MARKET_VALUE|SOURCE_SYSTEM
20250115|ACC001|AAPL|100|18550.00|CUSTODIAN_A
```

## Security

- **API Key Authentication**: Required for all API endpoints (except health/metrics)
- **SSH Key Authentication**: For SFTP file retrieval
- **Environment Variables**: Sensitive configuration via environment variables
- **Secrets Management**: AWS Secrets Manager integration in Terraform

## Infrastructure

### AWS Resources Created
- **VPC**: Isolated network environment
- **RDS PostgreSQL**: Managed database
- **ECS Fargate**: Containerized application hosting
- **Application Load Balancer**: High availability and health checks
- **ECR**: Docker image repository
- **CloudWatch**: Logging and monitoring
- **EventBridge**: Scheduled ingestion tasks

## Alert Examples

### Compliance Violation Alert
```json
{
  "alert_type": "compliance_violation",
  "data": {
    "account_id": "ACC003",
    "ticker": "NVDA",
    "percentage": 91.4,
    "threshold": 20.0,
    "severity": "high"
  }
}
```

### Ingestion Failure Alert
```json
{
  "alert_type": "ingestion_failure",
  "data": {
    "filename": "trades_20250115.csv",
    "error": "Database connection timeout",
    "severity": "medium"
  }
}
```

## Project Structure

```
PDC/
├── app/                    # Flask application
│   ├── __init__.py        # App factory
│   ├── config.py          # Configuration
│   ├── models.py          # Database models
│   ├── routes.py          # API endpoints
│   ├── middleware.py      # Authentication
│   └── services/          # Business logic
│       ├── sftp_service.py
│       ├── file_ingestion.py
│       ├── ingestion_worker.py
│       └── alerting_service.py
├── tests/                 # Unit tests
├── terraform/             # Infrastructure as code
├── scripts/               # Utility scripts
├── data/                  # Example data files
├── .github/workflows/     # CI/CD pipelines
└── requirements.txt       # Python dependencies
```

## Testing

Run tests with:
```bash
pytest --cov=app --cov-report=html
```

Run smoke tests with:
```bash
python scripts/smoketest.py
```

## Deployment

See `DEPLOYMENT.md` for detailed AWS deployment instructions using Terraform and GitHub Actions.

## Documentation

- **README.md**: Project overview and setup
- **QUICKSTART.md**: Local development guide
- **DEPLOYMENT.md**: AWS deployment guide
- **ALERTING.md**: Alerting service documentation
- **PROJECT_SUMMARY.md**: This file

## Notes

- The provided SSH public key (`ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINBiRG5vqvdhVxb1wmqnWf9YXVVp4l3qDdBJ8eNGoxWj`) should be added to the SFTP server's authorized_keys
- The system uses absolute values for position percentage calculations to handle both BUY and SELL trades correctly
- All dates should be in YYYY-MM-DD format for API queries
- The compliance threshold is set to 20% as specified in requirements




