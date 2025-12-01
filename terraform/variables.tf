variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "api_key" {
  description = "API key for authentication"
  type        = string
  sensitive   = true
}

variable "sftp_host" {
  description = "SFTP server hostname"
  type        = string
  default     = ""
}

variable "sftp_username" {
  description = "SFTP server username"
  type        = string
  default     = ""
}

