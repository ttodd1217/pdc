# Event-Driven Ingestion Infrastructure
# This file sets up S3 ObjectCreated events to trigger ECS ingestion tasks
# Architecture: S3 uploads/ → EventBridge → ECS Task

# S3 Bucket for SFTP file uploads (landing zone)
resource "aws_s3_bucket" "sftp_data" {
  bucket = "pdc-sftp-data-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "pdc-sftp-data"
  }
}

# Enable versioning for S3 bucket (optional but good practice)
resource "aws_s3_bucket_versioning" "sftp_data" {
  bucket = aws_s3_bucket.sftp_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# EventBridge Rule for S3 ObjectCreated events
# Triggers when files are uploaded to the uploads/ prefix
resource "aws_cloudwatch_event_rule" "s3_file_upload" {
  name        = "pdc-s3-sftp-file-upload"
  description = "Trigger file ingestion ECS task on S3 ObjectCreated in uploads/ prefix"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.sftp_data.id]
      }
      object = {
        key = [{
          prefix = "uploads/"
        }]
      }
    }
  })

  tags = {
    Name = "pdc-s3-file-upload-rule"
  }
}

# EventBridge Target: S3 event → ECS RunTask
# This target maps S3 ObjectCreated events to the ingestion ECS task
resource "aws_cloudwatch_event_target" "s3_upload_to_ecs" {
  rule      = aws_cloudwatch_event_rule.s3_file_upload.name
  target_id = "pdc-s3-ingestion-target"

  arn      = aws_ecs_cluster.main.arn
  role_arn = aws_iam_role.eventbridge_ecs.arn

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

  # Transform S3 event into a JSON payload for the container
  # Extracts bucket name and object key from the S3 event
  input_transformer {
    input_paths = {
      "bucket" = "$.detail.bucket.name"
      "key"    = "$.detail.object.key"
    }

    input_template = jsonencode({
      "s3_bucket" = "<bucket>"
      "s3_key"    = "<key>"
    })
  }
}

# Update EventBridge IAM role policy to include S3 permissions
# (The existing eventbridge_ecs role already has ECS permissions)
resource "aws_iam_role_policy" "eventbridge_s3_read" {
  name = "pdc-eventbridge-s3-read-policy"
  role = aws_iam_role.eventbridge_ecs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.sftp_data.arn}/uploads/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.sftp_data.arn
      }
    ]
  })
}

# Output the S3 bucket name for reference
output "sftp_data_bucket" {
  description = "S3 bucket for SFTP file uploads and event-driven ingestion"
  value       = aws_s3_bucket.sftp_data.id
}

output "sftp_data_bucket_uploads_path" {
  description = "S3 path where files should be uploaded to trigger ingestion"
  value       = "${aws_s3_bucket.sftp_data.id}/uploads/"
}
