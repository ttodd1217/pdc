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

locals {
  sftp_user_data = <<-EOF
#!/bin/bash
set -e

apt-get update -y
apt-get install -y openssh-server sudo

# Create SFTP-only user
if ! id "sftp_user" &>/dev/null; then
  useradd -m -d /home/sftp_user -s /usr/sbin/nologin sftp_user
fi

# Directories
mkdir -p /home/sftp_user/uploads
mkdir -p /home/sftp_user/processed
mkdir -p /home/sftp_user/.ssh

# Chroot requirements (CRITICAL)
chown root:root /home/sftp_user
chmod 755 /home/sftp_user
chown -R sftp_user:sftp_user /home/sftp_user/uploads
chown -R sftp_user:sftp_user /home/sftp_user/processed
chown -R sftp_user:sftp_user /home/sftp_user/.ssh
chmod 700 /home/sftp_user/.ssh

# Authorized SSH key
cat <<'KEYEOF' > /home/sftp_user/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRmkF13Mwt/iq+RecnzBgdRkkFYw7QJGOYAD24BfLNz administrator@DESKTOP-4517OPL
KEYEOF

chmod 600 /home/sftp_user/.ssh/authorized_keys
chown sftp_user:sftp_user /home/sftp_user/.ssh/authorized_keys

# Force internal-sftp safely
sed -i 's|^Subsystem sftp.*|Subsystem sftp internal-sftp|' /etc/ssh/sshd_config

# Remove any old Match blocks
sed -i '/^Match User sftp_user/,$d' /etc/ssh/sshd_config

# Append Match block LAST
cat <<'SSHEOF' >> /etc/ssh/sshd_config

# PDC SFTP-only user
Match User sftp_user
    ChrootDirectory /home/sftp_user
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
    PermitTTY no
SSHEOF

# Validate and restart SSH
sshd -t
systemctl restart ssh
systemctl enable ssh

echo "SFTP server ready"
EOF
}


# EC2 Instance for SFTP Server
resource "aws_instance" "sftp_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public[0].id
  key_name      = aws_key_pair.sftp.key_name

  vpc_security_group_ids = [aws_security_group.sftp_ec2.id]
  associate_public_ip_address = true
  user_data = base64encode(local.sftp_user_data)

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

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
