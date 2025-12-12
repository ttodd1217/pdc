# EventBridge Rule for Scheduled Ingestion
resource "aws_cloudwatch_event_rule" "ingestion_schedule" {
  name                = "pdc-ingestion-schedule"
  description         = "Trigger file ingestion every hour"
  schedule_expression = "rate(1 hour)"

  tags = {
    Name = "pdc-ingestion-schedule"
  }
}

# IAM Role for EventBridge to invoke ECS Task
# This creates a NEW role at /interview/ path with permissions boundary
# Note: Old role at "/" path will remain orphaned in AWS but unused
resource "aws_iam_role" "eventbridge_ecs" {
  name                 = "pdc-eventbridge-ecs-role-v2"
  path                 = "/interview/"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/InterviewCandidatePolicy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_iam_role_policy" "eventbridge_ecs" {
  name = "pdc-eventbridge-ecs-policy"
  role = aws_iam_role.eventbridge_ecs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = aws_ecs_task_definition.ingestion.arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })

}

# ECS Task Definition for Ingestion
resource "aws_ecs_task_definition" "ingestion" {
  family                   = "pdc-ingestion"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "pdc-ingestion"
      image = "${aws_ecr_repository.app.repository_url}:latest"

      command = ["python", "scripts/ingest_files.py"]

      environment = [
        {
          name  = "DATABASE_URL"
          value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.main.endpoint}/pdc_db"
        },
        {
          name  = "SFTP_HOST"
          value = var.sftp_host
        },
        {
          name  = "SFTP_USERNAME"
          value = var.sftp_username
        },
        {
          name  = "INGEST_EVENT"
          value = ""
        }
      ]

      secrets = [
        {
          name      = "SFTP_KEY"
          valueFrom = aws_secretsmanager_secret.sftp_key.arn
        },
        {
          name      = "ALERT_API_KEY"
          valueFrom = aws_secretsmanager_secret.alert_api_key.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ingestion.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "pdc-ingestion-task"
  }
}

# CloudWatch Log Group for Ingestion
resource "aws_cloudwatch_log_group" "ingestion" {
  name              = "/ecs/pdc-ingestion-v2"
  retention_in_days = 7

  tags = {
    Name = "pdc-ingestion-logs"
  }
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "ingestion" {
  rule      = aws_cloudwatch_event_rule.ingestion_schedule.name
  target_id = "pdc-ingestion-target"
  arn       = aws_ecs_cluster.main.arn
  role_arn  = aws_iam_role.eventbridge_ecs.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.ingestion.arn
    launch_type         = "FARGATE"
    platform_version    = "LATEST"

    network_configuration {
      subnets          = aws_subnet.public[*].id
      security_groups  = [aws_security_group.app.id]
      assign_public_ip = true
    }
  }
}




