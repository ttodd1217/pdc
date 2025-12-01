#!/usr/bin/env python3
"""
Test script for SFTP connection and file operations.
"""
import sys
import os

# Add project root to Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)

from app import create_app
from app.config import Config
from app.services.sftp_service import SFTPService
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

def test_sftp_connection():
    """Test SFTP connection and list files"""
    print("=" * 60)
    print("Testing SFTP Connection")
    print("=" * 60)
    
    app = create_app(Config)
    
    with app.app_context():
        service = SFTPService()
        
        print(f"\n📋 Configuration:")
        print(f"   Host: {service.host}")
        print(f"   Port: {service.port}")
        print(f"   Username: {service.username}")
        print(f"   Key Path: {service.key_path}")
        print(f"   Remote Path: {service.remote_path}")
        print(f"   Processed Path: {service.processed_path}")
        
        try:
            print(f"\n🔌 Connecting to SFTP server...")
            files = service.list_files()
            print(f"✅ Connection successful!")
            print(f"\n📁 Files in {service.remote_path}:")
            if files:
                for f in files:
                    print(f"   - {f}")
            else:
                print("   (no files found)")
            return True
        except FileNotFoundError as e:
            print(f"❌ SSH key not found: {str(e)}")
            print(f"\n💡 Solution:")
            print(f"   1. Generate SSH key: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519")
            print(f"   2. Add public key to SFTP server's ~/.ssh/authorized_keys")
            print(f"   3. Update SFTP_KEY_PATH in .env if using different path")
            return False
        except OSError as e:
            error_str = str(e)
            if '10013' in error_str or 'socket' in error_str.lower():
                print(f"❌ Windows Socket Permission Error: {error_str}")
                print(f"\n💡 This is a Windows-specific issue. Try these solutions:")
                print(f"\n   1. Allow Python through Windows Firewall:")
                print(f"      - Open Windows Defender Firewall")
                print(f"      - Click 'Allow an app or feature through Windows Defender Firewall'")
                print(f"      - Find Python and check both Private and Public")
                print(f"\n   2. Test if port is accessible:")
                print(f"      Test-NetConnection -ComputerName {service.host} -Port {service.port}")
                print(f"\n   3. Check if Docker container is running:")
                print(f"      docker ps --filter 'name=pdc-sftp'")
                print(f"\n   4. Verify SSH key is configured in container:")
                print(f"      docker exec pdc-sftp cat /home/sftp_user/.ssh/authorized_keys")
                print(f"\n   5. Try running PowerShell as Administrator")
                return False
            else:
                print(f"❌ Connection failed: {error_str}")
                print(f"\n💡 Troubleshooting:")
                print(f"   1. Verify SFTP server is running and accessible")
                print(f"   2. Check hostname/IP and port in configuration")
                print(f"   3. Verify SSH public key is in server's authorized_keys")
                print(f"   4. Test manually: sftp -i {service.key_path} -P {service.port} {service.username}@{service.host}")
                return False
        except Exception as e:
            print(f"❌ Connection failed: {str(e)}")
            print(f"\n💡 Troubleshooting:")
            print(f"   1. Verify SFTP server is running and accessible")
            print(f"   2. Check hostname/IP and port in configuration")
            print(f"   3. Verify SSH public key is in server's authorized_keys")
            print(f"   4. Test manually: sftp -i {service.key_path} -P {service.port} {service.username}@{service.host}")
            return False

def test_file_download():
    """Test downloading a file"""
    print("\n" + "=" * 60)
    print("Testing File Download")
    print("=" * 60)
    
    app = create_app(Config)
    
    with app.app_context():
        service = SFTPService()
        
        try:
            files = service.list_files()
            if not files:
                print("⚠️  No files available to download")
                return False
            
            test_file = files[0]
            print(f"\n📥 Downloading: {test_file}")
            
            import tempfile
            with tempfile.NamedTemporaryFile(delete=False, suffix='.tmp') as tmp:
                local_path = tmp.name
            
            service.download_file(test_file, local_path)
            print(f"✅ File downloaded to: {local_path}")
            
            # Clean up
            os.remove(local_path)
            return True
        except Exception as e:
            print(f"❌ Download failed: {str(e)}")
            return False

if __name__ == '__main__':
    print("\n🧪 SFTP Connection Test")
    print("=" * 60)
    
    # Test connection
    connection_ok = test_sftp_connection()
    
    if connection_ok:
        # Test file download
        download_ok = test_file_download()
        
        print("\n" + "=" * 60)
        if connection_ok and download_ok:
            print("✅ All tests passed!")
            sys.exit(0)
        else:
            print("⚠️  Some tests failed")
            sys.exit(1)
    else:
        print("\n" + "=" * 60)
        print("❌ Connection test failed. Please fix configuration and try again.")
        sys.exit(1)




