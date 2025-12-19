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

# Logging setup
exec > >(tee -a /var/log/user-data.log)
exec 2>&1
echo "Starting user-data script at $(date)"

# Update system
apt-get update -y
apt-get install -y openssh-server sudo python3 python3-pip python3-venv git postgresql-client

echo "✓ System packages installed"

# Create SFTP-only user
if ! id "sftp_user" &>/dev/null; then
  useradd -m -d /home/sftp_user -s /usr/sbin/nologin sftp_user
fi

# Create ingestion worker user (can run scripts)
if ! id "ingest_worker" &>/dev/null; then
  useradd -m -d /home/ingest_worker -s /bin/bash ingest_worker
fi

# Directories
mkdir -p /home/sftp_user/uploads
mkdir -p /home/sftp_user/processed
mkdir -p /home/sftp_user/.ssh

# Chroot requirements (CRITICAL for sftp_user)
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

echo "✓ SFTP users and directories created"

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

echo "✓ SSH/SFTP configured"

# Clone or copy project (using git, or you can use S3/artifact repo)
PROJECT_DIR="/opt/pdc"
mkdir -p $PROJECT_DIR

# For now, create a minimal project structure
# In production, use: git clone <repo> $PROJECT_DIR
cd $PROJECT_DIR

# Create minimal app structure if not already there
if [ ! -d "$PROJECT_DIR/app" ]; then
  echo "Creating minimal project structure..."
  mkdir -p app/services
  mkdir -p scripts
  mkdir -p logs
fi

echo "✓ Project directory created"

# Setup Python virtual environment
python3 -m venv /opt/pdc/venv
source /opt/pdc/venv/bin/activate

# Install Python dependencies
pip install --upgrade pip setuptools wheel
pip install Flask SQLAlchemy psycopg2-binary python-dotenv paramiko boto3 python-dateutil requests

echo "✓ Python environment created and dependencies installed"

# Create the local file ingestion script (standalone, doesn't require full app)
cat > $PROJECT_DIR/scripts/ingest_local_files.py <<'PYEOF'
#!/usr/bin/env python3
"""
Local file ingestion script for EC2.
Processes files directly from /home/sftp_user/uploads
"""
import os
import sys
import csv
import io
import logging
from datetime import datetime
import psycopg2
from pathlib import Path

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/pdc-ingest.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

UPLOADS_DIR = "/home/sftp_user/uploads"
PROCESSED_DIR = "/home/sftp_user/processed"

def get_db_connection():
    """Create database connection"""
    try:
        conn = psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            database=os.getenv('DB_NAME', 'pdc_db'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD', ''),
            port=os.getenv('DB_PORT', '5432')
        )
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        raise

def parse_csv_file(file_path):
    """Parse CSV file and return trades"""
    trades = []
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                try:
                    trade_date = datetime.strptime(row['TradeDate'], '%Y-%m-%d').date()
                    settlement_date = None
                    if row.get('SettlementDate'):
                        settlement_date = datetime.strptime(row['SettlementDate'], '%Y-%m-%d').date()
                    
                    quantity = int(row['Quantity'])
                    price = float(row['Price'])
                    market_value = quantity * price
                    
                    # Handle SELL trades
                    if row.get('TradeType', '').upper() == 'SELL':
                        quantity = -abs(quantity)
                        market_value = -abs(market_value)
                    
                    trade = {
                        'trade_date': trade_date,
                        'account_id': row['AccountID'],
                        'ticker': row['Ticker'],
                        'quantity': quantity,
                        'price': price,
                        'market_value': market_value,
                        'trade_type': row.get('TradeType', 'BUY'),
                        'settlement_date': settlement_date
                    }
                    trades.append(trade)
                except Exception as e:
                    logger.error(f"Error parsing row {row}: {e}")
                    continue
        
        logger.info(f"Parsed {len(trades)} trades from {os.path.basename(file_path)}")
        return trades
    except Exception as e:
        logger.error(f"Error reading file {file_path}: {e}")
        return []

