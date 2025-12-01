# SFTP Setup Guide

This guide covers setting up SFTP for the Portfolio Data Clearinghouse, including server setup, SSH key configuration, and application integration.

## Overview

The PDC application needs to:
1. Connect to an SFTP server using SSH key authentication
2. Download trade files from a remote directory
3. Move processed files to a processed directory

## Option 1: Using an Existing SFTP Server

If you already have an SFTP server, you just need to configure access.

### 1.1 Add SSH Public Key to Server

The project uses the provided SSH public key. Add it to your SFTP server:

**Public Key** (from requirements):
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINBiRG5vqvdhVxb1wmqnWf9YXVVp4l3qDdBJ8eNGoxWj
```

**On the SFTP server**, add this key to the authorized_keys file:

```bash
# On SFTP server
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINBiRG5vqvdhVxb1wmqnWf9YXVVp4l3qDdBJ8eNGoxWj" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 1.2 Create Directory Structure

```bash
# On SFTP server
mkdir -p /uploads        # Where files are dropped
mkdir -p /processed      # Where processed files are moved
chmod 755 /uploads
chmod 755 /processed
```

### 1.3 Configure Application

Update your `.env` file or environment variables:

```bash
SFTP_HOST=your-sftp-server.com
SFTP_PORT=22
SFTP_USERNAME=your-username
SFTP_KEY_PATH=~/.ssh/id_ed25519
SFTP_REMOTE_PATH=/uploads
SFTP_PROCESSED_PATH=/processed
```

## Option 2: Setting Up a New SFTP Server on Linux

### 2.1 Install OpenSSH Server

**Ubuntu/Debian**:
```bash
sudo apt-get update
sudo apt-get install openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
```

**CentOS/RHEL**:
```bash
sudo yum install openssh-server
sudo systemctl enable sshd
sudo systemctl start sshd
```

### 2.2 Configure SSH for SFTP

Edit `/etc/ssh/sshd_config`:

```bash
sudo nano /etc/ssh/sshd_config
```

Ensure these settings:
```
Port 22
PermitRootLogin no
PasswordAuthentication no          # Use key-based auth only
PubkeyAuthentication yes
Subsystem sftp /usr/lib/openssh/sftp-server
```

Restart SSH service:
```bash
sudo systemctl restart ssh
```

### 2.3 Create SFTP User

```bash
# Create user
sudo useradd -m -s /bin/bash sftp_user

# Create directory structure
sudo mkdir -p /home/sftp_user/uploads
sudo mkdir -p /home/sftp_user/processed
sudo chown sftp_user:sftp_user /home/sftp_user/uploads
sudo chown sftp_user:sftp_user /home/sftp_user/processed
sudo chmod 755 /home/sftp_user/uploads
sudo chmod 755 /home/sftp_user/processed
```

### 2.4 Add SSH Public Key

```bash
# Switch to sftp_user
sudo su - sftp_user

# Create .ssh directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add public key
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINBiRG5vqvdhVxb1wmqnWf9YXVVp4l3qDdBJ8eNGoxWj" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Exit
exit
```

### 2.5 Test SFTP Connection

From your local machine or application server:

```bash
# Test SSH connection
ssh -i ~/.ssh/id_ed25519 sftp_user@your-server-ip

# Test SFTP connection
sftp -i ~/.ssh/id_ed25519 sftp_user@your-server-ip
```

## Option 3: Using AWS Transfer Family (Managed SFTP)

AWS Transfer Family provides a managed SFTP service.

### 3.1 Create AWS Transfer Family Server

```bash
# Create IAM role for Transfer Family
aws iam create-role \
    --role-name TransferFamilyServiceRole \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "transfer.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'

# Create S3 bucket for SFTP files
aws s3 mb s3://pdc-sftp-files --region us-east-2

# Create Transfer Family server
aws transfer create-server \
    --protocols SFTP \
    --identity-provider-type SERVICE_MANAGED \
    --region us-east-2
```

