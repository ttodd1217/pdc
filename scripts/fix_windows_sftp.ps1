#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Helper script to diagnose and fix Windows SFTP connection issues.
.DESCRIPTION
    This script helps diagnose and fix common Windows issues when connecting to SFTP,
    particularly socket permission errors (WinError 10013).
#>

Write-Host "=" * 60
Write-Host "Windows SFTP Connection Diagnostics"
Write-Host "=" * 60
Write-Host ""

# Determine host port (default 3022 to avoid conflicts)
$hostPort = $env:SFTP_HOST_PORT
if (-not $hostPort -or $hostPort -eq "") {
    $hostPort = 3022
}

# Check if Docker container is running
Write-Host "1. Checking Docker container status..." -ForegroundColor Cyan
$container = docker ps --filter "name=pdc-sftp" --format "{{.Names}}" 2>&1
if ($container -eq "pdc-sftp") {
    Write-Host "   ✅ Docker container 'pdc-sftp' is running" -ForegroundColor Green
} else {
    Write-Host "   ❌ Docker container 'pdc-sftp' is not running" -ForegroundColor Red
    Write-Host "   Start it with: docker-compose -f docker-compose.sftp.yml up -d" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Check if selected port is listening
Write-Host "2. Checking if port $hostPort is listening..." -ForegroundColor Cyan
$portCheck = netstat -ano | findstr ":$hostPort.*LISTENING"
if ($portCheck) {
    Write-Host "   ✅ Port $hostPort is listening" -ForegroundColor Green
} else {
    Write-Host "   ❌ Port $hostPort is not listening" -ForegroundColor Red
    Write-Host "   Start the Docker container first" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Test network connection
Write-Host "3. Testing network connection to localhost:$hostPort..." -ForegroundColor Cyan
try {
    $connection = Test-NetConnection -ComputerName localhost -Port $hostPort -WarningAction SilentlyContinue
    if ($connection.TcpTestSucceeded) {
        Write-Host "   ✅ Network connection successful" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Network connection test failed" -ForegroundColor Yellow
        Write-Host "   This might indicate a firewall issue" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  Could not test connection: $_" -ForegroundColor Yellow
}
Write-Host ""

# Check SSH key
Write-Host "4. Checking SSH key..." -ForegroundColor Cyan
$sshKeyPath = "$env:USERPROFILE\.ssh\id_ed25519"
if (Test-Path $sshKeyPath) {
    Write-Host "   ✅ SSH key found at: $sshKeyPath" -ForegroundColor Green
} else {
    Write-Host "   ❌ SSH key not found at: $sshKeyPath" -ForegroundColor Red
    Write-Host "   Generate one with: ssh-keygen -t ed25519 -f $sshKeyPath" -ForegroundColor Yellow
}
Write-Host ""

# Check authorized_keys in container
Write-Host "5. Checking authorized_keys in Docker container..." -ForegroundColor Cyan
$authorizedKey = docker exec pdc-sftp cat /home/sftp_user/.ssh/authorized_keys 2>&1
if ($authorizedKey -and $authorizedKey -ne "YOUR_PUBLIC_KEY_HERE" -and $authorizedKey.Length -gt 20) {
    Write-Host "   ✅ authorized_keys is configured" -ForegroundColor Green
    $pubKey = Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub" -ErrorAction SilentlyContinue
    if ($pubKey -and $authorizedKey -match $pubKey.Split(' ')[0]) {
        Write-Host "   ✅ Public key matches your local key" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Public key in container may not match your local key" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ❌ authorized_keys is not properly configured" -ForegroundColor Red
    Write-Host "   Setting up SSH key in container..." -ForegroundColor Yellow
    if (Test-Path "$env:USERPROFILE\.ssh\id_ed25519.pub") {
        $pubKey = Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
        docker exec pdc-sftp sh -c "echo '$pubKey' > /home/sftp_user/.ssh/authorized_keys && chmod 600 /home/sftp_user/.ssh/authorized_keys && chown 1001:1001 /home/sftp_user/.ssh/authorized_keys" 2>&1 | Out-Null
        Write-Host "   ✅ SSH key configured in container" -ForegroundColor Green
    }
}
Write-Host ""

# Windows Firewall information
Write-Host "6. Windows Firewall Information..." -ForegroundColor Cyan
Write-Host "   If you see WinError 10013, Windows Firewall may be blocking Python." -ForegroundColor Yellow
Write-Host ""
Write-Host "   To allow Python through Windows Firewall:" -ForegroundColor Yellow
Write-Host "   1. Open 'Windows Defender Firewall' from Start menu" -ForegroundColor White
Write-Host "   2. Click 'Allow an app or feature through Windows Defender Firewall'" -ForegroundColor White
Write-Host "   3. Click 'Change settings' (requires admin)" -ForegroundColor White
Write-Host "   4. Find 'Python' in the list and check both 'Private' and 'Public'" -ForegroundColor White
Write-Host "   5. If Python is not listed, click 'Allow another app...' and browse to:" -ForegroundColor White
$pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
if ($pythonPath) {
    Write-Host "      $pythonPath" -ForegroundColor Cyan
} else {
    Write-Host "      C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "   Or run this PowerShell command as Administrator:" -ForegroundColor Yellow
Write-Host "   New-NetFirewallRule -DisplayName 'Allow Python SFTP' -Direction Outbound -Program '$pythonPath' -Action Allow" -ForegroundColor Cyan
Write-Host ""

Write-Host "=" * 60
Write-Host "Diagnostics complete!"
Write-Host "=" * 60
Write-Host ""
Write-Host "Try running the test again: python scripts/test_sftp.py" -ForegroundColor Green

