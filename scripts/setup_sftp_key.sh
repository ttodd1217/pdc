#!/bin/bash
# Script to set up SSH key for SFTP access
# This script helps generate and configure SSH keys for the PDC application

set -e

KEY_PATH="${HOME}/.ssh/id_ed25519"
PUBLIC_KEY_PATH="${KEY_PATH}.pub"

echo "🔑 SFTP SSH Key Setup"
echo "===================="

# Check if key already exists
if [ -f "$KEY_PATH" ]; then
    echo "⚠️  SSH key already exists at: $KEY_PATH"
    read -p "Do you want to generate a new key? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Using existing key."
        echo ""
        echo "📋 Your public key (add this to SFTP server):"
        cat "$PUBLIC_KEY_PATH"
        exit 0
    fi
fi

# Generate new key
echo ""
echo "Generating new Ed25519 SSH key..."
ssh-keygen -t ed25519 -f "$KEY_PATH" -C "pdc-app" -N ""

# Set correct permissions
chmod 600 "$KEY_PATH"
chmod 644 "$PUBLIC_KEY_PATH"

echo "✅ SSH key generated successfully!"
echo ""
echo "📋 Your public key (add this to SFTP server's ~/.ssh/authorized_keys):"
echo "---"
cat "$PUBLIC_KEY_PATH"
echo "---"
echo ""
echo "📝 Next steps:"
echo "   1. Copy the public key above"
echo "   2. On SFTP server, run:"
echo "      mkdir -p ~/.ssh"
echo "      chmod 700 ~/.ssh"
echo "      echo 'PUBLIC_KEY' >> ~/.ssh/authorized_keys"
echo "      chmod 600 ~/.ssh/authorized_keys"
echo ""
echo "   3. Test connection:"
echo "      sftp -i $KEY_PATH sftp_user@your-sftp-host"
echo ""
echo "   4. Update .env file:"
echo "      SFTP_KEY_PATH=$KEY_PATH"




