# Troubleshooting Guide

Common issues and solutions for the Portfolio Data Clearinghouse.

## Windows Socket Error

### Error: `OSError: [WinError 10038] An operation was attempted on something that is not a socket`

**Cause**: Windows-specific issue with Flask development server using `0.0.0.0` as host.

**Solution**: The `run.py` file has been updated to use `127.0.0.1` instead of `0.0.0.0` on Windows. If you still see this error:

1. **Use a different port**:
   ```bash
   set PORT=5001
   python run.py
   ```

2. **Or modify run.py directly**:
   ```python
   app.run(host='127.0.0.1', port=5000, debug=True)
   ```

3. **Or use a different host**:
   ```python
   app.run(host='localhost', port=5000, debug=True)
   ```

## Port Already in Use

### Error: `OSError: [WinError 10048] Only one usage of each socket address is permitted`

**Solution**:
1. Find what's using the port:
   ```bash
   netstat -ano | findstr :5000
   ```

2. Kill the process (replace PID with the number from above):
   ```bash
   taskkill /PID <PID> /F
   ```

3. Or use a different port:
   ```bash
   set PORT=5001
   python run.py
   ```

## Module Not Found Errors

### Error: `ModuleNotFoundError: No module named 'app'`

**Solution**:
1. Ensure you're in the project root directory
2. Activate virtual environment:
   ```bash
   venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Database Connection Errors

### Error: `sqlalchemy.exc.OperationalError: unable to open database file`

**Solution**:
1. Ensure you have write permissions in the project directory
2. Check the database path in `.env`:
   ```bash
   DATABASE_URL=sqlite:///pdc.db
   ```
3. Use absolute path if needed:
   ```bash
   DATABASE_URL=sqlite:///C:/Users/wreed/OneDrive/Desktop/PDC/pdc.db
   ```

### Error: PostgreSQL connection errors

**Solution**:
1. Verify PostgreSQL is running:
   ```bash
   # Windows
   services.msc  # Check PostgreSQL service
   ```
2. Check connection string in `.env`:
   ```bash
   DATABASE_URL=postgresql://username:password@localhost:5432/pdc_db
   ```
3. Create database if it doesn't exist:
   ```bash
   createdb pdc_db
   ```

## Import Errors

### Error: `ImportError: cannot import name 'create_app'`

**Solution**:
1. Ensure you're in the project root
2. Check that `app/__init__.py` exists
3. Verify virtual environment is activated
4. Reinstall dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## SFTP Connection Errors

### Error: `[WinError 10013] An attempt was made to access a socket in a way forbidden by its access permissions`

**Cause**: Windows Firewall or security software is blocking Python from making outbound connections to the SFTP server.

**Solution**:

1. **Run the diagnostic script** (Windows PowerShell):
   ```powershell
   .\scripts\fix_windows_sftp.ps1
   ```

2. **Allow Python through Windows Firewall**:
   - Open "Windows Defender Firewall" from Start menu
   - Click "Allow an app or feature through Windows Defender Firewall"
   - Click "Change settings" (requires admin)
   - Find "Python" and check both "Private" and "Public"
   - If not listed, click "Allow another app..." and browse to your Python executable

3. **Or use PowerShell as Administrator**:
   ```powershell
   # Find Python path
   $pythonPath = (Get-Command python).Source
   
   # Allow outbound connections
   New-NetFirewallRule -DisplayName "Allow Python SFTP" -Direction Outbound -Program $pythonPath -Action Allow
   ```

4. **Verify Docker container is running**:
   ```powershell
   docker ps --filter "name=pdc-sftp"
   ```

5. **Test port connectivity** (replace the port if you customized it):
   ```powershell
   Test-NetConnection -ComputerName localhost -Port $env:SFTP_HOST_PORT
   # Defaults to 3022 if SFTP_HOST_PORT is not set
   ```

6. **Check if antivirus is blocking**: Temporarily disable antivirus/security software to test

### Error: `paramiko.ssh_exception.SSHException: Unable to connect`

**Solution**:
1. Verify SFTP server is running and accessible
2. Check SSH key path in `.env`:
   ```bash
   SFTP_KEY_PATH=C:/Users/wreed/.ssh/id_ed25519
   ```
3. Verify SSH key is configured in Docker container:
   ```powershell
   docker exec pdc-sftp cat /home/sftp_user/.ssh/authorized_keys
   ```
4. Test connection manually (use the same port you expose locally):
   ```bash
   sftp -i ~/.ssh/id_ed25519 -P ${SFTP_HOST_PORT:-3022} sftp_user@localhost
   ```
5. See [SFTP_SETUP_GUIDE.md](SFTP_SETUP_GUIDE.md) for detailed setup

## API Key Authentication Errors

### Error: `401 Unauthorized: Invalid or missing API key`

**Solution**:
1. Include API key in request:
   ```bash
   curl -H "X-API-Key: dev-api-key" "http://localhost:5000/api/blotter?date=2025-01-15"
   ```
2. Or use query parameter:
   ```bash
   curl "http://localhost:5000/api/blotter?date=2025-01-15&api_key=dev-api-key"
   ```
3. Verify API key in `.env` matches the one you're using

## File Ingestion Errors

### Error: `ValueError: Unknown file format`

**Solution**:
1. Verify file format matches one of the supported formats
2. Check file encoding (should be UTF-8)
3. Ensure file has proper headers/format
4. See example files in `data/` directory

## Windows-Specific Issues

### PowerShell Execution Policy

**Error**: `cannot be loaded because running scripts is disabled`

**Solution**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Path Issues

**Error**: Backslash issues in paths

**Solution**: Use forward slashes or raw strings:
```bash
SFTP_KEY_PATH=C:/Users/wreed/.ssh/id_ed25519
# Or
SFTP_KEY_PATH=C:\\Users\\wreed\\.ssh\\id_ed25519
```

### Line Ending Issues

**Error**: `\r\n` or line ending errors

**Solution**:
1. Configure Git:
   ```bash
   git config core.autocrlf false
   ```
2. Use a text editor that supports Unix line endings
3. Or convert files:
   ```bash
   dos2unix filename
   ```

## Environment Variable Issues

### Variables Not Loading

**Solution**:
1. Ensure `.env` file is in project root
2. Check file name is exactly `.env` (not `.env.txt`)
3. Verify format (no spaces around `=`):
   ```bash
   DATABASE_URL=sqlite:///pdc.db
   ```
4. Restart the application after changing `.env`

## Test Failures

### Error: Tests fail with database errors

**Solution**:
1. Tests use in-memory SQLite by default
2. Ensure test database is properly initialized
3. Run tests with verbose output:
   ```bash
   pytest -v
   ```

## Performance Issues

### Application is slow

**Solution**:
1. Use PostgreSQL instead of SQLite for better performance
2. Check database indexes are created
3. Review query performance in logs

## Still Having Issues?

1. **Check logs**: Look for detailed error messages
2. **Verify setup**: Go through [SETUP_GUIDE.md](SETUP_GUIDE.md) again
3. **Check versions**: Ensure Python 3.9+ is installed
4. **Clean install**: 
   ```bash
   # Remove virtual environment and reinstall
   rmdir /s venv
   python -m venv venv
   venv\Scripts\activate
   pip install -r requirements.txt
   ```

## Getting Help

If you're still stuck:
1. Check the specific error message
2. Review relevant documentation
3. Check CloudWatch logs (if deployed)
4. Verify all environment variables are set correctly




