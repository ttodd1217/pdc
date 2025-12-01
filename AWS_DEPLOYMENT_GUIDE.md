# AWS Deployment Guide - Step by Step

This is a comprehensive step-by-step guide to deploy the Portfolio Data Clearinghouse to AWS.

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS Account with admin/appropriate permissions
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Terraform >= 1.0 installed
- [ ] Docker installed (for building images)
- [ ] GitHub repository (for CI/CD)
- [ ] SSH private key file for SFTP access

## Step 1: Prepare AWS Account

### 1.1 Configure AWS CLI

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region (e.g., us-east-1)
# Enter default output format (json)
```

### 1.2 Create S3 Bucket for Terraform State

```bash
# Create bucket for Terraform state
aws s3 mb s3://pdc-terraform-state --region us-east-1

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
    --bucket pdc-terraform-state \
    --versioning-configuration Status=Enabled

# Optional: Enable encryption
aws s3api put-bucket-encryption \
    --bucket pdc-terraform-state \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'
```

## Step 2: Configure Terraform Variables

### 2.1 Create terraform.tfvars

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### 2.2 Edit terraform.tfvars

Open `terraform/terraform.tfvars` and set your values:

```hcl
aws_region       = "us-east-1"
db_instance_class = "db.t3.micro"  # Use db.t3.small or larger for production
db_username      = "postgres"
db_password      = "YOUR_SECURE_PASSWORD_HERE"  # Change this!

# Optional: If you have SFTP details ready
sftp_host        = "your-sftp-host.com"
sftp_username    = "sftp_user"

# API key for authentication
api_key          = "YOUR_SECURE_API_KEY_HERE"  # Change this!
```

**⚠️ Important**: Never commit `terraform.tfvars` to git! It's already in `.gitignore`.

## Step 3: Store Secrets in AWS Secrets Manager

### 3.1 Store SFTP Private Key

```bash
# Read your SSH private key and store it
aws secretsmanager create-secret \
    --name pdc/sftp-key \
    --secret-string file://~/.ssh/id_ed25519 \
    --region us-east-1

# Or if secret already exists, update it
aws secretsmanager update-secret \
    --secret-id pdc/sftp-key \
    --secret-string file://~/.ssh/id_ed25519 \
    --region us-east-1
```

### 3.2 Store Alert API Key

```bash
aws secretsmanager create-secret \
    --name pdc/alert-api-key \
    --secret-string "your-alert-api-key" \
    --region us-east-1
```

## Step 4: Deploy Infrastructure with Terraform

### 4.1 Initialize Terraform

```bash
cd terraform
terraform init
```

This will:
- Download AWS provider
- Configure S3 backend for state storage

### 4.2 Review Terraform Plan

```bash
terraform plan -out=tfplan
```

Review the plan to see what resources will be created:
- VPC and networking
- RDS PostgreSQL database
- ECS cluster
- Application Load Balancer
- ECR repository
- Security groups
- CloudWatch log groups

### 4.3 Apply Infrastructure

```bash
terraform apply tfplan
```

This will take approximately 10-15 minutes. You'll see:
- VPC creation
- RDS database provisioning (takes longest)
- ECS cluster setup
- Load balancer creation

### 4.4 Save Important Outputs

After deployment completes, save the outputs:

```bash
# Get database endpoint
terraform output database_endpoint

# Get ALB DNS name (your API URL)
terraform output alb_dns_name

# Get ECR repository URL
terraform output ecr_repository_url
```

## Step 5: Build and Push Docker Image

### 5.1 Login to ECR

```bash
# Get ECR URL from Terraform output
ECR_URL=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin $ECR_URL
```

### 5.2 Build Docker Image

```bash
# From project root directory
cd ..
docker build -t pdc-app .
```

### 5.3 Tag and Push Image

```bash
# Tag the image
docker tag pdc-app:latest $ECR_URL:latest

# Push to ECR
docker push $ECR_URL:latest
```

## Step 6: Update ECS Task Definition with Environment Variables

The Terraform configuration creates the ECS task definition, but you may need to update it with your specific values.

### 6.1 Get Database Endpoint

```bash
cd terraform
DB_ENDPOINT=$(terraform output -raw database_endpoint)
```

### 6.2 Update Task Definition (if needed)

You can update the task definition via AWS Console or CLI:

```bash
# The task definition is in terraform/ecs.tf
# Update the environment variables section if needed
# Then re-run: terraform apply
```

Or update via AWS Console:
1. Go to ECS → Task Definitions
2. Find `pdc-app` task definition
3. Create new revision
4. Update environment variables:
   - `DATABASE_URL`: `postgresql://postgres:YOUR_PASSWORD@$DB_ENDPOINT:5432/pdc_db`
   - `API_KEY`: Your API key
   - `SFTP_HOST`: Your SFTP host
   - `SFTP_USERNAME`: Your SFTP username
   - `ALERT_SERVICE_URL`: Your alert service URL

## Step 7: Deploy ECS Service

The Terraform configuration should have created the ECS service. Verify it's running:

```bash
# Check ECS service status
aws ecs describe-services \
    --cluster pdc-cluster \
    --services pdc-app-service \
    --region us-east-1

# Check running tasks
aws ecs list-tasks \
    --cluster pdc-cluster \
    --service-name pdc-app-service \
    --region us-east-1
```

