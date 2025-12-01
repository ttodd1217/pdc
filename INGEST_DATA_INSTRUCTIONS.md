# How to Ingest Sample Data - Step by Step

## Method 1: Using the Batch Script (Easiest for Windows)

1. **Double-click** the file `ingest_data.bat` in your project folder
   - OR right-click → Run as administrator

That's it! The script will:
- Activate your virtual environment
- Run the ingestion script
- Show you the results

## Method 2: Using Command Prompt

1. **Open Command Prompt**
   - Press `Win + R`
   - Type `cmd`
   - Press Enter

2. **Navigate to project folder**
   ```cmd
   cd C:\Users\wreed\OneDrive\Desktop\PDC
   ```

3. **Activate virtual environment**
   ```cmd
   venv\Scripts\activate
   ```
   You should see `(venv)` appear in your prompt.

4. **Run the ingestion script**
   ```cmd
   python scripts/ingest_sample_data.py
   ```

## Method 3: Using PowerShell

1. **Open PowerShell**
   - Press `Win + X`
   - Select "Windows PowerShell" or "Terminal"

2. **Navigate to project folder**
   ```powershell
   cd C:\Users\wreed\OneDrive\Desktop\PDC
   ```

3. **Activate virtual environment**
   ```powershell
   .\venv\Scripts\Activate.ps1
   ```
   If you get an execution policy error, run:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
   Then try activating again.

4. **Run the ingestion script**
   ```powershell
   python scripts/ingest_sample_data.py
   ```

## Method 4: Using the Long Python Command

If you prefer the one-liner command:

1. **Open Command Prompt or PowerShell**

2. **Navigate and activate** (same as above)

3. **Run the command** (all on one line):
   ```cmd
   python -c "from app import create_app; from app.services.file_ingestion import FileIngestionService; app = create_app(); app.app_context().push(); FileIngestionService.ingest_file('data/example_format1.csv')"
   ```

   For format 2:
   ```cmd
   python -c "from app import create_app; from app.services.file_ingestion import FileIngestionService; app = create_app(); app.app_context().push(); FileIngestionService.ingest_file('data/example_format2.txt')"
   ```

## What You Should See

If successful, you'll see:
```
============================================================
Sample Data Ingestion
============================================================
✅ Successfully ingested 10 trades from data/example_format1.csv

✅ Successfully ingested 10 trades from data/example_format2.txt

============================================================
✅ All 2 files ingested successfully!
============================================================
```

## Troubleshooting

### "python is not recognized"
- Make sure Python is installed
- Try `py` instead of `python`
- Make sure virtual environment is activated

### "No module named 'app'"
- Make sure you're in the project root directory
- Make sure virtual environment is activated
- Run: `pip install -r requirements.txt`

### "File not found"
- Check that `data/example_format1.csv` exists
- Make sure you're in the project root directory

### Virtual environment not activating
- Make sure you're in the project directory
- Check that `venv` folder exists
- Try: `python -m venv venv` to recreate it

## Quick Test

After ingesting, test the API:

```cmd
curl -H "X-API-Key: dev-api-key" "http://127.0.0.1:5001/api/blotter?date=2025-01-15"
```

You should see the ingested data!




