#!/bin/bash
# Deployment Diagnostic Script

AWS_REGION="us-east-2"
CLUSTER="pdc-cluster"
SERVICE="pdc-app-service"

echo "=========================================="
echo "  ECS Deployment Diagnostics"
echo "=========================================="
echo ""

# 1. Check ECS Service Status
echo "[1/6] Checking ECS Service Status..."
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region $AWS_REGION \
  --query 'services[0].{DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount,Status:status}' \
  --output table

# 2. Check Task Status
echo ""
echo "[2/6] Checking ECS Tasks..."
TASK_ARNS=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --region $AWS_REGION --query 'taskArns[]' --output text)

if [ -z "$TASK_ARNS" ]; then
  echo "⚠️  No tasks found!"
else
  echo "Found $(echo $TASK_ARNS | wc -w) tasks"
  
  for TASK_ARN in $TASK_ARNS; do
    echo ""
    echo "Task: $(basename $TASK_ARN)"
    aws ecs describe-tasks \
      --cluster $CLUSTER \
      --tasks $TASK_ARN \
      --region $AWS_REGION \
      --query 'tasks[0].{LastStatus:lastStatus,HealthStatus:healthStatus,StoppedReason:stoppedReason}' \
      --output table
  done
fi

# 3. Check Task Definition
echo ""
echo "[3/6] Checking Task Definition..."
TASK_DEF=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $AWS_REGION --query 'services[0].taskDefinition' --output text)
echo "Current task definition: $TASK_DEF"

aws ecs describe-task-definition \
  --task-definition $TASK_DEF \
  --region $AWS_REGION \
  --query 'taskDefinition.{ExecutionRole:executionRoleArn,TaskRole:taskRoleArn}' \
  --output table

# 4. Check for Stopped Tasks (last 10)
echo ""
echo "[4/6] Checking Recent Stopped Tasks..."
STOPPED_TASKS=$(aws ecs list-tasks --cluster $CLUSTER --desired-status STOPPED --region $AWS_REGION --query 'taskArns[0:3]' --output text)

if [ ! -z "$STOPPED_TASKS" ]; then
  for TASK_ARN in $STOPPED_TASKS; do
    echo ""
    echo "Stopped Task: $(basename $TASK_ARN)"
    aws ecs describe-tasks \
      --cluster $CLUSTER \
      --tasks $TASK_ARN \
      --region $AWS_REGION \
      --query 'tasks[0].{StoppedReason:stoppedReason,StopCode:stopCode,Containers:containers[0].{Name:name,Reason:reason,ExitCode:exitCode}}' \
      --output json
  done
fi

# 5. Check CloudWatch Logs
echo ""
echo "[5/6] Checking Recent CloudWatch Logs..."
LOG_GROUP="/ecs/pdc-app"
echo "Log group: $LOG_GROUP"

# Get latest log stream
LATEST_STREAM=$(aws logs describe-log-streams \
  --log-group-name $LOG_GROUP \
  --region $AWS_REGION \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --query 'logStreams[0].logStreamName' \
  --output text)

if [ "$LATEST_STREAM" != "None" ]; then
  echo "Latest log stream: $LATEST_STREAM"
  echo ""
  echo "Last 20 log entries:"
  aws logs get-log-events \
    --log-group-name $LOG_GROUP \
    --log-stream-name $LATEST_STREAM \
    --region $AWS_REGION \
    --limit 20 \
    --query 'events[*].message' \
    --output text
else
  echo "⚠️  No log streams found"
fi

# 6. Check ALB Target Health
echo ""
echo "[6/6] Checking ALB Target Health..."
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
  --region $AWS_REGION \
  --names pdc-app-tg-fargate \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text 2>/dev/null)

if [ "$TARGET_GROUP_ARN" != "None" ]; then
  aws elbv2 describe-target-health \
    --target-group-arn $TARGET_GROUP_ARN \
    --region $AWS_REGION \
    --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
    --output table
else
  echo "⚠️  Target group not found"
fi

echo ""
echo "=========================================="
echo "  Diagnostics Complete"
echo "=========================================="

