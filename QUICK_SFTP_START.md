# SFTP Setup - Quick Reference Card

## 📍 File Location
```
C:\Users\Administrator\Dev_Env\vest\
```

## 🚀 3-Step Quick Start

### Step 1: Generate SSH Key (Pick ONE)

Command Prompt (Windows)**
```cmd
cd C:\Users\Administrator\Dev_Env\vest\terraform
ssh-keygen -t ed25519 -f pdc-sftp-server-key.pem -N "" -C "pdc-sftp-server"
aws ec2 import-key-pair --key-name pdc-sftp-server-key --region us-east-2 --public-key-material fileb://pdc-sftp-server-key.pem.pub
```

```

### Step 2: Deploy SFTP Server

```bash
cd C:\Users\Administrator\Dev_Env\vest\terraform
terraform validate
terraform plan -lock=false -out=tfplan
terraform apply -lock=false tfplan
```

### Step 3: Get Connection Info

```bash
cd C:\Users\Administrator\Dev_Env\vest\terraform
terraform output sftp_ec2_public_ip
```

Will show something like: `18.217.242.197`

---

## 🔗 Connect to SFTP

```bash
cd C:\Users\Administrator\Dev_Env\vest\terraform
sftp -i pdc-sftp-server-key.pem sftp_user@18.217.242.197
```

Replace `18.217.242.197` with your IP from Step 3.

Inside SFTP:
```
sftp> put myfile.csv
sftp> ls
sftp> exit
```

---

## 🧪 Test SSH (Verify It Works)

```bash
cd C:\Users\Administrator\Dev_Env\vest\terraform
ssh -i pdc-sftp-server-key.pem ubuntu@18.217.242.197 "echo 'Connected!'"
```

---

## 📁 Key Files

| File | Location | Purpose |
|------|----------|---------|
| Private Key | `terraform/pdc-sftp-server-key.pem` | SSH access (SECRET!) |
| Public Key | `terraform/pdc-sftp-server-key.pem.pub` | Shareable |
| Setup Script | `terraform/setup_sftp_keypair.ps1` | Auto key generation |
| Config | `terraform/sftp_ec2.tf` | EC2 configuration |
| Outputs | `terraform/outputs.tf` | Deployment outputs |

---

## ⏱️ What to Expect

| Step | Time | Status |
|------|------|--------|
| Key generation | < 1 sec | 🟢 Instant |
| Import to AWS | < 2 sec | 🟢 Quick |
| Terraform plan | 10-15 sec | 🟡 Medium |
| Create EC2 instance | 1-2 min | 🟡 Medium |
| Boot and configure | 2-3 min | 🟠 Slow |
| **Total** | **5-7 min** | ⏱️ |

---

## ❓ Common Issues

### "ssh-keygen: command not found"
→ Install Git for Windows or OpenSSH

### "ssh: connect to host ... refused"
→ Wait 2-3 minutes for EC2 to boot, then retry

### "Permission denied (publickey)"
→ Verify key file has 600 permissions:
```bash
ls -la pdc-sftp-server-key.pem
```

### "Key already exists"
→ Delete old key:
```bash
aws ec2 delete-key-pair --key-name pdc-sftp-server-key
```

---

## 📚 Full Documentation

- **Complete Setup Guide:** `README_SFTP_SETUP.md`
- **Deployment Details:** `terraform/SFTP_DEPLOYMENT_GUIDE.md`
- **Key Management:** `terraform/SFTP_KEYPAIR_SETUP.md`
- **Terraform Config:** `terraform/sftp_ec2.tf`

---

## 🎯 Next: Update PDC Config

After SFTP is working, update `app/config.py`:

```python
SFTP_HOST = "18.217.242.197"  # Your Elastic IP
SFTP_PORT = 22
SFTP_USERNAME = "sftp_user"
SFTP_KEY_PATH = "/path/to/pdc-sftp-server-key.pem"
SFTP_REMOTE_PATH = "/uploads"
```

---

## 📞 Support

- Check logs: `terraform/SFTP_DEPLOYMENT_GUIDE.md` (Troubleshooting section)
- View outputs: `terraform output` (shows all deployment info)
- SSH to instance: `ssh -i pdc-sftp-server-key.pem ubuntu@<IP>`
- Check AWS console: EC2 → Instances → pdc-sftp-server

---

**Created:** Dec 12, 2025  
**Status:** ✅ Ready to Deploy