Note the `ServerId` from the output.

### 3.2 Create SFTP User

```bash
# Create SSH key pair (if you don't have the private key)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Get public key
PUBLIC_KEY=$(cat ~/.ssh/id_ed25519.pub)

# Create user
aws transfer create-user \
    --server-id YOUR_SERVER_ID \
    --user-name sftp_user \
    --role "arn:aws:iam::ACCOUNT_ID:role/TransferFamilyServiceRole" \
    --home-directory "/pdc-sftp-files" \
    --ssh-public-key-body "$PUBLIC_KEY"
```

### 3.3 Configure Application

```bash
SFTP_HOST=YOUR_SERVER_ID.server.transfer.us-east-2.amazonaws.com
SFTP_PORT=22
SFTP_USERNAME=sftp_user
SFTP_KEY_PATH=~/.ssh/id_ed25519
SFTP_REMOTE_PATH=/uploads
SFTP_PROCESSED_PATH=/processed
```

## Option 4: Using Docker for Local Testing

For local development and testing, you can run an SFTP server in Docker.

### 4.1 Create Docker SFTP Server

Create `docker-compose.sftp.yml`:

```yaml
version: '3.8'

services:
  sftp:
    image: atmoz/sftp:latest
    container_name: pdc-sftp
    ports:
      - "${SFTP_HOST_PORT:-3022}:22"
    volumes:
      - ./sftp-data:/home/sftp_user/uploads
      - ./sftp-processed:/home/sftp_user/processed
    command: sftp_user:password:1001:1001:uploads,processed
    environment:
      - SFTP_USERS=sftp_user:password:1001:1001:uploads,processed
```

### 4.2 Generate SSH Key Pair

```bash
# Generate key pair
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Copy public key to SFTP server
docker exec -it pdc-sftp sh -c "mkdir -p /home/sftp_user/.ssh && echo '$(cat ~/.ssh/id_ed25519.pub)' > /home/sftp_user/.ssh/authorized_keys && chmod 600 /home/sftp_user/.ssh/authorized_keys && chown sftp_user:sftp_user /home/sftp_user/.ssh/authorized_keys"
```

### 4.3 Start SFTP Server

```bash
docker-compose -f docker-compose.sftp.yml up -d
```

### 4.4 Configure Application

```bash
SFTP_HOST=localhost
SFTP_HOST_PORT=3022
SFTP_PORT=22
SFTP_USERNAME=sftp_user
SFTP_KEY_PATH=~/.ssh/id_ed25519
SFTP_REMOTE_PATH=/uploads
SFTP_PROCESSED_PATH=/processed
```

## Generating SSH Key Pair

If you need to generate a new SSH key pair:

```bash
# Generate Ed25519 key (recommended)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "pdc-app"

# Or generate RSA key (if Ed25519 not supported)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -C "pdc-app"

# View public key (to add to server)
cat ~/.ssh/id_ed25519.pub
```

**Important**: Keep the private key (`id_ed25519`) secure and never commit it to version control!

## Testing SFTP Connection

### Test from Command Line

```bash
# Test SSH connection
ssh -i ~/.ssh/id_ed25519 -p 22 sftp_user@your-sftp-host

# Test SFTP connection
sftp -i ~/.ssh/id_ed25519 -P 22 sftp_user@your-sftp-host

# Once connected, test commands:
sftp> ls
sftp> pwd
sftp> exit
```

### Test from Python

Create a test script `test_sftp.py`:

```python
from app.services.sftp_service import SFTPService
from app.config import Config

# Test connection
service = SFTPService()
try:
    files = service.list_files()
    print(f"✅ Connection successful! Found {len(files)} files")
    for f in files:
        print(f"  - {f}")
except Exception as e:
    print(f"❌ Connection failed: {str(e)}")
```

Run it:
```bash
python test_sftp.py
```

## Application Configuration

### Environment Variables

Set these in your `.env` file or deployment configuration:

