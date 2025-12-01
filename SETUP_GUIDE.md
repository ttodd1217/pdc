# Complete Setup Guide

This guide will walk you through setting up the Portfolio Data Clearinghouse from scratch.

## Prerequisites

Before you begin, ensure you have:

- [ ] **Python 3.9 or higher** - Check with `python --version`
- [ ] **pip** - Python package manager (usually comes with Python)
- [ ] **PostgreSQL** (optional for local dev, SQLite works too)
- [ ] **Git** - For cloning the repository

## Step 1: Clone or Navigate to Project

If you haven't already:

```bash
cd C:\Users\wreed\OneDrive\Desktop\PDC
```

## Step 2: Create Virtual Environment (Recommended)

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On Mac/Linux:
# source venv/bin/activate
```

You should see `(venv)` in your terminal prompt.

## Step 3: Install Dependencies

```bash
pip install -r requirements.txt
```

This will install:
- Flask and Flask-SQLAlchemy
- PostgreSQL driver (psycopg2)
- SFTP client (paramiko)
- Testing tools (pytest)
- And other dependencies

## Step 4: Configure Environment Variables

### Option A: Using .env file (Recommended)

1. Create a `.env` file in the project root:

```bash
# Copy example (if it exists)
copy .env.example .env
# Or create new file
notepad .env
```

2. Add these variables to `.env`:

```bash
# Database - Use SQLite for easy local setup
DATABASE_URL=sqlite:///pdc.db

# API Security
API_KEY=dev-api-key-change-in-production
SECRET_KEY=dev-secret-key-change-in-production

# SFTP Configuration (optional for now)
SFTP_HOST=localhost
SFTP_HOST_PORT=3022      # Host port that maps to the Docker container
SFTP_PORT=22             # Container port; keep 22 unless your server uses another port
SFTP_USERNAME=sftp_user
SFTP_KEY_PATH=~/.ssh/id_ed25519
SFTP_REMOTE_PATH=/uploads
SFTP_PROCESSED_PATH=/processed

# Alerting (optional for now)
ALERT_SERVICE_URL=http://localhost:5001/alerts
ALERT_API_KEY=alert-api-key
```

### Option B: Set Environment Variables Directly

**Windows PowerShell:**
```powershell
$env:DATABASE_URL="sqlite:///pdc.db"
$env:API_KEY="dev-api-key"
```

**Windows CMD:**
```cmd
set DATABASE_URL=sqlite:///pdc.db
set API_KEY=dev-api-key
```

**Mac/Linux:**
```bash
export DATABASE_URL=sqlite:///pdc.db
export API_KEY=dev-api-key
```

## Step 5: Initialize Database

```bash
# Initialize database tables
python -c "from app import create_app, db; app = create_app(); app.app_context().push(); db.create_all()"
```

This creates the database file (`pdc.db` for SQLite) and all necessary tables.

## Step 6: Run the Application

```bash
python run.py
```

You should see output like:
```
 * Running on http://127.0.0.1:5000
 * Debug mode: on
```

## Step 7: Test the Application

### Test Health Endpoint

Open a new terminal and run:

```bash
# Windows PowerShell
curl http://localhost:5000/health

# Or use browser
# Navigate to: http://localhost:5000/health
```

Expected response:
```json
{
  "status": "healthy",
  "database": "healthy",
  "timestamp": "2025-01-15T10:00:00.000Z"
}
```

### Test API Endpoint

```bash
# Test blotter endpoint (requires API key)
curl -H "X-API-Key: dev-api-key" "http://localhost:5000/api/blotter?date=2025-01-15"
```

## Step 8: Load Sample Data (Optional)

To test with sample data:

```bash
# Ingest format 1 (CSV)
python -c "from app import create_app; from app.services.file_ingestion import FileIngestionService; app = create_app(); app.app_context().push(); FileIngestionService.ingest_file('data/example_format1.csv')"

# Ingest format 2 (pipe-delimited)
python -c "from app import create_app; from app.services.file_ingestion import FileIngestionService; app = create_app(); app.app_context().push(); FileIngestionService.ingest_file('data/example_format2.txt')"
```

Then test the endpoints:

```bash
# Get blotter data
curl -H "X-API-Key: dev-api-key" "http://localhost:5000/api/blotter?date=2025-01-15"

# Get positions
curl -H "X-API-Key: dev-api-key" "http://localhost:5000/api/positions?date=2025-01-15"

