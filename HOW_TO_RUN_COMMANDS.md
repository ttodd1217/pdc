# How to Run Commands - Quick Guide

## Running Python Commands

### Option 1: Using Command Prompt (CMD) or PowerShell

**Windows Command Prompt (CMD):**
```cmd
python -c "from app import create_app; from app.services.file_ingestion import FileIngestionService; app = create_app(); app.app_context().push(); FileIngestionService.ingest_file('data/example_format1.csv')"
```

**Windows PowerShell:**
```powershell
python -c "from app import create_app; from app.services.file_ingestion import FileIngestionService; app = create_app(); app.app_context().push(); FileIngestionService.ingest_file('data/example_format1.csv')"
```

**Important Notes:**
- Make sure you're in the project directory: `cd C:\Users\wreed\OneDrive\Desktop\PDC`
- Make sure virtual environment is activated: `venv\Scripts\activate`
- Use double quotes `"` for the entire Python command
- Use single quotes `'` inside for the file path

### Option 2: Using a Python Script (Easier!)

Instead of the long command, use the provided script:

```bash
python scripts/ingest_sample_data.py
```

This is much easier and will ingest both sample files!

### Option 3: Using Python Interactive Mode

1. Open Python:
   ```bash
   python
   ```

2. Type these commands one by one:
   ```python
   from app import create_app
   from app.services.file_ingestion import FileIngestionService
   app = create_app()
   app.app_context().push()
   FileIngestionService.ingest_file('data/example_format1.csv')
   ```

3. Exit Python:
   ```python
   exit()
   ```

## Step-by-Step Instructions

### For the Ingest Command:

1. **Open Command Prompt or PowerShell**
   - Press `Win + R`
   - Type `cmd` or `powershell`
   - Press Enter

2. **Navigate to project directory**
   ```cmd
   cd C:\Users\wreed\OneDrive\Desktop\PDC
   ```

3. **Activate virtual environment**
   ```cmd
   venv\Scripts\activate
   ```
   You should see `(venv)` in your prompt.

4. **Run the command**

   **Option A: Long command (one line)**
   ```cmd
   python -c "from app import create_app; from app.services.file_ingestion import FileIngestionService; app = create_app(); app.app_context().push(); FileIngestionService.ingest_file('data/example_format1.csv')"
   ```

   **Option B: Use the script (recommended)**
   ```cmd
   python scripts/ingest_sample_data.py
   ```

## Common Issues

### Issue: "python is not recognized"

**Solution**: 
- Make sure Python is installed
- Try `py` instead of `python`:
  ```cmd
  py -c "from app import create_app; ..."
  ```

### Issue: "No module named 'app'"

**Solution**:
- Make sure you're in the project root directory
- Make sure virtual environment is activated
- Install dependencies: `pip install -r requirements.txt`

### Issue: "File not found"

**Solution**:
- Check the file path is correct
- Make sure you're in the project root directory
- Verify file exists: `dir data\example_format1.csv`

### Issue: Quotes not working

**Solution**:
- In CMD, use double quotes for the whole command
- In PowerShell, you might need to escape quotes differently
- Better: Use the Python script instead!

## Recommended Approach

**Instead of typing long commands, use the provided scripts:**

```bash
# Ingest sample data (both files)
python scripts/ingest_sample_data.py

# Test SFTP connection
python scripts/test_sftp.py

# Run file ingestion from SFTP
python scripts/ingest_files.py

# Run smoke tests
python scripts/smoketest.py

# Test API key
python scripts/test_api.py
```

These scripts are much easier to use and less error-prone!

## Quick Reference

| Task | Command |
|------|---------|
| Ingest sample data | `python scripts/ingest_sample_data.py` |
| Test SFTP | `python scripts/test_sftp.py` |
| Ingest from SFTP | `python scripts/ingest_files.py` |
| Run tests | `pytest` |
| Run smoke tests | `python scripts/smoketest.py` |
| Check API key | `python scripts/test_api.py` |




