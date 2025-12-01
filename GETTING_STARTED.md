# Getting Started - Quick Reference

## 🚀 Fastest Way to Get Running

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Create `.env` File
```bash
DATABASE_URL=sqlite:///pdc.db
API_KEY=dev-api-key
```

### 3. Initialize Database
```bash
python -c "from app import create_app, db; app = create_app(); app.app_context().push(); db.create_all()"
```

### 4. Run Application
```bash
python run.py
```

### 5. Test It
Open browser: http://localhost:5000/health

## 📚 Documentation Guide

- **New to the project?** → Start with [SETUP_GUIDE.md](SETUP_GUIDE.md)
- **Want quick commands?** → See [QUICKSTART.md](QUICKSTART.md)
- **Setting up SFTP?** → See [SFTP_SETUP_GUIDE.md](SFTP_SETUP_GUIDE.md)
- **Deploying to AWS?** → See [AWS_DEPLOYMENT_GUIDE.md](AWS_DEPLOYMENT_GUIDE.md)
- **Need help?** → Check [README.md](README.md)

## 🎯 Common Tasks

### Load Sample Data
```bash
python -c "from app import create_app; from app.services.file_ingestion import FileIngestionService; app = create_app(); app.app_context().push(); FileIngestionService.ingest_file('data/example_format1.csv')"
```

### Run Tests
```bash
pytest
```

### Test API
```bash
curl -H "X-API-Key: dev-api-key" "http://localhost:5000/api/blotter?date=2025-01-15"
```

### Run Smoke Tests
```bash
python scripts/smoketest.py
```

## ⚡ Troubleshooting

**Port in use?** → Change port in `run.py`  
**Import errors?** → Activate virtual environment  
**Database errors?** → Check `.env` file  
**Need help?** → See [SETUP_GUIDE.md](SETUP_GUIDE.md) troubleshooting section




