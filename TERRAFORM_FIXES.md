# Terraform Error Fixes

## Issues Fixed

### Issue 1: IAM Permission Denied on DeleteRole ❌ → ✅

**Error:**
```
Error: deleting IAM Role (pdc-ecs-task-role): operation error IAM: DeleteRole
api error AccessDenied: User is not authorized to perform: iam:DeleteRole
```

**Root Cause:**
- Used `data "aws_iam_role" "ecs_task"` which only references an existing role
- When Terraform detected any changes, it attempted to delete and recreate the role
- Your IAM user lacked `iam:DeleteRole` permission

**Fix:**
- Changed from `data` source to managed `resource` in `main.tf`
- Created two separate IAM roles:
  - `aws_iam_role.ecs_task_execution_role` - For ECS to pull images, write logs, access Secrets Manager
  - `aws_iam_role.ecs_task_role` - For the application's runtime permissions
- Terraform now manages these roles, avoiding permission issues

**Files Modified:**
- `terraform/main.tf` - Added IAM role resources with proper policies
- `terraform/ecs.tf` - Updated references to use managed resources
- `terraform/scheduled_task.tf` - Updated references to use managed resources

---

### Issue 2: Target Group Type Mismatch ❌ → ✅

**Error:**
```
Error: The provided target group has target type instance, which is incompatible 
with the awsvpc network mode specified in the task definition.
```

**Root Cause:**
- `aws_lb_target_group.app` did not specify `target_type`
- Defaults to `instance` (EC2 instances)
- But the task definition uses `network_mode = "awsvpc"` with Fargate
- Fargate requires `target_type = "ip"`

**Fix:**
- Added `target_type = "ip"` to `aws_lb_target_group` resource in `main.tf`

**Files Modified:**
- `terraform/main.tf` - Added `target_type = "ip"` to load balancer target group

---

## Changed Configuration Details

### New IAM Role Structure

```hcl
# Execution Role (ECS system permissions)
resource "aws_iam_role" "ecs_task_execution_role" {
  # Allows ECS to pull images, write logs, access secrets
  # Has AmazonECSTaskExecutionRolePolicy attached
}

# Task Role (Application permissions)
resource "aws_iam_role" "ecs_task_role" {
  # Allows the app to write CloudWatch logs
  # Can be extended with S3, SNS, etc. as needed
}
```

### Updated Target Group

```hcl
resource "aws_lb_target_group" "app" {
  name        = "pdc-app-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"  # ← ADDED: Required for Fargate + awsvpc
  
  # ... health check config ...
}
```

---

## Next Steps

1. **Backup your Terraform state** (if not already in S3):
   ```bash
   terraform state pull > backup.tfstate
   ```

2. **Plan the changes** to review them:
   ```bash
   terraform plan
   ```

3. **Apply the changes**:
   ```bash
   terraform apply -auto-approve tfplan
   ```

4. **Destroy old resources** (optional cleanup):
   - If the old `pdc-ecs-task-role` still exists in AWS and is no longer needed
   - AWS console → IAM → Roles → Delete `pdc-ecs-task-role`

---

## Additional Recommendations

### For Production:

1. **Restrict IAM Policies Further**
   - The current `ecs_task_role` policy is minimal and safe
   - Extend it only as your application needs additional AWS services

2. **Use Secrets Manager for All Sensitive Data**
   - Current setup already supports SFTP key and alert API key
   - Consider adding database credentials too

3. **Enable CloudTrail Logging**
   - Monitor who's making changes to Terraform-managed resources

4. **Set Up State Locking**
   - Ensure S3 state file has DynamoDB locking configured
   - Prevents concurrent modifications

5. **IAM User Permissions**
   - For normal Terraform operations, your IAM user should have:
     - `ec2:*` (VPC, subnets, security groups)
     - `ecs:*` (cluster, services, task definitions)
     - `iam:GetRole`, `iam:CreateRole`, `iam:DeleteRole` (role management)
     - `rds:*` (database)
     - `elasticloadbalancing:*` (load balancer)
     - `ecr:*` (container registry)
     - `logs:*` (CloudWatch logs)
     - `secretsmanager:*` (secrets)
     - (Preferably via AWS managed policy or custom restrictive policy)

---

## Verification Commands

After applying the changes:

```bash
# Verify ECS cluster is running
aws ecs list-clusters --region us-east-2

# Verify task definitions
aws ecs list-task-definitions --region us-east-2

# Verify IAM roles were created
aws iam get-role --role-name pdc-ecs-task-execution-role
aws iam get-role --role-name pdc-ecs-task-role

# Describe the service
aws ecs describe-services --cluster pdc-cluster --services pdc-app-service --region us-east-2
```
