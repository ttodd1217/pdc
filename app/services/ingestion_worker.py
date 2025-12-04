import logging
import os
import tempfile

from app.services.alerting_service import AlertingService
from app.services.file_ingestion import FileIngestionService
from app.services.sftp_service import SFTPService

logger = logging.getLogger(__name__)


class IngestionWorker:
    def __init__(self):
        self.sftp_service = SFTPService()
        self.ingestion_service = FileIngestionService()
        self.alerting_service = AlertingService()

    def process_files(self):
        """Process all files from SFTP server"""
        try:
            files = self.sftp_service.list_files()
            logger.info(f"Found {len(files)} files to process")

            for filename in files:
                try:
                    self.process_file(filename)
                except Exception as e:
                    logger.error(f"Error processing file {filename}: {str(e)}")
                    self.alerting_service.send_ingestion_failure_alert(filename, str(e))
        except Exception as e:
            logger.error(f"Error listing files from SFTP: {str(e)}")
            raise

    def process_file(self, filename):
        """Process a single file"""
        with tempfile.NamedTemporaryFile(
            mode="w+", delete=False, suffix=".tmp"
        ) as tmp_file:
            tmp_path = tmp_file.name

        try:
            # Download file
            self.sftp_service.download_file(filename, tmp_path)

            # Ingest file
            count = self.ingestion_service.ingest_file(tmp_path)
            logger.info(f"Successfully processed {filename}: {count} trades ingested")

            # Move to processed directory (using the local copy we already downloaded)
            self.sftp_service.move_to_processed(filename, local_source_path=tmp_path)

        except Exception as e:
            logger.error(f"Error processing {filename}: {str(e)}")
            raise
        finally:
            # Clean up temp file
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
