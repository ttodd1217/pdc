# Local Deployment Steps (Following CD Pipeline)

## Prerequisites
- AWS credentials configured
- Docker Desktop running
- PowerShell or Git Bash

## Step-by-Step Commands

### Step 1: Verify AWS Credentials
```powershell
cd C:\Users\Administrator\Dev_Env\vest
aws sts get-caller-identity --region us-east-2
```

### Step 2: Terraform Init
```powershell
cd terraform
terraform init
```

### Step 3: Import Existing Resources (if needed)
```powershell
# Check what's already in state
terraform state list

# Import if needed (errors are OK if already imported)
terraform import aws_iam_role.ecs_task_execution_role pdc-ecs-task-execution-role
terraform import aws_iam_role.ecs_task_role pdc-ecs-task-app-role
terraform import aws_iam_role.eventbridge_ecs pdc-eventbridge-ecs-role
```

### Step 4: Terraform Plan
```powershell
terraform plan -out=tfplan
```
**Review the output carefully!** Look for:
- ✅ Resources to create (+)
- ✅ Resources to modify (~)
- ⚠️ Resources to destroy (-/+)

### Step 5: Terraform Apply
```powershell
terraform apply -auto-approve tfplan
```

### Step 6: Get ECR Repository URL
```powershell
$ECR_URL = terraform output -raw ecr_repository_url
Write-Host "ECR URL: $ECR_URL"
```

### Step 7: Login to ECR
```powershell
$ECR_REGISTRY = $ECR_URL.Split('/')[0]
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin $ECR_REGISTRY
```

### Step 8: Build and Push Docker Image
```powershell
cd ..  # Back to project root
docker build -t "${ECR_URL}:latest" .
docker push "${ECR_URL}:latest"
```

### Step 9: Update ECS Service
```powershell
# Get current task definition
$TASK_DEF = aws ecs describe-task-definition --task-definition pdc-app --region us-east-2 --query 'taskDefinition' --output json | ConvertFrom-Json

# Update image
$TASK_DEF.containerDefinitions[0].image = "${ECR_URL}:latest"

# Remove read-only fields
$TASK_DEF.PSObject.Properties.Remove('taskDefinitionArn')
$TASK_DEF.PSObject.Properties.Remove('revision')
$TASK_DEF.PSObject.Properties.Remove('status')
$TASK_DEF.PSObject.Properties.Remove('requiresAttributes')
$TASK_DEF.PSObject.Properties.Remove('compatibilities')
$TASK_DEF.PSObject.Properties.Remove('registeredAt')
$TASK_DEF.PSObject.Properties.Remove('registeredBy')

# Register new task definition
$NEW_TASK_JSON = $TASK_DEF | ConvertTo-Json -Depth 10 -Compress
$NEW_TASK_ARN = (aws ecs register-task-definition --region us-east-2 --cli-input-json $NEW_TASK_JSON --query 'taskDefinition.taskDefinitionArn' --output text)

# Update service
aws ecs update-service --cluster pdc-cluster --service pdc-app-service --task-definition $NEW_TASK_ARN --region us-east-2
```

### Step 10: Get Application URL
```powershell
cd terraform
$ALB_DNS = terraform output -raw alb_dns_name
Write-Host "Application URL: http://$ALB_DNS"
```

## Verification

Wait 2-3 minutes for ECS tasks to start, then:

```powershell
# Check service status
aws ecs describe-services --cluster pdc-cluster --services pdc-app-service --region us-east-2 --query 'services[0].{DesiredCount:desiredCount,RunningCount:runningCount,Status:status}' --output table

# Test the API
$API_URL = "http://$(terraform output -raw alb_dns_name)"
curl "${API_URL}/health"
```

## Troubleshooting

### If Terraform fails:
```powershell
# Check state
terraform state list

# View specific resource
terraform state show aws_iam_role.ecs_task_execution_role

# If needed, remove from state and re-import
terraform state rm aws_iam_role.ecs_task_execution_role
terraform import aws_iam_role.ecs_task_execution_role pdc-ecs-task-execution-role
```

### If Docker build fails:
```powershell
# Check Docker is running
docker ps

# Clean up old images
docker system prune -a
```

### If ECS update fails:
```powershell
# Check ECS cluster
aws ecs describe-clusters --clusters pdc-cluster --region us-east-2

# Check task definition
aws ecs describe-task-definition --task-definition pdc-app --region us-east-2
```

