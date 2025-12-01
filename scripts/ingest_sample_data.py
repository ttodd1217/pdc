#!/usr/bin/env python3
"""
Simple script to ingest sample data files.
Usage: python scripts/ingest_sample_data.py
"""
import sys
import os

# Add project root to Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)

from app import create_app
from app.services.file_ingestion import FileIngestionService

def ingest_file(file_path):
    """Ingest a single file"""
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        return False
    
    app = create_app()
    with app.app_context():
        try:
            count = FileIngestionService.ingest_file(file_path)
            print(f"✅ Successfully ingested {count} trades from {file_path}")
            return True
        except Exception as e:
            print(f"❌ Error ingesting {file_path}: {str(e)}")
            return False

def main():
    """Main function"""
    print("=" * 60)
    print("Sample Data Ingestion")
    print("=" * 60)
    
    files = [
        'data/example_format1.csv',
        'data/example_format2.txt'
    ]
    
    success_count = 0
    for file_path in files:
        if ingest_file(file_path):
            success_count += 1
        print()
    
    print("=" * 60)
    if success_count == len(files):
        print(f"✅ All {len(files)} files ingested successfully!")
    else:
        print(f"⚠️  {success_count} of {len(files)} files ingested")
    print("=" * 60)
    
    return 0 if success_count == len(files) else 1

if __name__ == '__main__':
    sys.exit(main())