```bash
# SFTP Configuration
SFTP_HOST=your-sftp-server.com          # SFTP server hostname or IP
SFTP_PORT=22                            # SFTP port (usually 22)
SFTP_USERNAME=sftp_user                 # SFTP username
SFTP_KEY_PATH=~/.ssh/id_ed25519         # Path to private SSH key
SFTP_REMOTE_PATH=/uploads               # Remote directory for incoming files
SFTP_PROCESSED_PATH=/processed          # Remote directory for processed files
```

### For AWS Deployment

Store the SSH private key in AWS Secrets Manager:

```bash
# Store private key
aws secretsmanager create-secret \
    --name pdc/sftp-key \
    --secret-string file://~/.ssh/id_ed25519 \
    --region us-east-2
```

The Terraform configuration automatically retrieves this secret for the ECS task.

### For Local Development

1. Place your private key at `~/.ssh/id_ed25519`
2. Set permissions: `chmod 600 ~/.ssh/id_ed25519`
3. Update `.env` with SFTP configuration

## File Upload Testing

### Upload Test Files

```bash
# Using SFTP command
sftp -i ~/.ssh/id_ed25519 sftp_user@your-sftp-host
sftp> put data/example_format1.csv /uploads/
sftp> put data/example_format2.txt /uploads/
sftp> exit

# Or using SCP
scp -i ~/.ssh/id_ed25519 data/example_format1.csv sftp_user@your-sftp-host:/uploads/
```

### Trigger Ingestion

```bash
# Run ingestion script
python scripts/ingest_files.py
```

The script will:
1. Connect to SFTP server
2. List files in `/uploads`
3. Download each file
4. Ingest into database
5. Move file to `/processed`

## Troubleshooting

### Issue: Connection Refused

**Check**:
- SFTP server is running: `sudo systemctl status ssh`
- Firewall allows port 22: `sudo ufw allow 22`
- Correct hostname/IP address
- Correct port number

### Issue: Permission Denied

**Check**:
- SSH public key is in `~/.ssh/authorized_keys` on server
- Correct permissions: `chmod 600 ~/.ssh/authorized_keys`
- Correct username
- Private key path is correct
- Private key permissions: `chmod 600 ~/.ssh/id_ed25519`

### Issue: Directory Not Found

**Check**:
- Directories exist on SFTP server
- User has permissions to access directories
- Correct path in configuration (absolute paths recommended)

### Issue: Key Format Error

**Check**:
- Key is Ed25519 or RSA format
- Private key is not corrupted
- Try regenerating key pair

### Debug SFTP Connection

Enable verbose logging:

```python
import logging
logging.basicConfig(level=logging.DEBUG)

from app.services.sftp_service import SFTPService
service = SFTPService()
files = service.list_files()
```

## Security Best Practices

1. **Use Key-Based Authentication**: Disable password authentication
2. **Restrict SSH Access**: Use firewall rules to limit access
3. **Use Strong Keys**: Ed25519 or RSA 4096-bit minimum
4. **Rotate Keys Regularly**: Update keys periodically
5. **Limit User Permissions**: SFTP user should only access necessary directories
6. **Use Non-Standard Ports**: Consider changing from port 22 (optional)
7. **Monitor Access**: Enable SSH logging and monitor access

## Next Steps

After SFTP is configured:

1. Test connection using the test script
2. Upload sample files to test ingestion
3. Verify files are moved to processed directory
4. Check application logs for any errors
5. Set up scheduled ingestion (EventBridge/ECS scheduled tasks)

## Quick Reference

```bash
# Test SFTP connection
sftp -i ~/.ssh/id_ed25519 sftp_user@host

# Upload file
scp -i ~/.ssh/id_ed25519 file.csv sftp_user@host:/uploads/

# List files on server
sftp -i ~/.ssh/id_ed25519 sftp_user@host
sftp> ls /uploads

# Run ingestion
python scripts/ingest_files.py
```

