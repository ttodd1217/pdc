# Deployment Diagnostic Script for Windows

$AWS_REGION = "us-east-2"
$CLUSTER = "pdc-cluster"
$SERVICE = "pdc-app-service"

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  ECS Deployment Diagnostics" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check ECS Service Status
Write-Host "[1/6] Checking ECS Service Status..." -ForegroundColor Yellow
aws ecs describe-services `
  --cluster $CLUSTER `
  --services $SERVICE `
  --region $AWS_REGION `
  --query 'services[0].{DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount,Status:status}' `
  --output table

# 2. Check Task Status
Write-Host "`n[2/6] Checking ECS Tasks..." -ForegroundColor Yellow
$TASK_ARNS = aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --region $AWS_REGION --query 'taskArns[]' --output text

if ([string]::IsNullOrWhiteSpace($TASK_ARNS)) {
  Write-Host "⚠️  No tasks found!" -ForegroundColor Red
} else {
  $TaskCount = ($TASK_ARNS -split '\s+').Count
  Write-Host "Found $TaskCount tasks" -ForegroundColor Green
  
  foreach ($TASK_ARN in ($TASK_ARNS -split '\s+')) {
    Write-Host "`nTask: $([System.IO.Path]::GetFileName($TASK_ARN))" -ForegroundColor Cyan
    aws ecs describe-tasks `
      --cluster $CLUSTER `
      --tasks $TASK_ARN `
      --region $AWS_REGION `
      --query 'tasks[0].{LastStatus:lastStatus,HealthStatus:healthStatus,StoppedReason:stoppedReason}' `
      --output table
  }
}

# 3. Check Task Definition
Write-Host "`n[3/6] Checking Task Definition..." -ForegroundColor Yellow
$TASK_DEF = aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $AWS_REGION --query 'services[0].taskDefinition' --output text
Write-Host "Current task definition: $TASK_DEF" -ForegroundColor Gray

aws ecs describe-task-definition `
  --task-definition $TASK_DEF `
  --region $AWS_REGION `
  --query 'taskDefinition.{ExecutionRole:executionRoleArn,TaskRole:taskRoleArn}' `
  --output table

# 4. Check for Stopped Tasks
Write-Host "`n[4/6] Checking Recent Stopped Tasks..." -ForegroundColor Yellow
$STOPPED_TASKS = aws ecs list-tasks --cluster $CLUSTER --desired-status STOPPED --region $AWS_REGION --query 'taskArns[0:3]' --output text

if (![string]::IsNullOrWhiteSpace($STOPPED_TASKS)) {
  foreach ($TASK_ARN in ($STOPPED_TASKS -split '\s+')) {
    Write-Host "`nStopped Task: $([System.IO.Path]::GetFileName($TASK_ARN))" -ForegroundColor Cyan
    aws ecs describe-tasks `
      --cluster $CLUSTER `
      --tasks $TASK_ARN `
      --region $AWS_REGION `
      --query 'tasks[0].{StoppedReason:stoppedReason,StopCode:stopCode,Containers:containers[0].{Name:name,Reason:reason,ExitCode:exitCode}}' `
      --output json | ConvertFrom-Json | ConvertTo-Json -Depth 5
  }
} else {
  Write-Host "No stopped tasks found" -ForegroundColor Gray
}

# 5. Check CloudWatch Logs
Write-Host "`n[5/6] Checking Recent CloudWatch Logs..." -ForegroundColor Yellow
$LOG_GROUP = "/ecs/pdc-app"
Write-Host "Log group: $LOG_GROUP" -ForegroundColor Gray

$LATEST_STREAM = aws logs describe-log-streams `
  --log-group-name $LOG_GROUP `
  --region $AWS_REGION `
  --order-by LastEventTime `
  --descending `
  --max-items 1 `
  --query 'logStreams[0].logStreamName' `
  --output text

if ($LATEST_STREAM -and $LATEST_STREAM -ne "None") {
  Write-Host "Latest log stream: $LATEST_STREAM" -ForegroundColor Gray
  Write-Host "`nLast 20 log entries:" -ForegroundColor Gray
  aws logs get-log-events `
    --log-group-name $LOG_GROUP `
    --log-stream-name $LATEST_STREAM `
    --region $AWS_REGION `
    --limit 20 `
    --query 'events[*].message' `
    --output text
} else {
  Write-Host "⚠️  No log streams found" -ForegroundColor Red
}

# 6. Check ALB Target Health
Write-Host "`n[6/6] Checking ALB Target Health..." -ForegroundColor Yellow
$TARGET_GROUP_ARN = aws elbv2 describe-target-groups `
  --region $AWS_REGION `
  --names pdc-app-tg-fargate `
  --query 'TargetGroups[0].TargetGroupArn' `
  --output text 2>$null

if ($TARGET_GROUP_ARN -and $TARGET_GROUP_ARN -ne "None") {
  aws elbv2 describe-target-health `
    --target-group-arn $TARGET_GROUP_ARN `
    --region $AWS_REGION `
    --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' `
    --output table
} else {
  Write-Host "⚠️  Target group not found" -ForegroundColor Red
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  Diagnostics Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Check the logs above for errors" -ForegroundColor Gray
Write-Host "2. If tasks are stopped, check the StoppedReason" -ForegroundColor Gray
Write-Host "3. Verify IAM roles have correct permissions" -ForegroundColor Gray
Write-Host "4. Check if container image exists in ECR" -ForegroundColor Gray

