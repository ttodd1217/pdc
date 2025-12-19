#!/usr/bin/env python3
"""
Script to trigger file ingestion.
Supports three modes:
  1. Local Disk Mode (EC2): Process all files from /home/sftp_user/uploads (RECOMMENDED for EC2)
  2. SFTP Mode: Process all files from SFTP server
  3. Event-Driven Mode: Process a single file from S3 (triggered by S3 ObjectCreated event)
"""
import sys
import os
import json
import tempfile
import boto3
import shutil

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


def ingest_from_local_disk():
    """
    Local disk mode: Process all files from /home/sftp_user/uploads (on EC2).
    This is the RECOMMENDED mode when running on EC2 with local SFTP storage.
    Files are processed automatically by cron job every 5 minutes.
    """
    logger.info("Starting local disk ingestion (EC2 mode)")
    
    uploads_dir = "/home/sftp_user/uploads"
    processed_dir = "/home/sftp_user/processed"
    
    # Create directories if they don't exist
    os.makedirs(uploads_dir, exist_ok=True)
    os.makedirs(processed_dir, exist_ok=True)
    
    try:
        # List files
        files = [f for f in os.listdir(uploads_dir) 
                if os.path.isfile(os.path.join(uploads_dir, f)) 
                and f.endswith(('.csv', '.txt', '.psv'))]
        
        logger.info(f"Found {len(files)} files to process in {uploads_dir}")
        
        if not files:
            logger.info("No files to process")
            return
        
        app = create_app(Config)
        
        with app.app_context():
            ingestion_service = FileIngestionService()
            
            for filename in files:
                file_path = os.path.join(uploads_dir, filename)
                processed_path = os.path.join(processed_dir, filename)
                
                try:
                    logger.info(f"Processing {filename}...")
                    
                    # Ingest the file
                    count = ingestion_service.ingest_file(file_path)
                    logger.info(f"Successfully ingested {filename}: {count} records")
                    
                    # Move to processed directory
                    shutil.move(file_path, processed_path)
                    logger.info(f"Moved {filename} to {processed_dir}")
                    
                except Exception as e:
                    logger.error(f"Error processing {filename}: {str(e)}")
                    # Continue with next file instead of failing completely
                    continue
        
        logger.info("Local disk ingestion completed")
        
    except Exception as e:
        logger.error(f"Error in local disk ingestion: {str(e)}", exc_info=True)
        raise


def ingest_from_sftp():
    """
    SFTP mode: Process all files from SFTP server (legacy/alternative mode).
    Use this if you want the ingestion to download from remote SFTP instead of local disk.
    """
    logger.info("Starting SFTP batch ingestion")
    
    app = create_app(Config)
    
    with app.app_context():
        worker = IngestionWorker()
        try:
            worker.process_files()
            logger.info("SFTP batch ingestion completed successfully")
            return True
        except Exception as e:
            logger.error(f"SFTP batch ingestion failed: {str(e)}", exc_info=True)
            raise


def ingest_from_s3(bucket_name, object_key):
    """
    Event-driven mode: Ingest a single file from S3.
    Triggered by S3 ObjectCreated event via EventBridge.
    
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


def main():
    """
    Main entry point.
    Determines which ingestion mode to use based on environment.
    
    Priority:
    1. INGEST_EVENT → S3 mode (single file from event)
    2. INGEST_MODE=local → Local disk mode (EC2)
    3. INGEST_MODE=sftp → SFTP mode (remote)
    4. Default → Local disk mode (EC2)
    """
    ingest_event_json = os.getenv('INGEST_EVENT')
    ingest_mode = os.getenv('INGEST_MODE', 'local').lower()
    
    if ingest_event_json:
        # Event-driven mode (S3)
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
    
    elif ingest_mode == 'sftp':
        # SFTP mode
        try:
            ingest_from_sftp()
            sys.exit(0)
        except Exception as e:
            logger.error(f"SFTP ingestion failed: {str(e)}")
            sys.exit(1)
    
    else:
        # Local disk mode (default, recommended for EC2)
        try:
            ingest_from_local_disk()
            sys.exit(0)
        except Exception as e:
            logger.error(f"Local disk ingestion failed: {str(e)}")
            sys.exit(1)


if __name__ == '__main__':
    main()