If the service wasn't created, you can create it manually or update Terraform and re-apply.

## Step 8: Verify Deployment

### 8.1 Get Your API URL

```bash
cd terraform
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "API URL: http://$ALB_DNS"
```

### 8.2 Test Health Endpoint

```bash
curl http://$ALB_DNS/health
```

Expected response:
```json
{
  "status": "healthy",
  "database": "healthy",
  "timestamp": "2025-01-15T10:00:00.000Z"
}
```

### 8.3 Test API Endpoint (with API key)

```bash
# Get your API key from terraform.tfvars or environment
API_KEY="your-api-key"

curl -H "X-API-Key: $API_KEY" \
  "http://$ALB_DNS/api/blotter?date=2025-01-15"
```

### 8.4 Run Smoke Tests

```bash
export API_URL=http://$ALB_DNS
export API_KEY=your-api-key
python scripts/smoketest.py
```

## Step 9: Set Up GitHub Actions (Optional but Recommended)

### 9.1 Add GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `API_KEY`: Your API key (same as in terraform.tfvars)
- `DB_PASSWORD`: Your database password

### 9.2 Update deploy.yml (if needed)

The `.github/workflows/deploy.yml` should work, but you may need to:
- Update the region if different from us-east-1
- Add additional environment variables

### 9.3 Trigger Deployment

Push to `main` branch or manually trigger the workflow:
- Go to Actions tab
- Select "Deploy to AWS" workflow
- Click "Run workflow"

## Step 10: Post-Deployment Configuration

### 10.1 Set Up Scheduled Ingestion

The Terraform configuration includes a scheduled task that runs every hour. Verify it's set up:

```bash
# Check EventBridge rule
aws events describe-rule --name pdc-ingestion-schedule --region us-east-1
```

### 10.2 Configure Alerting Service

Update the `ALERT_SERVICE_URL` environment variable in your ECS task definition to point to your alerting service (PagerDuty, Datadog, etc.).

### 10.3 Set Up Monitoring

1. **CloudWatch Logs**: Already configured, view at:
   - `/ecs/pdc-app` - Application logs
   - `/ecs/pdc-ingestion` - Ingestion logs

2. **CloudWatch Alarms**: Create alarms for:
   - High error rates
   - Database connection failures
   - ECS task failures

3. **ALB Health Checks**: Already configured to check `/health` endpoint

## Troubleshooting

### Issue: Terraform apply fails

**Database creation timeout**:
- RDS can take 10-15 minutes to create
- Check AWS Console for RDS status
- Verify security groups are correct

**S3 backend error**:
- Ensure bucket exists: `aws s3 ls s3://pdc-terraform-state`
- Check bucket permissions

### Issue: ECS tasks not starting

**Check logs**:
```bash
aws logs tail /ecs/pdc-app --follow --region us-east-1
```

**Common causes**:
- Database connection string incorrect
- Missing environment variables
- Secrets Manager permissions
- Security group blocking traffic

### Issue: API not responding

**Check ALB health checks**:
1. Go to EC2 → Load Balancers
2. Select `pdc-alb`
3. Check Target Health tab
4. Ensure targets are healthy

**Check ECS service**:
```bash
aws ecs describe-services \
    --cluster pdc-cluster \
    --services pdc-app-service \
    --region us-east-1
```

### Issue: Database connection errors

**Verify**:
1. RDS is in same VPC as ECS
2. Security group allows port 5432 from ECS security group
3. Database endpoint is correct
4. Credentials are correct

**Test connection**:
```bash
# From ECS task or local machine with access
psql -h $DB_ENDPOINT -U postgres -d pdc_db
```

## Cost Estimation

Approximate monthly costs (us-east-1):

- **RDS db.t3.micro**: ~$15/month
- **ECS Fargate** (2 tasks, 0.25 vCPU, 512MB): ~$15/month
- **ALB**: ~$20/month
- **ECR**: ~$1/month (storage)
- **CloudWatch Logs**: ~$5/month
- **Data Transfer**: ~$5/month
- **Total**: ~$60-80/month

For production, consider:
- RDS db.t3.small or larger: +$30/month
- More ECS tasks for high availability: +$15/task/month
- Reserved instances for cost savings

## Next Steps

1. **Set up custom domain**: Add Route53 record pointing to ALB
2. **Enable HTTPS**: Add SSL certificate via ACM and update ALB listener
3. **Set up backup**: Configure RDS automated backups
4. **Monitor costs**: Set up AWS Cost Explorer alerts
5. **Scale horizontally**: Increase ECS task count for high availability

## Quick Reference Commands

```bash
# View Terraform outputs
cd terraform && terraform output

# View ECS service status
aws ecs describe-services --cluster pdc-cluster --services pdc-app-service

# View application logs
aws logs tail /ecs/pdc-app --follow

# Update and push new Docker image
docker build -t pdc-app .
docker tag pdc-app:latest $ECR_URL:latest
docker push $ECR_URL:latest

# Force new ECS deployment (picks up new image)
aws ecs update-service --cluster pdc-cluster --service pdc-app-service --force-new-deployment
```

## Support

For issues or questions:
- Check CloudWatch logs
- Review Terraform state: `terraform show`
- Check AWS Console for resource status
- Review application logs in CloudWatch