# Get alarms
curl -H "X-API-Key: dev-api-key" "http://localhost:5000/api/alarms?date=2025-01-15"
```

## Step 9: Run Tests

```bash
# Run all tests
pytest

# Run with coverage report
pytest --cov=app --cov-report=html

# View coverage report
# Open htmlcov/index.html in browser
```

## Step 10: Set Up SFTP (Optional)

If you want to test file ingestion from SFTP:

### Quick Local SFTP Server

1. **Start Docker SFTP server** (if you have Docker):
   ```bash
   docker-compose -f docker-compose.sftp.yml up -d
   ```

2. **Generate SSH keys**:
   ```bash
   bash scripts/setup_sftp_key.sh
   ```

3. **Test connection**:
   ```bash
   python scripts/test_sftp.py
   ```

See [SFTP_SETUP_GUIDE.md](SFTP_SETUP_GUIDE.md) for detailed SFTP setup.

## Step 11: Run Smoke Tests

```bash
# Set environment variables
$env:API_URL="http://localhost:5000"
$env:API_KEY="dev-api-key"

# Run smoke tests
python scripts/smoketest.py
```

## Troubleshooting

### Issue: ModuleNotFoundError

**Solution**: Make sure virtual environment is activated and dependencies are installed:
```bash
pip install -r requirements.txt
```

### Issue: Database Connection Error

**Solution**: 
- For SQLite: Ensure you have write permissions in the project directory
- For PostgreSQL: Verify database exists and credentials are correct:
  ```bash
  # Create database
  createdb pdc_db
  ```

### Issue: Port Already in Use

**Solution**: Change the port in `run.py`:
```python
app.run(host='0.0.0.0', port=5001, debug=True)  # Use different port
```

### Issue: Import Errors

**Solution**: Ensure you're in the project root directory and virtual environment is activated.

### Issue: Windows Path Issues

**Solution**: Use forward slashes or raw strings for paths in `.env`:
```bash
SFTP_KEY_PATH=C:/Users/wreed/.ssh/id_ed25519
```

## Quick Start Checklist

- [ ] Python 3.9+ installed
- [ ] Virtual environment created and activated
- [ ] Dependencies installed (`pip install -r requirements.txt`)
- [ ] `.env` file created with configuration
- [ ] Database initialized
- [ ] Application running (`python run.py`)
- [ ] Health endpoint working (`http://localhost:5000/health`)
- [ ] Tests passing (`pytest`)

## Next Steps

Once basic setup is complete:

1. **Read the Documentation**:
   - [README.md](README.md) - Project overview
   - [QUICKSTART.md](QUICKSTART.md) - Quick reference
   - [SFTP_SETUP_GUIDE.md](SFTP_SETUP_GUIDE.md) - SFTP configuration

2. **Explore the API**:
   - Test all endpoints
   - Load sample data
   - Try different queries

3. **Set Up Development**:
   - Configure your IDE
   - Set up code formatting (black, isort)
   - Enable linting (flake8)

4. **Prepare for Deployment**:
   - Review [AWS_DEPLOYMENT_GUIDE.md](AWS_DEPLOYMENT_GUIDE.md)
   - Set up AWS account
   - Configure CI/CD

## Common Commands Reference

```bash
# Activate virtual environment
venv\Scripts\activate  # Windows
source venv/bin/activate  # Mac/Linux

# Run application
python run.py

# Run tests
pytest
pytest --cov=app

# Run smoke tests
python scripts/smoketest.py

# Test SFTP connection
python scripts/test_sftp.py

# Run file ingestion
python scripts/ingest_files.py

# Start mock alert service
python scripts/mock_alert_service.py
```

## Getting Help

If you encounter issues:

1. Check the error message carefully
2. Review relevant documentation
3. Check CloudWatch logs (if deployed)
4. Verify environment variables are set correctly
5. Ensure all dependencies are installed

## Windows-Specific Notes

### PowerShell Execution Policy

If you get execution policy errors:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Path Separators

Windows uses backslashes, but Python accepts forward slashes:
```bash
# Both work:
SFTP_KEY_PATH=C:\Users\wreed\.ssh\id_ed25519
SFTP_KEY_PATH=C:/Users/wreed/.ssh/id_ed25519
```

### Line Endings

If you see `\r\n` issues, ensure your `.env` file uses Unix line endings (LF) or configure Git:
```bash
git config core.autocrlf false
```

## Success!

If you see the health endpoint responding and tests passing, you're all set! 🎉

You can now:
- Explore the API endpoints
- Load and query trade data
- Set up SFTP for file ingestion
- Deploy to AWS when ready




