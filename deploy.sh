#!/bin/bash
# Quick deployment script for AWS
# Usage: ./deploy.sh

set -e  # Exit on error

echo "🚀 Starting AWS Deployment for Portfolio Data Clearinghouse"
echo "============================================================"

# Check prerequisites
echo "📋 Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI not found. Please install it."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform not found. Please install it."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ Docker not found. Please install it."; exit 1; }

# Check AWS credentials
echo "🔐 Checking AWS credentials..."
aws sts get-caller-identity >/dev/null 2>&1 || { echo "❌ AWS credentials not configured. Run 'aws configure'"; exit 1; }
echo "✅ AWS credentials OK"

# Check terraform.tfvars exists
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo "⚠️  terraform.tfvars not found. Creating from example..."
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars
    echo "⚠️  Please edit terraform/terraform.tfvars with your values before continuing!"
    exit 1
fi

# Step 1: Create S3 bucket for state (if needed)
echo ""
echo "📦 Step 1: Setting up Terraform state bucket..."
BUCKET_NAME="pdc-terraform-state"
REGION=$(grep aws_region terraform/terraform.tfvars | cut -d'"' -f2 || echo "us-east-1")

if ! aws s3 ls "s3://$BUCKET_NAME" 2>&1 >/dev/null; then
    echo "Creating S3 bucket: $BUCKET_NAME"
    aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    echo "✅ S3 bucket created"
else
    echo "✅ S3 bucket already exists"
fi

# Step 2: Initialize Terraform
echo ""
echo "🔧 Step 2: Initializing Terraform..."
cd terraform
terraform init
echo "✅ Terraform initialized"

# Step 3: Plan deployment
echo ""
echo "📝 Step 3: Planning deployment..."
terraform plan -out=tfplan
echo "✅ Plan created"

# Step 4: Apply infrastructure
echo ""
echo "🏗️  Step 4: Applying infrastructure (this may take 10-15 minutes)..."
read -p "Continue with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 1
fi

terraform apply tfplan
echo "✅ Infrastructure deployed"

# Step 5: Get outputs
echo ""
echo "📤 Step 5: Getting deployment outputs..."
ECR_URL=$(terraform output -raw ecr_repository_url)
ALB_DNS=$(terraform output -raw alb_dns_name)
DB_ENDPOINT=$(terraform output -raw database_endpoint)

echo "ECR Repository: $ECR_URL"
echo "API URL: http://$ALB_DNS"
echo "Database Endpoint: $DB_ENDPOINT"

# Step 6: Build and push Docker image
echo ""
echo "🐳 Step 6: Building and pushing Docker image..."
cd ..

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region "$REGION" | \
    docker login --username AWS --password-stdin "$ECR_URL"

# Build image
echo "Building Docker image..."
docker build -t pdc-app .

# Tag and push
echo "Pushing to ECR..."
docker tag pdc-app:latest "$ECR_URL:latest"
docker push "$ECR_URL:latest"
echo "✅ Docker image pushed"

# Step 7: Force ECS service update
echo ""
echo "🔄 Step 7: Updating ECS service..."
CLUSTER_NAME="pdc-cluster"
SERVICE_NAME="pdc-app-service"

aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --force-new-deployment \
    --region "$REGION" >/dev/null

echo "✅ ECS service update triggered"

# Step 8: Wait for service to stabilize
echo ""
echo "⏳ Step 8: Waiting for service to stabilize..."
echo "This may take a few minutes..."
aws ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$REGION"

echo "✅ Service is stable"

# Step 9: Test deployment
echo ""
echo "🧪 Step 9: Testing deployment..."
sleep 10  # Give ALB time to register targets

HEALTH_URL="http://$ALB_DNS/health"
echo "Testing health endpoint: $HEALTH_URL"

if curl -f -s "$HEALTH_URL" >/dev/null; then
    echo "✅ Health check passed!"
else
    echo "⚠️  Health check failed. Check CloudWatch logs:"
    echo "   aws logs tail /ecs/pdc-app --follow"
fi

echo ""
echo "============================================================"
echo "🎉 Deployment Complete!"
echo ""
echo "📋 Important Information:"
echo "   API URL: http://$ALB_DNS"
echo "   Health Check: http://$ALB_DNS/health"
echo "   Database: $DB_ENDPOINT"
echo ""
echo "📝 Next Steps:"
echo "   1. Test API: curl -H 'X-API-Key: YOUR_KEY' http://$ALB_DNS/api/blotter?date=2025-01-15"
echo "   2. Run smoke tests: export API_URL=http://$ALB_DNS && python scripts/smoketest.py"
echo "   3. Check logs: aws logs tail /ecs/pdc-app --follow"
echo "   4. View in AWS Console: https://console.aws.amazon.com/ecs"
echo "============================================================"

