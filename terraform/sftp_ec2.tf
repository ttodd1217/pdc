# Security Group for SFTP EC2 Instance
resource "aws_security_group" "sftp_ec2" {
  name        = "pdc-sftp-ec2-sg"
  description = "Security group for PDC SFTP EC2 instance"
  vpc_id      = aws_vpc.main.id

  # Inbound SFTP (port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SFTP access from anywhere"
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pdc-sftp-ec2-sg"
  }
}

# EC2 Key Pair for SSH access to SFTP server
# NOTE: You must have already created this key in AWS or generated it locally
# Create key pair in AWS: aws ec2 create-key-pair --key-name pdc-sftp-server-key --query 'KeyMaterial' --output text > pdc-sftp-server-key.pem
# OR generate locally: ssh-keygen -t ed25519 -f pdc-sftp-server-key.pem -N "" -C "pdc-sftp-server"
# Then import: aws ec2 import-key-pair --key-name pdc-sftp-server-key --public-key-material file://pdc-sftp-server-key.pem.pub
#
# For now, we'll reference an existing key or create during first apply
variable "sftp_key_name" {
  description = "Name of EC2 key pair for SFTP server (must exist in AWS)"
  type        = string
  default     = "pdc-sftp-server-key"
}

# Data source for Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# User data script for SFTP setup
locals {
  sftp_user_data = <<-EOF
#!/bin/bash
set -e

# Update system packages
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y openssh-server openssh-client sudo curl wget

# Create SFTP user (vest)
if ! id "sftp_user" &>/dev/null; then
  useradd -m -d /home/sftp_user -s /bin/bash sftp_user
fi

# Create SFTP directories on local filesystem
mkdir -p /home/sftp_user/uploads
mkdir -p /home/sftp_user/processed
mkdir -p /home/sftp_user/.ssh
chmod 755 /home/sftp_user
chmod 755 /home/sftp_user/uploads
chmod 755 /home/sftp_user/processed
chmod 700 /home/sftp_user/.ssh

# Add the public key to authorized_keys for password-less authentication
cat > /home/sftp_user/.ssh/authorized_keys <<'KEYEOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIDjeHsMLuBEjmgnlTCD/Gn3SklCzxZ1eJedabojcg8X administrator@DESKTOP-4517OPL
KEYEOF
chmod 600 /home/sftp_user/.ssh/authorized_keys
chown sftp_user:sftp_user /home/sftp_user/.ssh/authorized_keys
chown -R sftp_user:sftp_user /home/sftp_user/.ssh

# Configure OpenSSH for SFTP-only access
if ! grep -q "Subsystem sftp" /etc/ssh/sshd_config; then
  cat >> /etc/ssh/sshd_config <<'SSHEOF'

# SFTP Configuration for PDC
Subsystem sftp /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO
Match User sftp_user
    AllowAgentForwarding no
    AllowTcpForwarding no
    PermitTTY no
    PermitUserRC no
    X11Forwarding no
    ForceCommand internal-sftp -d /home/sftp_user
SSHEOF
fi

# Restart SSH
systemctl restart ssh
systemctl enable ssh

echo "SFTP Server Setup Complete"
EOF
}

# EC2 Instance for SFTP Server
resource "aws_instance" "sftp_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public[0].id
  key_name      = aws_key_pair.sftp.key_name

  vpc_security_group_ids = [aws_security_group.sftp_ec2.id]

  # Explicit dependency to ensure key pair is fully propagated before instance creation
  depends_on = [aws_key_pair.sftp]

  # Enable public IP assignment
  associate_public_ip_address = true

  # User data for SFTP configuration
  user_data = base64encode(local.sftp_user_data)

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint           = "enabled"
    http_tokens             = "required"
    http_put_response_hop_limit = 1
  }

  monitoring = true

  tags = {
    Name = "pdc-sftp-server"
  }
}

# Elastic IP for stable SFTP server address
resource "aws_eip" "sftp_server" {
  instance = aws_instance.sftp_server.id
  domain   = "vpc"

  tags = {
    Name = "pdc-sftp-eip"
  }

  depends_on = [aws_instance.sftp_server]
}
