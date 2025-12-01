@echo off
REM Batch script to ingest sample data
REM Usage: Double-click this file or run: ingest_data.bat

echo Activating virtual environment...
call venv\Scripts\activate.bat

echo.
echo Ingesting sample data files...
echo.

python scripts/ingest_sample_data.py

echo.
echo Done! Press any key to exit...
pause >nul