def save_trades_to_db(conn, trades):
    """Save trades to database"""
    if not trades:
        return 0
    
    try:
        cursor = conn.cursor()
        insert_query = """
            INSERT INTO trade (trade_date, account_id, ticker, quantity, price, market_value, trade_type, settlement_date)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        for trade in trades:
            cursor.execute(insert_query, (
                trade['trade_date'],
                trade['account_id'],
                trade['ticker'],
                trade['quantity'],
                trade['price'],
                trade['market_value'],
                trade['trade_type'],
                trade['settlement_date']
            ))
        
        conn.commit()
        cursor.close()
        logger.info(f"Saved {len(trades)} trades to database")
        return len(trades)
    except Exception as e:
        conn.rollback()
        logger.error(f"Error saving trades: {e}")
        raise

def process_file(file_path):
    """Process a single file"""
    filename = os.path.basename(file_path)
    logger.info(f"Processing {filename}...")
    
    try:
        trades = parse_csv_file(file_path)
        
        if trades:
            conn = get_db_connection()
            count = save_trades_to_db(conn, trades)
            conn.close()
            logger.info(f"Successfully processed {filename}: {count} trades")
        else:
            logger.warning(f"No trades found in {filename}")
        
        # Move to processed directory
        processed_path = os.path.join(PROCESSED_DIR, filename)
        os.makedirs(PROCESSED_DIR, exist_ok=True)
        os.rename(file_path, processed_path)
        logger.info(f"Moved {filename} to processed directory")
        
        return True
    except Exception as e:
        logger.error(f"Error processing {filename}: {e}")
        return False

def main():
    """Process all files in uploads directory"""
    logger.info("Starting file ingestion...")
    
    # Create uploads directory if it doesn't exist
    os.makedirs(UPLOADS_DIR, exist_ok=True)
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    
    # List files
    try:
        files = [f for f in os.listdir(UPLOADS_DIR) if f.endswith(('.csv', '.txt', '.psv'))]
        logger.info(f"Found {len(files)} files to process")
        
        if not files:
            logger.info("No files to process")
            return
        
        for filename in files:
            file_path = os.path.join(UPLOADS_DIR, filename)
            if os.path.isfile(file_path):
                process_file(file_path)
        
        logger.info("Ingestion completed")
    except Exception as e:
        logger.error(f"Error listing files: {e}")

if __name__ == '__main__':
    main()
PYEOF

chmod +x $PROJECT_DIR/scripts/ingest_local_files.py
echo "✓ Local ingestion script created"

# Setup cron job for ingestion (every 5 minutes)
# First, create environment file for cron
cat > /opt/pdc/.env.cron <<'ENVEOF'
DB_HOST=__DB_HOST__
DB_NAME=pdc_db
DB_USER=__DB_USER__
DB_PASSWORD=__DB_PASSWORD__
DB_PORT=5432
ENVEOF

# Set proper permissions
chown ingest_worker:ingest_worker /opt/pdc
chmod 755 /opt/pdc
chown ingest_worker:ingest_worker /opt/pdc/scripts/ingest_local_files.py

# Create cron job script wrapper
cat > /opt/pdc/scripts/run_ingest_cron.sh <<'CRONEOF'
#!/bin/bash
source /opt/pdc/.env.cron
export DB_HOST DB_NAME DB_USER DB_PASSWORD DB_PORT
/opt/pdc/venv/bin/python3 /opt/pdc/scripts/ingest_local_files.py
CRONEOF

chmod +x /opt/pdc/scripts/run_ingest_cron.sh
chown ingest_worker:ingest_worker /opt/pdc/scripts/run_ingest_cron.sh

# Install cron job for ingest_worker user
cat > /tmp/crontab-ingest <<'CRONEOF'
*/5 * * * * /opt/pdc/scripts/run_ingest_cron.sh >> /var/log/pdc-ingest-cron.log 2>&1
CRONEOF

sudo -u ingest_worker crontab /tmp/crontab-ingest
rm /tmp/crontab-ingest

echo "✓ Cron job scheduled (every 5 minutes)"
echo "✓ SFTP server and ingestion pipeline ready!"
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
