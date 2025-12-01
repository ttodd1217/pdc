# Quick Commands Reference

## Local Development

```bash
# Activate virtual environment
venv\Scripts\activate  # Windows
source venv/bin/activate  # Mac/Linux

# Run application
python run.py

# Run tests
pytest
pytest --cov=app --cov-report=html

# Run smoke tests
python scripts/smoketest.py
```

## SFTP Operations

```bash
# Test SFTP connection
python scripts/test_sftp.py

# Generate SSH keys
bash scripts/setup_sftp_key.sh

# Upload file to SFTP (use your mapped host port; defaults to 3022)
scp -i ~/.ssh/id_ed25519 -P ${SFTP_HOST_PORT:-3022} file.csv sftp_user@localhost:/uploads/

# Run file ingestion
python scripts/ingest_files.py
```

## API Testing

```bash
# Health check
curl http://localhost:5001/health

# Blotter endpoint
curl -H "X-API-Key: dev-api-key" "http://localhost:5001/api/blotter?date=2025-01-15"

# Positions endpoint
curl -H "X-API-Key: dev-api-key" "http://localhost:5001/api/positions?date=2025-01-15"

# Alarms endpoint
curl -H "X-API-Key: dev-api-key" "http://localhost:5001/api/alarms?date=2025-01-15"
```

## Database Operations

```bash
# Initialize database
python -c "from app import create_app, db; app = create_app(); app.app_context().push(); db.create_all()"

# Load sample data
python -c "from app import create_app; from app.services.file_ingestion import FileIngestionService; app = create_app(); app.app_context().push(); FileIngestionService.ingest_file('data/example_format1.csv')"
```

## Docker Operations

```bash
# Start local SFTP server
docker-compose -f docker-compose.sftp.yml up -d

# Stop SFTP server
docker-compose -f docker-compose.sftp.yml down

# Build Docker image
docker build -t pdc-app .

# Run Docker container
docker run -p 5001:5000 -e DATABASE_URL=sqlite:///pdc.db -e API_KEY=dev-api-key pdc-app
```

## AWS Deployment

```bash
# Initialize Terraform
cd terraform
terraform init

# Plan deployment
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Get outputs
terraform output alb_dns_name
terraform output database_endpoint

# Login to ECR
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin $ECR_URL

# Build and push image
docker build -t pdc-app .
docker tag pdc-app:latest $ECR_URL:latest
docker push $ECR_URL:latest

# Force ECS update
aws ecs update-service --cluster pdc-cluster --service pdc-app-service --force-new-deployment
```

## Monitoring

```bash
# View application logs
aws logs tail /ecs/pdc-app --follow --region us-east-2

# View ingestion logs
aws logs tail /ecs/pdc-ingestion --follow --region us-east-2

# Check ECS service status
aws ecs describe-services --cluster pdc-cluster --services pdc-app-service --region us-east-2

# Check running tasks
aws ecs list-tasks --cluster pdc-cluster --service-name pdc-app-service --region us-east-2
```

## Git Operations

```bash
# Commit and push
git add .
git commit -m "Description"
git push

# Check CI/CD status
# Go to GitHub → Actions tab
```

## Alert Service

```bash
# Start mock alert service
python scripts/mock_alert_service.py

# View received alerts
curl http://localhost:5001/alerts
```

## Environment Variables

```bash
# Windows PowerShell
$env:DATABASE_URL="sqlite:///pdc.db"
$env:API_KEY="dev-api-key"
$env:API_URL="http://localhost:5001"

# Windows CMD
set DATABASE_URL=sqlite:///pdc.db
set API_KEY=dev-api-key

# Mac/Linux
export DATABASE_URL=sqlite:///pdc.db
export API_KEY=dev-api-key
```




