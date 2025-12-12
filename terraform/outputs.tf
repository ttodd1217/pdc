output "database_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "database_port" {
  description = "RDS database port"
  value       = aws_db_instance.main.port
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for Docker images"
  value       = aws_ecr_repository.app.repository_url
}

output "sftp_ec2_public_ip" {
  description = "Public IP address of SFTP EC2 instance"
  value       = try(aws_eip.sftp_server.public_ip, null)
}

output "sftp_ec2_endpoint" {
  description = "SFTP server endpoint for connections (IP:22)"
  value       = try("${aws_eip.sftp_server.public_ip}:22", null)
}

output "sftp_ec2_instance_id" {
  description = "EC2 instance ID for SFTP server"
  value       = try(aws_instance.sftp_server.id, null)
}

output "sftp_username" {
  description = "SFTP username for authentication"
  value       = "sftp_user"
}

output "sftp_ssh_key_name" {
  description = "Name of the EC2 key pair for SSH access"
  value       = var.sftp_key_name
}

output "sftp_connection_instructions" {
  description = "Instructions for connecting to SFTP server"
  value       = <<-EOF
    
    To connect via SSH to the EC2 instance:
      ssh -i pdc-sftp-server-key.pem ubuntu@${try(aws_eip.sftp_server.public_ip, "PENDING")}
    
    To connect via SFTP to upload files:
      sftp -i pdc-sftp-server-key.pem sftp_user@${try(aws_eip.sftp_server.public_ip, "PENDING")}
    
    Inside SFTP:
      sftp> put local_file.csv
      sftp> ls
      sftp> exit
  EOF
}

