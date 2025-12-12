#!/usr/bin/env python3
"""
Script to trigger file ingestion.
Supports two modes:
  1. Scheduled/Batch Mode: Process all files from SFTP server
  2. Event-Driven Mode: Process a single file from S3 (triggered by S3 ObjectCreated event)
"""
import sys
import os
import json
import tempfile
import boto3

# Ensure the project root is on the Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from app import create_app
from app.config import Config
from app.services.ingestion_worker import IngestionWorker
from app.services.file_ingestion import FileIngestionService
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)


def ingest_from_s3(bucket_name, object_key):
    """
    Ingest a single file from S3.
    
    Args:
        bucket_name: S3 bucket name
        object_key: S3 object key (path)
    """
    logger.info(f"Starting event-driven ingestion for s3://{bucket_name}/{object_key}")
    
    try:
        # Download file from S3
        s3_client = boto3.client('s3')
        
        # Create temporary file
        with tempfile.NamedTemporaryFile(
            mode='w+b', delete=False, suffix=os.path.splitext(object_key)[1]
        ) as tmp_file:
            tmp_path = tmp_file.name
        
        # Download from S3
        logger.info(f"Downloading s3://{bucket_name}/{object_key} to {tmp_path}")
        s3_client.download_file(bucket_name, object_key, tmp_path)
        
        # Ingest the file
        app = create_app(Config)
        with app.app_context():
            ingestion_service = FileIngestionService()
            count = ingestion_service.ingest_file(tmp_path)
            logger.info(f"Successfully ingested {object_key}: {count} records processed")
        
        # Clean up
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        
        return True
        
    except Exception as e:
        logger.error(f"Error ingesting file from S3: {str(e)}", exc_info=True)
        raise


def ingest_all_files():
    """
    Scheduled/Batch mode: Process all files from SFTP server.
    """
    logger.info("Starting scheduled batch ingestion")
    
    app = create_app(Config)
    
    with app.app_context():
        worker = IngestionWorker()
        try:
            worker.process_files()
            logger.info("Batch ingestion completed successfully")
            return True
        except Exception as e:
            logger.error(f"Batch ingestion failed: {str(e)}", exc_info=True)
            raise


def main():
    """
    Main entry point.
    
    Checks for INGEST_EVENT environment variable:
    - If set: Event-driven mode (S3 file)
    - If not set: Scheduled batch mode (all SFTP files)
    """
    ingest_event_json = os.getenv('INGEST_EVENT')
    
    if ingest_event_json:
        # Event-driven mode
        try:
            event = json.loads(ingest_event_json)
            bucket = event.get('s3_bucket')
            key = event.get('s3_key')
            
            if not bucket or not key:
                logger.error(f"Invalid INGEST_EVENT: missing s3_bucket or s3_key. Event: {event}")
                sys.exit(1)
            
            ingest_from_s3(bucket, key)
            sys.exit(0)
            
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse INGEST_EVENT JSON: {str(e)}")
            sys.exit(1)
    else:
        # Scheduled batch mode
        try:
            ingest_all_files()
            sys.exit(0)
        except Exception as e:
            print(f"File ingestion failed: {str(e)}")
            sys.exit(1)


if __name__ == '__main__':
    main()




