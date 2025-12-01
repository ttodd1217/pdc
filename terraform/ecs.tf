# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "pdc-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.ecs_task.arn
  task_role_arn            = data.aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "pdc-app"
      image = "${aws_ecr_repository.app.repository_url}:latest"

      portMappings = [
        {
          containerPort = 5000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DATABASE_URL"
          value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.main.endpoint}:5432/pdc_db"
        },
        {
          name  = "API_KEY"
          value = var.api_key
        },
        {
          name  = "SFTP_HOST"
          value = var.sftp_host
        },
        {
          name  = "SFTP_USERNAME"
          value = var.sftp_username
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
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "python -c \"import requests; requests.get('http://localhost:5000/health')\""]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "pdc-app-task"
  }
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "pdc-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "pdc-app"
    container_port   = 5000
  }

  depends_on = [
    aws_lb_listener.app
  ]

  tags = {
    Name = "pdc-app-service"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/pdc-app"
  retention_in_days = 7

  tags = {
    Name = "pdc-app-logs"
  }
}

# Secrets Manager for sensitive data
resource "aws_secretsmanager_secret" "sftp_key" {
  name = "pdc/sftp-key"
  
  tags = {
    Name = "pdc-sftp-key"
  }
}

resource "aws_secretsmanager_secret" "alert_api_key" {
  name = "pdc/alert-api-key"
  
  tags = {
    Name = "pdc-alert-api-key"
  }
}




