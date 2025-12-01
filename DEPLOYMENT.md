# Deployment Guide

This guide covers deploying the Portfolio Data Clearinghouse to AWS using Terraform and GitHub Actions.

**📖 For a detailed step-by-step guide, see [AWS_DEPLOYMENT_GUIDE.md](AWS_DEPLOYMENT_GUIDE.md)**

## Prerequisites

1. AWS Account with appropriate permissions
2. GitHub repository with Actions enabled
3. Terraform >= 1.0
4. AWS CLI configured
5. Docker (for building images)

## AWS Setup

### 1. Create S3 Bucket for Terraform State

```bash
aws s3 mb s3://pdc-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
    --bucket pdc-terraform-state \
    --versioning-configuration Status=Enabled
```

### 2. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

- `AWS_ACCESS_KEY_ID`: AWS access key with deployment permissions
- `AWS_SECRET_ACCESS_KEY`: AWS secret access key
- `API_URL`: The deployed API URL (will be available after first deployment)
- `API_KEY`: API key for authentication
- `DB_PASSWORD`: Database password (or use AWS Secrets Manager)

### 3. Configure Terraform Variables

Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and update:

```hcl
aws_region       = "us-east-1"
db_instance_class = "db.t3.micro"
db_username      = "postgres"
db_password      = "YOUR_SECURE_PASSWORD"
```

**Note**: Never commit `terraform.tfvars` to version control!

## Deployment Steps

### Manual Deployment

1. **Initialize Terraform**:
```bash
cd terraform
terraform init
```

2. **Plan Deployment**:
```bash
terraform plan -out=tfplan
```

3. **Apply Infrastructure**:
```bash
terraform apply tfplan
```

4. **Build and Push Docker Image**:
```bash
# Get ECR repository URL from Terraform output
ECR_URL=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL

# Build image
docker build -t pdc-app .

# Tag and push
docker tag pdc-app:latest $ECR_URL:latest
docker push $ECR_URL:latest
```

5. **Deploy Application**:
   - Create ECS task definition with the Docker image
   - Create ECS service pointing to the ALB target group
   - Configure environment variables (DATABASE_URL, API_KEY, etc.)

### Automated Deployment via GitHub Actions

The `.github/workflows/deploy.yml` workflow will:
1. Configure AWS credentials
2. Initialize and apply Terraform
3. Run smoke tests

**Note**: You'll need to create the ECS task definition and service separately, or add them to Terraform.

## Post-Deployment

### 1. Set Up File Ingestion Schedule

The file ingestion can be scheduled using:
- AWS EventBridge (CloudWatch Events) + Lambda
- ECS Scheduled Tasks
- Cron job on EC2 instance

Example EventBridge rule:
```json
{
  "ScheduleExpression": "rate(1 hour)",
  "Targets": [
    {
      "Arn": "arn:aws:lambda:us-east-1:ACCOUNT:function:ingest-files",
      "Id": "1"
    }
  ]
}
```

### 2. Configure Alerting Service

Update `ALERT_SERVICE_URL` to point to your alerting service:
- PagerDuty
- Datadog
- CloudWatch Alarms
- Custom service

### 3. Set Up Monitoring

- CloudWatch Logs for application logs
- CloudWatch Metrics for custom metrics
- CloudWatch Alarms for critical errors
- X-Ray for distributed tracing (optional)

## Environment Variables

Set these in your ECS task definition or deployment configuration:

```bash
DATABASE_URL=postgresql://postgres:PASSWORD@RDS_ENDPOINT:5432/pdc_db
API_KEY=your-secure-api-key
SFTP_HOST=your-sftp-host
SFTP_USERNAME=sftp_user
SFTP_KEY_PATH=/app/.ssh/id_ed25519
ALERT_SERVICE_URL=https://your-alert-service.com/alerts
```

## Troubleshooting

### Database Connection Issues
- Verify security groups allow traffic from ECS to RDS
- Check RDS endpoint and credentials
- Verify database exists and is accessible

### SFTP Connection Issues
- Verify SSH key is mounted correctly
- Check SFTP host and port
- Verify network connectivity from ECS to SFTP server

### API Not Responding
- Check ALB health checks
- Verify ECS tasks are running
- Check CloudWatch logs for errors
- Verify security groups allow traffic

## Cost Optimization

- Use RDS `db.t3.micro` for development
- Use ECS Fargate Spot for non-critical workloads
- Enable RDS automated backups only for production
- Use CloudWatch Logs retention policies
- Consider using Aurora Serverless for variable workloads

