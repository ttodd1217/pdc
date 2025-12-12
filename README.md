# PDC (Position Data Center) Application

A Flask-based application for ingesting, storing, and querying trade data with REST API endpoints for blotter, positions, and alarms. Deployed on AWS ECS with automated CI/CD via GitHub Actions.

## � SFTP Server Setup

**New to this project?** Start with the SFTP server setup:

→ **[📖 SFTP Quick Start Guide](./QUICKSTART.md)** - 5 minutes to a working SFTP server

→ **[✅ SFTP Setup Checklist](./SETUP_CHECKLIST.md)** - Interactive step-by-step guide

→ **[📑 Complete SFTP Documentation](./README_SFTP_SETUP.md)** - Everything you need to know

Note: SFTP keypair automation — The Terraform configuration can now generate and register an ED25519 keypair for the SFTP EC2 instance (Terraform `tls` provider + `aws_key_pair`). The private key will be written to `terraform/pdc-sftp-server-key.pem` and is stored in the Terraform state (sensitive). If you prefer to manage keys manually, the old manual commands (`ssh-keygen` + `aws ec2 import-key-pair`) are still supported and described in `QUICK_SFTP_START.md`.

## �📋 Table of Contents

- [SFTP Setup](#sftp-server-setup) ← **Start here if new!**
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [AWS Deployment](#aws-deployment)
- [API Endpoints](#api-endpoints)
- [Configuration](#configuration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

**📚 Complete documentation files:**
- `QUICKSTART.md` - 3-step quick setup
- `SETUP_CHECKLIST.md` - Interactive checklist
- `SETUP_FLOWCHART.md` - Visual diagrams
- `README_SFTP_SETUP.md` - Comprehensive guide
- `DOCUMENTATION_INDEX.md` - Index of all documentation

## ✨ Features

- **SFTP File Ingestion**: Automated ingestion of trade data files via SFTP
- **REST API**: Query blotter, positions, and alarms with API key authentication
- **Scheduled Tasks**: EventBridge-triggered ECS tasks for periodic data ingestion
- **Health Monitoring**: Health check and metrics endpoints for observability
- **AWS Infrastructure**: Fully automated deployment with Terraform
- **CI/CD Pipeline**: GitHub Actions workflow for automated deployments

## 🏗️ Architecture

### AWS Infrastructure

```
┌─────────────────┐
│  Application    │
│  Load Balancer  │
└────────┬────────┘
         │
    ┌────▼────┐
    │  ECS    │
    │ Service │
    │ (Fargate)│
    └────┬────┘
         │
    ┌────▼────┐      ┌──────────┐
    │  RDS    │      │  EventBridge │
    │PostgreSQL│      │  (Scheduled) │
    └─────────┘      └─────┬─────┘
                           │
                      ┌────▼────┐
                      │  ECS    │
                      │  Task   │
                      │(Ingestion)│
                      └─────────┘
```

### Components

- **VPC**: Isolated network with public subnets
- **Application Load Balancer (ALB)**: Routes traffic to ECS tasks
- **ECS Fargate**: Container orchestration for the Flask application
- **RDS PostgreSQL**: Managed database for trade data
- **ECR**: Docker image registry
- **EventBridge**: Scheduled ingestion tasks
- **CloudWatch**: Logging and monitoring

## 📦 Prerequisites

### Local Development

- Python 3.11+
- SQLite (included with Python) or PostgreSQL (for production-like setup)
- Git
- Virtual environment (venv)
- Docker (optional, for SFTP testing)

### AWS Deployment

- AWS Account with appropriate IAM permissions
- Terraform >= 1.0
- Docker (for building images)
- AWS CLI configured
- GitHub repository with Actions enabled

## 🚀 Local Development

### 1. Clone Repository

```bash
git clone <repository-url>
cd vest
```

### 2. Create Virtual Environment

```bash
python -m venv venv

# Windows
venv\Scripts\activate

# Linux/Mac
source venv/bin/activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure Environment

Create a `.env` file in the root directory:

```env
# API URL for smoke tests
API_URL="http://127.0.0.1:5001"

# Database - Use SQLite for easy local setup
DATABASE_URL=sqlite:///pdc.db

# For PostgreSQL (alternative):
# DATABASE_URL=postgresql://postgres:postgres@localhost:5432/pdc_db

# API Security
API_KEY=dev-api-key
SECRET_KEY=dev-secret-key-change-in-production

# SFTP Configuration (optional for local dev)
# Note: SFTP_HOST_PORT is for Docker port mapping
SFTP_HOST='127.0.0.1'
SFTP_HOST_PORT=3022    # host port defined in docker-compose
SFTP_PORT=3022         # the port the Python app connects to
SFTP_USERNAME=sftp_user
SFTP_KEY_PATH=~/.ssh/id_pdc
SFTP_REMOTE_PATH=/uploads
SFTP_PROCESSED_PATH=/processed

# Alerting (optional for now)
ALERT_SERVICE_URL=http://localhost:5002/alerts
ALERT_API_KEY=alert-api-key
```

**Note**: The application will automatically use SQLite (`pdc.db`) if `DATABASE_URL` is set to `sqlite:///pdc.db`. For production-like testing, you can use PostgreSQL instead.

### 5. Set Up Database

**For SQLite (default)**: No setup needed! The database file will be created automatically.

**For PostgreSQL (optional)**:
```bash
# Create database
createdb pdc_db

# Or using psql
psql -U postgres -c "CREATE DATABASE pdc_db;"
```

### 6. Initialize Database Schema

```bash
python -c "from app import create_app, db; from app.config import Config; app = create_app(Config); app.app_context().push(); db.create_all()"
```

### 7. Run Application

```bash
python run.py
```

The application will be available at `http://127.0.0.1:5001`

### 8. Run Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_routes.py
```

## ☁️ AWS Deployment

### Prerequisites

1. **AWS IAM Permissions**: Your AWS account must have permissions to create:
   - VPC, Subnets, Security Groups
   - ECS Clusters, Services, Task Definitions
   - RDS Instances
   - ALB, Target Groups, Listeners
   - ECR Repositories
   - IAM Roles and Policies (under `/interview/` path)
   - EventBridge Rules

2. **Terraform Backend**: S3 bucket for Terraform state (recommended)

  This repository expects a remote S3 backend with DynamoDB locking for CI and collaborative work. The default names used in the Terraform config are:

  - Bucket: `pdc-terraform-state-669411698716`
  - Key: `pdc/terraform.tfstate`
  - Region: `us-east-2`
  - DynamoDB table (locking): `pdc-terraform-locks`

  Create these resources before running `terraform init -reconfigure`, or provide backend config values at init time with `-backend-config` (recommended for CI).

  Example (PowerShell):

  ```powershell
  aws s3api create-bucket --bucket pdc-terraform-state-669411698716 --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
  aws s3api put-bucket-encryption --bucket pdc-terraform-state-669411698716 --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"}}]}'
  aws dynamodb create-table --table-name pdc-terraform-locks --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region us-east-2
  ```

  Then initialize Terraform and migrate state if needed:

  ```powershell
  cd terraform
  terraform init -reconfigure
  ```

3. **GitHub Secrets**: Configure in your repository settings:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

### Terraform Configuration

1. **Copy example variables file**:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

2. **Edit `terraform.tfvars`**:

```hcl
aws_region = "us-east-2"
db_instance_class = "db.t3.micro"
db_username = "postgres"
db_password = "your-secure-password"
api_key = "your-api-key"
sftp_host = "your-sftp-host"
sftp_username = "your-sftp-user"
```

3. **Initialize Terraform**:

```bash
terraform init
```

4. **Plan Deployment**:

```bash
terraform plan -out=tfplan
```

5. **Apply Changes**:

```bash
terraform apply tfplan
```

### Automated CI/CD Deployment

The project includes a GitHub Actions workflow that automatically deploys on push to `main`:

1. **Push to GitHub**:
```bash
git add .
git commit -m "Your changes"
git push origin main
```

2. **Monitor Deployment**:
   - Go to GitHub → Actions tab
   - Watch the "Deploy to AWS" workflow

3. **Workflow Steps**:
   - Configure AWS credentials
   - Set up Terraform
  - Initialize Terraform (use `-reconfigure` or `-backend-config` in CI)
   - Plan infrastructure changes
   - Build Docker image
   - Push to ECR
   - Apply Terraform changes
   - Update ECS service
   - Run smoke tests

### Get Deployment Information

```bash
# Get ALB DNS name
terraform output alb_dns_name

# Get database endpoint
terraform output database_endpoint

# Get ECR repository URL
terraform output ecr_repository_url
```

## 🔌 API Endpoints

### Health & Metrics

- **GET `/health`**: Health check endpoint
  ```bash
  curl http://localhost:5001/health
  ```

- **GET `/metrics`**: Basic metrics
  ```bash
  curl http://localhost:5001/metrics
  ```

### API Endpoints (Require API Key)

All API endpoints require authentication via `X-API-Key` header or `api_key` query parameter.

- **GET `/api/blotter`**: Get trade blotter
  ```bash
  curl -H "X-API-Key: your-api-key" \
    "http://localhost:5001/api/blotter?date=2025-01-15"
  ```

- **GET `/api/positions`**: Get positions
  ```bash
  curl -H "X-API-Key: your-api-key" \
    "http://localhost:5001/api/positions?date=2025-01-15"
  ```

- **GET `/api/alarms`**: Get alarms
  ```bash
  curl -H "X-API-Key: your-api-key" \
    "http://localhost:5001/api/alarms?date=2025-01-15"
  ```

### Query Parameters

- `date`: Filter by trade date (YYYY-MM-DD format)
- `account_id`: Filter by account ID
- `ticker`: Filter by ticker symbol
- `api_key`: API key (alternative to header)

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `API_URL` | API URL for smoke tests | `http://127.0.0.1:5001` |
| `DATABASE_URL` | Database connection string (SQLite or PostgreSQL) | `sqlite:///pdc.db` |
| `API_KEY` | API authentication key | `dev-api-key-change-in-production` |
| `SECRET_KEY` | Flask secret key | `dev-secret-key-change-in-production` |
| `SFTP_HOST` | SFTP server hostname | `127.0.0.1` |
| `SFTP_HOST_PORT` | SFTP host port (for Docker port mapping) | `3022` |
| `SFTP_PORT` | SFTP server port (the port app connects to) | `3022` |
| `SFTP_USERNAME` | SFTP username | `sftp_user` |
| `SFTP_KEY_PATH` | Path to SSH private key | `~/.ssh/id_pdc` |
| `SFTP_REMOTE_PATH` | Remote SFTP path | `/uploads` |
| `SFTP_PROCESSED_PATH` | Processed files path | `/processed` |
| `ALERT_SERVICE_URL` | Alert service endpoint | `http://localhost:5002/alerts` |
| `ALERT_API_KEY` | Alert service API key | `alert-api-key` |
| `PORT` | Application port (local dev) | `5001` |
| `HOST` | Application host (local dev) | `127.0.0.1` |

### Terraform Variables

See `terraform/variables.tf` for all available variables.

## 🧪 Testing

### Unit Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test
pytest tests/test_routes.py -v
```

### Smoke Tests

Test deployed application. See `SMOKETEST_DEMO.md` for a concise 5-minute demo script and troubleshooting steps.

PowerShell (Windows) — recommended when running locally from the repo or CI runner that uses PowerShell:

```powershell
cd terraform
$ALB_DNS   = terraform output -raw alb_dns_name
$SFTP_IP   = terraform output -raw sftp_ec2_public_ip
$S3_BUCKET = terraform output -raw sftp_data_bucket
# If using Secrets Manager for API or alerting keys, fetch them explicitly
$API_KEY   = aws secretsmanager get-secret-value --secret-id pdc/alert-api-key --region us-east-2 --query SecretString --output text

"ALB: $ALB_DNS"
"SFTP: $SFTP_IP"
"S3: $S3_BUCKET"

# Run the smoke test script (it uses API_URL or the ALB DNS directly)
$env:API_URL = "http://$ALB_DNS"
python ..\scripts\smoketest.py
```

Bash (Linux/macOS):

```bash
# Local
export API_URL="http://localhost:5001"
python scripts/smoketest.py

# AWS (after deployment)
export API_URL="http://$(terraform output -raw alb_dns_name)"
python scripts/smoketest.py
```

### API Testing

```bash
# Test API endpoints
python scripts/test_api.py
```

## 🔧 Troubleshooting

### Local Development Issues

**Database Connection Error**:
- **For SQLite**: Check file permissions in the project directory
- **For PostgreSQL**: 
  - Verify PostgreSQL is running: `pg_isready`
  - Check `DATABASE_URL` in `.env`
  - Ensure database exists: `psql -l | grep pdc_db`

**Port Already in Use**:
- Change `PORT` in `.env` to a different port
- Or kill the process using the port

**Import Errors**:
- Ensure virtual environment is activated
- Reinstall dependencies: `pip install -r requirements.txt`

### AWS Deployment Issues

**Terraform IAM Errors**:
- Verify IAM permissions allow creating roles under `/interview/` path
- Check that permissions boundary is set correctly
- Ensure roles don't already exist at root path

**ECS Tasks Not Starting**:
- Check CloudWatch logs: `/ecs/pdc-app`
- Verify security group allows port 5000 from ALB
- Check task definition health check configuration
- Verify `DATABASE_URL` is correct (no duplicate port)

**Health Checks Failing**:
- Ensure `curl` is installed in Docker image
- Check health check timeout and start period settings
- Verify application is listening on port 5000
- Check security group rules

**Database Connection Issues**:
- Verify RDS security group allows connections from ECS security group
- Check `DATABASE_URL` format (should be `postgresql://user:pass@host/db`, not `host:5432:5432`)
- Verify database credentials in Terraform variables

**ALB 503 Errors**:
- Check target group health: AWS Console → EC2 → Target Groups
- Verify ECS tasks are running and healthy
- Check security group allows ALB → ECS communication on port 5000

### Common Fixes

1. **Rebuild Docker Image**:
   ```bash
   docker build -t pdc-app .
   ```

2. **Check ECS Task Logs**:
   ```bash
   aws logs tail /ecs/pdc-app --follow
   ```

3. **Verify Terraform State**:
   ```bash
   terraform state list
   ```

4. **Force ECS Service Update**:
   ```bash
   aws ecs update-service --cluster pdc-cluster --service pdc-app-service --force-new-deployment
   ```

## 📁 Project Structure

```
vest/
├── app/                    # Flask application
│   ├── __init__.py        # App factory
│   ├── config.py          # Configuration
│   ├── models.py          # Database models
│   ├── routes.py          # API routes
│   ├── middleware.py      # Request middleware
│   └── services/          # Business logic
│       ├── sftp_service.py
│       ├── file_ingestion.py
│       ├── ingestion_worker.py
│       └── alerting_service.py
├── terraform/             # Infrastructure as Code
│   ├── main.tf           # Main infrastructure
│   ├── ecs.tf            # ECS configuration
│   ├── scheduled_task.tf # EventBridge tasks
│   ├── variables.tf      # Variable definitions
│   └── outputs.tf        # Output values
├── scripts/               # Utility scripts
│   ├── smoketest.py      # Smoke tests
│   ├── test_api.py       # API tests
│   └── ingest_files.py   # Data ingestion
├── tests/                 # Unit tests
├── .github/
│   └── workflows/
│       └── deploy.yml     # CI/CD pipeline
├── Dockerfile            # Docker image definition
├── requirements.txt      # Python dependencies
└── run.py               # Application entry point
```


