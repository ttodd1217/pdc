#!/usr/bin/env python3
"""
Script to manually trigger file ingestion from SFTP server.
Can be run as a scheduled job or manually.
"""
import sys
import os

# Ensure the project root is on the Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from app import create_app
from app.config import Config
from app.services.ingestion_worker import IngestionWorker
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

def main():
    """Run file ingestion"""
    app = create_app(Config)
    
    with app.app_context():
        worker = IngestionWorker()
        try:
            worker.process_files()
            print("File ingestion completed successfully")
            sys.exit(0)
        except Exception as e:
            print(f"File ingestion failed: {str(e)}")
            logging.error(f"File ingestion failed: {str(e)}", exc_info=True)
            sys.exit(1)

if __name__ == '__main__':
    main()




