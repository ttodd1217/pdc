# IAM Role Migration Guide: Moving to /interview/ Path

## The Problem

Your AWS permissions **ONLY** allow managing IAM roles at `/interview/` path:
- ✅ Can create/delete/modify roles at `arn:aws:iam::*:role/interview/*`
- ❌ Cannot manage roles at `arn:aws:iam::*:role/*` (root path)

Your current roles exist at `/` (root path), which means Terraform cannot manage them.

## The Solution: Create New Roles

We'll create **NEW** roles at `/interview/` path and leave the old ones orphaned in AWS.

### Why This Works
1. ✅ New roles will be at `/interview/` path - **within your permissions**
2. ✅ New roles will have the required permissions boundary
3. ✅ Old roles at `/` will remain in AWS but unused (harmless)
4. ✅ ECS tasks and services will use the new role ARNs

## Step-by-Step Migration

### Step 1: Remove Old Roles from Terraform State

This tells Terraform to stop managing the old roles (but leaves them in AWS).

**On Windows (PowerShell):**
```powershell
cd C:\Users\Administrator\Dev_Env\vest\terraform
.\migrate_to_interview_path.ps1
```

**On Linux/Mac (Bash):**
```bash
cd terraform
bash migrate_to_interview_path.sh
```

**Expected Output:**
```
=== Migrating IAM Roles to /interview/ Path ===

Step 1: Removing old roles from Terraform state...
Removed aws_iam_role.ecs_task_execution_role
Removed aws_iam_role.ecs_task_role  
Removed aws_iam_role.eventbridge_ecs

Step 2: Removing old role policies from Terraform state...
Removed aws_iam_role_policy.ecs_task_execution_secrets
Removed aws_iam_role_policy.ecs_task_permissions
Removed aws_iam_role_policy.eventbridge_ecs

✓ Migration preparation complete!
```

### Step 2: Terraform Plan

```powershell
terraform plan -out=tfplan
```

**Expected Output:**
```
Plan: 9 to add, 4 to change, 0 to destroy
```

**What will be created:**
- 3 NEW IAM roles at `/interview/` path ✅
- 3 NEW IAM role policies ✅  
- 1 NEW IAM role policy attachment ✅
- 2 NEW ECS task definitions (with new role ARNs) ✅

**What will be updated:**
- ECS service (to use new task definition)
- EventBridge target (to use new role ARN)
- CloudWatch event target
- Other dependent resources

**What will NOT be destroyed:**
- 0 resources will be destroyed ✅
- Old roles at `/` path remain in AWS (orphaned but harmless)

### Step 3: Terraform Apply

```powershell
terraform apply -auto-approve tfplan
```

This will:
1. ✅ Create new roles at `/interview/pdc-ecs-task-execution-role`
2. ✅ Create new roles at `/interview/pdc-ecs-task-app-role`
3. ✅ Create new role at `/interview/pdc-eventbridge-ecs-role`
4. ✅ Attach policies with permissions boundary
5. ✅ Create new ECS task definitions using new roles
6. ✅ Update ECS services to use new task definitions

### Step 4: Verify the New Roles

```powershell
# List roles at /interview/ path
aws iam list-roles --path-prefix /interview/ --query 'Roles[*].[RoleName,Arn]' --output table

# Should show:
# pdc-ecs-task-execution-role  | arn:aws:iam::ACCOUNT:role/interview/pdc-ecs-task-execution-role
# pdc-ecs-task-app-role        | arn:aws:iam::ACCOUNT:role/interview/pdc-ecs-task-app-role
# pdc-eventbridge-ecs-role     | arn:aws:iam::ACCOUNT:role/interview/pdc-eventbridge-ecs-role
```

### Step 5: Continue with Deployment

After Terraform succeeds, continue with Docker deployment:

```powershell
# Get ECR URL
cd terraform
$ECR_URL = terraform output -raw ecr_repository_url

# Build and push Docker image
cd ..
docker build -t "${ECR_URL}:latest" .
docker push "${ECR_URL}:latest"

# ECS will automatically use the new roles with new task definitions
```

## What About the Old Roles?

The old roles at `/` path will remain in AWS:
- ❌ Not used by any services (orphaned)
- ⚠️ You cannot delete them (no permissions)
- ✅ They don't cost anything
- ✅ They don't interfere with the new setup

**Options:**
1. **Leave them** - Harmless, costs nothing, no action needed
2. **Ask AWS admin to delete** - If you want a clean account

## Troubleshooting

### If migration script shows "not in state" for all resources:
- ✅ This is OK! It means the resources were already removed or never imported
- Continue to Step 2 (terraform plan)

### If terraform plan fails with permission errors:
- Check that you removed ALL old roles from state
- Verify roles are configured with `path = "/interview/"`
- Verify `permissions_boundary` is set

### If terraform apply fails on role creation:
```
Error: creating IAM Role: AccessDenied
```

**Solution:** Verify the role configuration has:
```hcl
path = "/interview/"
permissions_boundary = "arn:aws:iam::ACCOUNT:policy/InterviewCandidatePolicy"
```

### If ECS service fails to update:
```
Error: IAM role arn:aws:iam::ACCOUNT:role/pdc-ecs-task-execution-role is invalid
```

**Solution:** The old task definition references the old role. This is fixed by:
1. Creating new task definitions (Terraform does this)
2. Updating ECS service to use new task definition (Terraform does this)

## Verification Checklist

After migration, verify:

- [ ] New roles exist at `/interview/` path
  ```powershell
  aws iam list-roles --path-prefix /interview/
  ```

- [ ] New roles have permissions boundary
  ```powershell
  aws iam get-role --role-name pdc-ecs-task-execution-role --query 'Role.PermissionsBoundary'
  ```

- [ ] ECS task definitions use new role ARNs
  ```powershell
  aws ecs describe-task-definition --task-definition pdc-app --query 'taskDefinition.[executionRoleArn,taskRoleArn]'
  ```

- [ ] ECS service is running with new task definition
  ```powershell
  aws ecs describe-services --cluster pdc-cluster --services pdc-app-service --query 'services[0].{TaskDefinition:taskDefinition,RunningCount:runningCount}'
  ```

## Summary

✅ **Before Migration:**
- Roles at `/` path (cannot manage)
- Terraform blocked by permissions
- Deployment fails

✅ **After Migration:**
- NEW roles at `/interview/` path (can fully manage)
- Terraform works perfectly
- Full deployment capability
- Old roles orphaned but harmless

**Result:** You can now deploy and manage your infrastructure without admin help!

