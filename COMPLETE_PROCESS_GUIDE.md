# Complete Process Guide - From Setup to Deployment

This guide covers the **entire process** from initial setup through testing, CI/CD, and deployment.

## Table of Contents

1. [Initial Setup](#1-initial-setup)
2. [Local Development](#2-local-development)
3. [SFTP Server Setup](#3-sftp-server-setup)
4. [Testing](#4-testing)
5. [CI/CD Setup](#5-cicd-setup)
6. [AWS Deployment](#6-aws-deployment)
7. [Post-Deployment](#7-post-deployment)

---

## 1. Initial Setup

### Step 1.1: Prerequisites Check

```bash
# Check Python version (need 3.9+)
python --version

# Check if you have pip
pip --version

# Check if you have Git
git --version
```

### Step 1.2: Clone/Navigate to Project

```bash
cd C:\Users\wreed\OneDrive\Desktop\PDC
```

### Step 1.3: Create Virtual Environment

```bash
# Create virtual environment
python -m venv venv

# Activate it (Windows)
venv\Scripts\activate

# You should see (venv) in your prompt
```

### Step 1.4: Install Dependencies

```bash
pip install -r requirements.txt
```

This installs:
- Flask and Flask-SQLAlchemy
- PostgreSQL driver
- SFTP client (paramiko)
- Testing tools (pytest)
- All other dependencies

### Step 1.5: Create Environment Configuration

Create a `.env` file in the project root:

```bash
# Database - SQLite for local, PostgreSQL for production
DATABASE_URL=sqlite:///pdc.db

# API Security
API_KEY=dev-api-key-change-in-production
SECRET_KEY=dev-secret-key-change-in-production

# SFTP Configuration (we'll set this up next)
SFTP_HOST=localhost
SFTP_HOST_PORT=3022      # Host port mapped to the Docker container (avoid 2222 conflicts)
SFTP_PORT=22             # Container port; leave as 22 unless your server uses a custom port
SFTP_USERNAME=sftp_user
SFTP_KEY_PATH=C:/Users/wreed/ssh/id_pdc
SFTP_REMOTE_PATH=/uploads
SFTP_PROCESSED_PATH=/processed

# Alerting (optional for local)
ALERT_SERVICE_URL=http://localhost:5001/alerts
ALERT_API_KEY=alert-api-key
```

### Step 1.6: Initialize Database

```bash
python -c "from app import create_app, db; app = create_app(); app.app_context().push(); db.create_all()"
```

This creates the database and tables.

---

## 2. Local Development

### Step 2.1: Run the Application

```bash
python run.py
```

You should see:
```
 * Running on http://127.0.0.1:5001
 * Debug mode: on
```

### Step 2.2: Test Basic Endpoints

**Health Check** (no auth required):
```bash
curl http://127.0.0.1:5001/health
```

Or open in browser: http://127.0.0.1:5001/health

**API Endpoint** (requires API key):
```bash
curl -H "X-API-Key: dev-api-key" "http://127.0.0.1:5001/api/blotter?date=2025-01-15"
```

### Step 2.3: Load Sample Data

```bash
# Ingest format 1 (CSV)
python -c "from app import create_app; from app.services.file_ingestion import FileIngestionService; app = create_app(); app.app_context().push(); FileIngestionService.ingest_file('data/example_format1.csv')"

# Ingest format 2 (pipe-delimited)
python -c "from app import create_app; from app.services.file_ingestion import FileIngestionService; app = create_app(); app.app_context().push(); FileIngestionService.ingest_file('data/example_format2.txt')"
```

### Step 2.4: Test API Endpoints

```bash
# Get all trades for a date
curl -H "X-API-Key: dev-api-key" "http://127.0.0.1:5001/api/blotter?date=2025-01-15"

# Get position percentages
curl -H "X-API-Key: dev-api-key" "http://127.0.0.1:5001/api/positions?date=2025-01-15"

# Get compliance alarms
curl -H "X-API-Key: dev-api-key" "http://127.0.0.1:5001/api/alarms?date=2025-01-15"
```

---

## 3. SFTP Server Setup

### Step 3.1: Generate SSH Keys

```bash
# Generate Ed25519 key pair
ssh-keygen -t ed25519 -f C:/Users/Administrator/.ssh/id_pdc -C "pdc-app"

# Or use the setup script
bash scripts/setup_sftp_key.sh
```

This creates:
- Private key: `C:/Users/wreed/.ssh/id_pdc` (keep secret!)
- Public key: `C:/Users/wreed/.ssh/id_pdc.pub` (add to SFTP server)

### Step 3.2: Set Up Local SFTP Server (Docker)

**Option A: Using Docker (Recommended for Local Testing)**

```bash
# Choose a host port that is free on your machine (3022 by default)
set SFTP_HOST_PORT=3022   # Windows PowerShell
export SFTP_HOST_PORT=3022  # macOS/Linux

# Start SFTP server
docker-compose -f docker-compose.sftp.yml up -d

# Check it's running
docker ps
```

The SFTP server will be available at:
- Host: `localhost`
- Host Port: value of `SFTP_HOST_PORT` (defaults to `3022`)
- Container Port: `22`
- Username: `sftp_user`
- Password: `password` (for initial setup)

**Add your public key to the server:**

```bash
# Copy your public key
cat C:/Users/Administrator/.ssh/id_pdc.pub

# Add it to the Docker container
docker exec -it pdc-sftp sh -c "mkdir -p /home/sftp_user/.ssh && echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINipDSvY8BmoiiCCR2kZvbiCXj+h1J70wUC8Vi6lZj3p pdc-app' > /home/sftp_user/.ssh/authorized_keys && chmod 600 /home/sftp_user/.ssh/authorized_keys && chown 1001:1001 /home/sftp_user/.ssh/authorized_keys && chown root:root /home/sftp_user && chmod 755 /home/sftp_user"
```

**Option B: Using Existing SFTP Server**

If you have an existing SFTP server:

1. Add your public key to the server's `~/ssh/authorized_keys`
2. Update `.env` with your SFTP server details:
   ```bash
   SFTP_HOST=your-sftp-server.com
   SFTP_PORT=22
   SFTP_USERNAME=your-username
   ```

### Step 3.3: Test SFTP Connection

```bash
# Test connection
python scripts/test_sftp.py
```

You should see:
```
✅ Connection successful!
📁 Files in /uploads:
   (no files found)
```

### Step 3.4: Upload Test Files

```bash
# Upload a test file
scp -i C:/Users/Administrator/.ssh/id_pdc -P %SFTP_HOST_PORT% data/example_format1.csv sftp_user@localhost:/uploads/

# Or using SFTP
sftp -i C:/Users/Administrator/.ssh/id_pdc -P %SFTP_HOST_PORT% sftp_user@localhost
sftp> put data/example_format1.csv /uploads/
sftp> exit
```

### Step 3.5: Run File Ingestion

```bash
# Process files from SFTP
python scripts/ingest_files.py
```

This will:
1. Connect to SFTP server
2. List files in `/uploads`
3. Download each file
4. Parse and ingest into database
5. Move files to `/processed`

---

## 4. Testing

### Step 4.1: Run Unit Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# View coverage report
# Open htmlcov/index.html in browser
```

### Step 4.2: Run Specific Test Files

```bash
# Test file ingestion
pytest tests/test_file_ingestion.py -v

# Test API routes
pytest tests/test_routes.py -v

# Test alerting
pytest tests/test_alerting.py -v
```

### Step 4.3: Run Smoke Tests

```bash
# Set environment variables
$env:API_URL="http://127.0.0.1:5001"
$env:API_KEY="dev-api-key"

# Run smoke tests
python scripts/smoketest.py
```

Expected output:
```
✅ All tests passed!
```

### Step 4.4: Test Alert Service

**Start mock alert service** (in separate terminal):
```bash
python scripts/mock_alert_service.py
```

**Test alert sending**:
```bash
python -c "from app import create_app; from app.services.alerting_service import AlertingService; app = create_app(); app.app_context().push(); service = AlertingService(); service.send_compliance_violation_alert('ACC001', 'AAPL', 25.5, '2025-01-15')"
```

**View received alerts**:
```bash
curl http://localhost:5001/alerts
```

---

## 5. CI/CD Setup

### Step 5.1: Set Up GitHub Repository

```bash
# Initialize git (if not already done)
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit - PDC project"

# Add remote (replace with your repo URL)
git remote add origin https://github.com/yourusername/pdc.git

# Push to GitHub
git push -u origin main
```

### Step 5.2: Configure GitHub Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions**

Add these secrets:

1. **AWS_ACCESS_KEY_ID**: Your AWS access key
2. **AWS_SECRET_ACCESS_KEY**: Your AWS secret key
3. **API_KEY**: Your API key (same as in `.env`)
4. **DB_PASSWORD**: Database password (for deployment)

### Step 5.3: Verify CI Pipeline

The CI pipeline (`.github/workflows/ci.yml`) will automatically run on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`

**Test it:**
```bash
# Make a small change
echo "# Test" >> README.md

# Commit and push
git add README.md
git commit -m "Test CI pipeline"
git push
```

Go to GitHub → **Actions** tab to see the pipeline running.

The CI pipeline will:
- ✅ Run tests
- ✅ Check code coverage
- ✅ Run linting (flake8, black, isort)

### Step 5.4: Review CI Results

Check the Actions tab:
- Green checkmark = All tests passed
- Red X = Tests failed (check logs)

---

## 6. AWS Deployment

### Step 6.1: Prerequisites

```bash
# Install AWS CLI
# Download from: https://aws.amazon.com/cli/

# Configure AWS credentials
aws configure
# Enter: Access Key ID
# Enter: Secret Access Key
# Enter: Default region (e.g., us-east-1)
# Enter: Default output format (json)

# Verify configuration
aws sts get-caller-identity
```

### Step 6.2: Create S3 Bucket for Terraform State

```bash
# Create bucket
aws s3 mb s3://pdc-terraform-state --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket pdc-terraform-state \
    --versioning-configuration Status=Enabled
```

### Step 6.3: Configure Terraform Variables

```bash
cd terraform

# Copy example
copy terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars (use notepad or your editor)
notepad terraform.tfvars
```

Set these values:
```hcl
aws_region       = "us-east-1"
db_instance_class = "db.t3.micro"
db_username      = "postgres"
db_password      = "YOUR_SECURE_PASSWORD_HERE"
api_key          = "YOUR_API_KEY_HERE"
sftp_host        = "your-sftp-host.com"
sftp_username    = "sftp_user"
```

### Step 6.4: Store Secrets in AWS Secrets Manager

```bash
# Store SFTP private key
aws secretsmanager create-secret \
    --name pdc/sftp-key \
    --secret-string file://C:/Users/wreed/ssh/id_ed25519 \
    --region us-east-1

# Store alert API key
aws secretsmanager create-secret \
    --name pdc/alert-api-key \
    --secret-string "your-alert-api-key" \
    --region us-east-1
```

### Step 6.5: Deploy Infrastructure

```bash
# Initialize Terraform
cd terraform
terraform init

# Review what will be created
terraform plan -out=tfplan

# Apply (this takes 10-15 minutes)
terraform apply tfplan
```

This creates:
- VPC and networking
- RDS PostgreSQL database
- ECS Fargate cluster
- Application Load Balancer
- ECR repository
- Security groups
- CloudWatch logs

### Step 6.6: Build and Push Docker Image

```bash
# Get ECR repository URL
cd terraform
$ECR_URL = terraform output -raw ecr_repository_url
echo $ECR_URL

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL

# Build image
cd ..
docker build -t pdc-app .

# Tag and push
docker tag pdc-app:latest "$ECR_URL:latest"
docker push "$ECR_URL:latest"
```

### Step 6.7: Get Deployment URLs

```bash
cd terraform

# Get API URL
terraform output alb_dns_name

# Get database endpoint
terraform output database_endpoint
```

### Step 6.8: Verify Deployment

```bash
# Get API URL
$API_URL = "http://$(terraform output -raw alb_dns_name)"

# Test health endpoint
curl "$API_URL/health"

# Test API endpoint
curl -H "X-API-Key: YOUR_API_KEY" "$API_URL/api/blotter?date=2025-01-15"
```

### Step 6.9: Run Smoke Tests Against Production

```bash
$env:API_URL="http://$(terraform output -raw alb_dns_name)"
$env:API_KEY="YOUR_API_KEY"
python scripts/smoketest.py
```

---

## 7. Post-Deployment

### Step 7.1: Set Up Scheduled Ingestion

The Terraform configuration includes EventBridge rules for scheduled ingestion. Verify:

```bash
# Check EventBridge rule
aws events describe-rule --name pdc-ingestion-schedule --region us-east-1
```

The ingestion runs every hour automatically.

### Step 7.2: Configure Monitoring

**View logs:**
```bash
# Application logs
aws logs tail /ecs/pdc-app --follow --region us-east-1

# Ingestion logs
aws logs tail /ecs/pdc-ingestion --follow --region us-east-1
```

**Set up CloudWatch alarms:**
- High error rates
- Database connection failures
- ECS task failures

### Step 7.3: Configure Alerting Service

Update the ECS task definition with your alert service URL:

1. Go to ECS → Task Definitions → `pdc-app`
2. Create new revision
3. Update `ALERT_SERVICE_URL` environment variable
4. Update service to use new revision

### Step 7.4: Set Up Custom Domain (Optional)

```bash
# Create Route53 hosted zone
aws route53 create-hosted-zone --name yourdomain.com --caller-reference $(date +%s)

# Get ALB DNS name
terraform output alb_dns_name

# Create A record pointing to ALB
# (Use AWS Console or CLI)
```

### Step 7.5: Enable HTTPS (Optional)

```bash
# Request SSL certificate
aws acm request-certificate \
    --domain-name yourdomain.com \
    --validation-method DNS \
    --region us-east-1

# Update ALB listener to use HTTPS
# (Update terraform/main.tf or use AWS Console)
```

---

## Complete Workflow Summary

### Daily Development Workflow

1. **Start development**:
   ```bash
   venv\Scripts\activate
   python run.py
   ```

2. **Make changes** to code

3. **Test locally**:
   ```bash
   pytest
   python scripts/smoketest.py
   ```

4. **Commit and push**:
   ```bash
   git add .
   git commit -m "Description of changes"
   git push
   ```

5. **CI runs automatically** (tests, linting)

6. **Merge to main** triggers deployment

### Deployment Workflow

1. **Code changes** → Push to GitHub
2. **CI pipeline** → Runs tests automatically
3. **Deploy pipeline** → Deploys to AWS (on merge to main)
4. **Smoke tests** → Validates deployment
5. **Monitor** → Check CloudWatch logs

### File Ingestion Workflow

1. **Files dropped** to SFTP server `/uploads` directory
2. **Scheduled task** runs every hour (EventBridge)
3. **Ingestion worker** processes files:
   - Downloads from SFTP
   - Parses (CSV or pipe-delimited)
   - Ingests into database
   - Moves to `/processed`
4. **Alerts sent** if ingestion fails

---

## Quick Reference Commands

### Local Development
```bash
# Run app
python run.py

# Run tests
pytest

# Run smoke tests
python scripts/smoketest.py

# Test SFTP
python scripts/test_sftp.py

# Ingest files
python scripts/ingest_files.py
```

### Deployment
```bash
# Deploy infrastructure
cd terraform
terraform apply

# Build and push Docker image
docker build -t pdc-app .
docker push $ECR_URL:latest

# Force ECS update
aws ecs update-service --cluster pdc-cluster --service pdc-app-service --force-new-deployment
```

### Monitoring
```bash
# View logs
aws logs tail /ecs/pdc-app --follow

# Check ECS service
aws ecs describe-services --cluster pdc-cluster --services pdc-app-service

# Check ALB health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

---

## Troubleshooting

### Local Issues
- See [SETUP_GUIDE.md](SETUP_GUIDE.md) troubleshooting section
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

### Deployment Issues
- See [AWS_DEPLOYMENT_GUIDE.md](AWS_DEPLOYMENT_GUIDE.md) troubleshooting section
- Check CloudWatch logs
- Verify Terraform state: `terraform show`

### SFTP Issues
- See [SFTP_SETUP_GUIDE.md](SFTP_SETUP_GUIDE.md) troubleshooting section
- Test connection: `python scripts/test_sftp.py`

---

## Next Steps

1. ✅ **Local setup complete** → Start developing
2. ✅ **SFTP configured** → Test file ingestion
3. ✅ **Tests passing** → Ready for CI/CD
4. ✅ **Deployed to AWS** → Monitor and optimize
5. ✅ **Production ready** → Scale as needed

## Support

- **Setup issues**: [SETUP_GUIDE.md](SETUP_GUIDE.md)
- **SFTP issues**: [SFTP_SETUP_GUIDE.md](SFTP_SETUP_GUIDE.md)
- **Deployment issues**: [AWS_DEPLOYMENT_GUIDE.md](AWS_DEPLOYMENT_GUIDE.md)
- **General help**: [README.md](README.md)

