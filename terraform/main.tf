terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
  
  # Commented out for local testing - uncomment after S3 bucket is created
  # backend "s3" {
  #   bucket = "pdc-terraform-state"
  #   key    = "pdc/terraform.tfstate"
  #   region = "us-east-2"
  # }
}

provider "aws" {
  region = var.aws_region
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# VPC and Networking
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "pdc-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "pdc-igw"
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "pdc-public-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "pdc-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "app" {
  name        = "pdc-app-sg"
  description = "Security group for PDC application"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow ALB to reach Flask app on port 5000"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pdc-app-sg"
  }
}

resource "aws_security_group" "db" {
  name        = "pdc-db-sg"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pdc-db-sg"
  }
}

# RDS Database
resource "aws_db_subnet_group" "main" {
  name       = "pdc-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name = "pdc-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier             = "pdc-db"
  engine                 = "postgres"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = "pdc_db"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = true
  skip_final_snapshot    = true

  tags = {
    Name = "pdc-db"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "pdc-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "pdc-cluster"
  }
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = "pdc-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "pdc-app-ecr"
  }
}

# IAM Role for ECS Task (Execution Role)
# This creates a NEW role at /interview/ path with permissions boundary
# Note: Old role at "/" path will remain orphaned in AWS but unused
resource "aws_iam_role" "ecs_task_execution_role" {
  name                 = "pdc-ecs-task-execution-role-v2"
  path                 = "/interview/"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/InterviewCandidatePolicy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}


# Attach the standard ECS Task Execution Role policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow ECS Task to access Secrets Manager
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "pdc-ecs-task-execution-secrets"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.sftp_key.arn,
          aws_secretsmanager_secret.alert_api_key.arn
        ]
      }
    ]
  })

}

# IAM Role for ECS Task (Task Role - for app permissions)
# This creates a NEW role at /interview/ path with permissions boundary
# Note: Old role at "/" path will remain orphaned in AWS but unused
resource "aws_iam_role" "ecs_task_role" {
  name                 = "pdc-ecs-task-app-role-v2"
  path                 = "/interview/"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/InterviewCandidatePolicy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}


# Allow ECS Task to access S3, CloudWatch, etc.
resource "aws_iam_role_policy" "ecs_task_permissions" {
  name = "pdc-ecs-task-permissions"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.app.arn}:*"
      }
    ]
  })

}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "pdc-alb-v2"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "pdc-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "pdc-app-tg-fargate-v2"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  # Deregistration delay to drain connections gracefully
  deregistration_delay = 30

  tags = {
    Name = "pdc-app-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

