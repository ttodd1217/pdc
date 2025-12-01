# Portfolio Data Clearinghouse (PDC)

A simplified data clearinghouse system that ingests trade files from an SFTP server and provides API endpoints for querying portfolio data and compliance violations.

## Features

- **File Ingestion**: Supports two file formats (CSV and pipe-delimited) from SFTP server
- **SFTP Integration**: SSH key-based authentication for secure file transfer
- **REST API**: Three endpoints for querying trade data, positions, and compliance alarms
- **Compliance Monitoring**: Automatically detects holdings exceeding 20% threshold
- **CI/CD Pipeline**: GitHub Actions with Terraform for AWS deployment
- **Observability**: Health checks and metrics endpoints
- **Alerting**: Integration with alerting service for compliance violations and ingestion failures
- **Security**: API key authentication

## Project Structure

```
PDC/
├── app/
│   ├── __init__.py          # Flask app factory
│   ├── config.py            # Configuration
│   ├── models.py            # Database models
│   ├── routes.py            # API endpoints
│   ├── middleware.py        # API key authentication
│   └── services/
│       ├── sftp_service.py      # SFTP file retrieval
│       ├── file_ingestion.py    # File parsing and ingestion
│       ├── ingestion_worker.py  # File processing orchestration
│       └── alerting_service.py  # Alert sending
├── tests/                   # Unit tests
├── terraform/              # Infrastructure as code
├── .github/workflows/      # CI/CD pipelines
├── requirements.txt        # Python dependencies
└── run.py                  # Application entry point
```

## Setup

**📖 For complete setup instructions, see [SETUP_GUIDE.md](SETUP_GUIDE.md)**

### Quick Start (5 Minutes)

1. **Create virtual environment**:
```bash
python -m venv venv
venv\Scripts\activate  # Windows
# source venv/bin/activate  # Mac/Linux
```

2. **Install dependencies**:
```bash
pip install -r requirements.txt
```

3. **Create `.env` file**:
```bash
DATABASE_URL=sqlite:///pdc.db
API_KEY=dev-api-key
```

4. **Initialize database**:
```bash
python -c "from app import create_app, db; app = create_app(); app.app_context().push(); db.create_all()"
```

5. **Run the application**:
```bash
python run.py
```

6. **Test it**:
```bash
# Health check
curl http://localhost:5000/health

# API endpoint
curl -H "X-API-Key: dev-api-key" "http://localhost:5000/api/blotter?date=2025-01-15"
```

### Prerequisites

- Python 3.9+
- PostgreSQL (or SQLite for local development)
- SSH key for SFTP access (optional for local testing)
- AWS account (for deployment)

## API Endpoints

All endpoints require an API key in the `X-API-Key` header or `api_key` query parameter.

### GET /api/blotter?date=YYYY-MM-DD
Returns all trade records for the specified date.

### GET /api/positions?date=YYYY-MM-DD
Returns position percentages by ticker for each account.

### GET /api/alarms?date=YYYY-MM-DD
Returns accounts with holdings exceeding 20% threshold.

### GET /health
Health check endpoint (no authentication required).

### GET /metrics
Basic metrics endpoint (no authentication required).

## File Formats

### Format 1 (CSV)
```
TradeDate,AccountID,Ticker,Quantity,Price,TradeType,SettlementDate
2025-01-15,ACC001,AAPL,100,185.50,BUY,2025-01-17
```

### Format 2 (Pipe-delimited)
```
REPORT_DATE|ACCOUNT_ID|SECURITY_TICKER|SHARES|MARKET_VALUE|SOURCE_SYSTEM
20250115|ACC001|AAPL|100|18550.00|CUSTODIAN_A
```

## SFTP Setup

The application requires SFTP access for file ingestion. See [SFTP_SETUP_GUIDE.md](SFTP_SETUP_GUIDE.md) for:
- Setting up SFTP server (Linux, AWS Transfer Family, or Docker)
- Configuring SSH key authentication
- Testing SFTP connection
- Troubleshooting common issues

**Quick Setup**: Run `bash scripts/setup_sftp_key.sh` to generate SSH keys, then test with `python scripts/test_sftp.py`

## Deployment

The project includes Terraform configurations for AWS deployment and GitHub Actions for CI/CD.

**Quick Start**: See [AWS_DEPLOYMENT_GUIDE.md](AWS_DEPLOYMENT_GUIDE.md) for detailed step-by-step instructions.

**Automated**: Run `./deploy.sh` for automated deployment (requires AWS CLI, Terraform, and Docker).

**Manual**: See [DEPLOYMENT.md](DEPLOYMENT.md) for manual deployment steps.

## Alerting

The system sends alerts for:
1. **Compliance Violations**: When any account has >20% holding in a single ticker
2. **Ingestion Failures**: When file processing fails
3. **Data Quality Issues**: When data quality problems are detected

Alert service endpoint and API key are configurable via environment variables.

## Complete Process Guide

**📖 For the complete end-to-end process from setup to deployment, see [COMPLETE_PROCESS_GUIDE.md](COMPLETE_PROCESS_GUIDE.md)**

This guide covers:
- Initial setup and local development
- SFTP server configuration
- Testing (unit tests, smoke tests)
- CI/CD pipeline setup
- AWS deployment
- Post-deployment configuration

## License

Proprietary - Vest Financial

