# Permission Constraints Solution

## The Problem

Your AWS IAM permissions policy restricts IAM role management to the `/interview/` path:

```json
{
  "Sid": "IAMDeleteRole",
  "Effect": "Allow",
  "Action": "iam:DeleteRole",
  "Resource": "arn:aws:iam::*:role/interview/*"
},
{
  "Sid": "IAMModifyRoleWithBoundary",
  "Effect": "Allow",
  "Action": ["iam:PutRolePolicy", "iam:DeleteRolePolicy", ...],
  "Resource": "arn:aws:iam::*:role/interview/*",
  ...
}
```

### Current State in AWS
- Roles exist at **root path** `/`:
  - `pdc-ecs-task-execution-role`
  - `pdc-ecs-task-app-role`
  - `pdc-eventbridge-ecs-role`
- Roles have **no permissions boundary**

### Constraint
❌ You **CANNOT** delete or modify policies on roles at `/` path  
✅ You **CAN** only delete/modify roles at `/interview/` path

## The Solution

### What We Did
1. **Matched Terraform config to AWS reality**:
   - Set `path = "/"` (not `/interview/`)
   - Removed `permissions_boundary` attribute

2. **Added lifecycle protection**:
   ```hcl
   lifecycle {
     ignore_changes = [path, permissions_boundary]
   }
   ```

3. **Protected IAM role policies from replacement**:
   ```hcl
   lifecycle {
     ignore_changes = [policy]
   }
   ```

### Why This Works
- ✅ Terraform won't try to change the path (would force recreation)
- ✅ Terraform won't try to add permissions boundary (would fail)
- ✅ Terraform won't try to replace policies (would need delete permission)
- ✅ Terraform CAN manage ECS, ECR, EventBridge, etc. (full permissions)

## What Terraform Will Manage

### ✅ Can Manage (Full Control)
- ECS Clusters
- ECS Task Definitions
- ECS Services
- ECR Repositories
- EventBridge Rules
- EventBridge Targets
- Load Balancers
- RDS Databases
- Secrets Manager
- CloudWatch Logs
- All other AWS services

### ⚠️ Limited Management (Read-Only Mode)
- **IAM Roles**: Terraform tracks them but won't modify them
- **IAM Policies**: Terraform tracks them but won't update content

## Deployment Instructions

### Step 1: Verify Configuration
```powershell
cd C:\Users\Administrator\Dev_Env\vest\terraform
terraform plan -out=tfplan
```

**Expected output:**
```
Plan: 2 to add, 2 to change, 0 to destroy
```

- 2 to add: ECS task definitions
- 2 to change: ECS service and EventBridge target
- **0 to destroy**: No IAM roles or policies will be deleted ✅

### Step 2: Apply Changes
```powershell
terraform apply -auto-approve tfplan
```

### Step 3: Continue with Deployment
After Terraform completes, continue with Docker build and push:

```powershell
# Get ECR URL
$ECR_URL = terraform output -raw ecr_repository_url

# Login to ECR
$ECR_REGISTRY = $ECR_URL.Split('/')[0]
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build and push
cd ..
docker build -t "${ECR_URL}:latest" .
docker push "${ECR_URL}:latest"

# Update ECS service (see DEPLOYMENT_STEPS.md for full commands)
```

## Alternative: Move to /interview/ Path (Requires Admin)

If you want full Terraform management with permissions boundary:

### Option A: Ask AWS Admin to Move Roles
1. Admin deletes existing roles at `/`
2. Terraform creates new roles at `/interview/` with boundary
3. Full Terraform management enabled

### Option B: Work with Current Setup
- Keep roles at `/` path
- Accept limited Terraform management of IAM
- Everything else works perfectly ✅

**Recommendation**: Keep current setup. It works and requires no admin intervention.

## Troubleshooting

### If you see "Cannot delete role policy" errors:
- Check that `ignore_changes = [policy]` is present on all role policies
- Verify roles have `path = "/"` not `/interview/`

### If you see "Cannot put permissions boundary" errors:
- Check that `ignore_changes = [path, permissions_boundary]` is present on all roles

### If you need to update IAM policies manually:
1. Update in AWS Console
2. Run `terraform plan` - should show no changes
3. If it shows changes, add field to `ignore_changes`

## Summary

✅ **Current Configuration**: Works within your permission constraints  
✅ **No Admin Help Needed**: Can deploy everything yourself  
✅ **Full Application Deployment**: Can manage all infrastructure except IAM  
✅ **Safe**: Won't accidentally try to delete/modify protected resources  

The solution accepts the IAM permission constraints and works around them gracefully.

