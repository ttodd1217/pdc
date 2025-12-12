import logging
import os
from pathlib import Path

import paramiko

from app.config import Config


logger = logging.getLogger(__name__)


class SFTPService:
    def __init__(self):
        self.host = Config.SFTP_HOST
        self.port = int(Config.SFTP_PORT)
        self.username = Config.SFTP_USERNAME
        self.key_path = os.path.expanduser(Config.SFTP_KEY_PATH)
        self.remote_path = Config.SFTP_REMOTE_PATH
        self.processed_path = Config.SFTP_PROCESSED_PATH

    def _get_ssh_client(self):
        """Create and return an SSH client with key authentication"""
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        try:
            key_file = Path(self.key_path)
            if not key_file.exists():
                logger.error(f"SSH key not found at {self.key_path}")
                raise FileNotFoundError(f"SSH key not found at {self.key_path}")

            private_key = paramiko.Ed25519Key.from_private_key_file(self.key_path)
            ssh.connect(
                hostname=self.host,
                port=self.port,
                username=self.username,
                pkey=private_key,
                timeout=30,
                allow_agent=False,
                look_for_keys=False,
            )
            logger.info("Successfully connected to SFTP server")
            return ssh
        except FileNotFoundError:
            logger.error(f"SSH key not found at {self.key_path}")
            raise
        except Exception as e:
            logger.error(
                f"Failed to connect to SFTP server {self.host}:{self.port} - {e}"
            )
            raise

    def list_files(self):
        """List all files in the remote directory"""
        ssh = self._get_ssh_client()
        sftp = ssh.open_sftp()

        try:
            files = sftp.listdir(self.remote_path)
            logger.info(f"Found files in {self.remote_path}: {files}")
            return [f for f in files if f.endswith((".csv", ".txt", ".psv"))]
        finally:
            sftp.close()
            ssh.close()

    def download_file(self, remote_filename, local_path):
        """Download a file from SFTP server"""
        ssh = self._get_ssh_client()
        sftp = ssh.open_sftp()

        try:
            remote_filepath = f"{self.remote_path}/{remote_filename}"
            sftp.get(remote_filepath, local_path)
            logger.info(f"Downloaded {remote_filename} to {local_path}")
            return local_path
        finally:
            sftp.close()
            ssh.close()

    def move_to_processed(self, filename, local_source_path=None):
        """Move a file to the processed directory"""
        ssh = self._get_ssh_client()
        sftp = ssh.open_sftp()

        try:
            remote_filepath = f"{self.remote_path}/{filename}"
            processed_filepath = f"{self.processed_path}/{filename}"

            # Create processed directory if it doesn't exist
            try:
                sftp.mkdir(self.processed_path)
            except IOError:
                pass  # Directory already exists

            # Some SFTP servers (for example atmoz/sftp) mount uploads and
            # processed directories on separate volumes. Server-side rename may
            # fail with "Failure" in that case. If we still have the local
            # copy that we just ingested, upload it to the processed directory
            # and then delete the original remote copy. Otherwise, fall back
            # to a rename operation.
            if local_source_path and os.path.exists(local_source_path):
                sftp.put(local_source_path, processed_filepath)
                sftp.remove(remote_filepath)
                logger.info(
                    (
                        f"Uploaded local copy of {filename} to processed directory "
                        "and removed remote upload"
                    )
                )
            else:
                # Remove existing file if already processed to avoid rename errors
                try:
                    sftp.stat(processed_filepath)
                    sftp.remove(processed_filepath)
                except IOError:
                    pass

                sftp.rename(remote_filepath, processed_filepath)
                logger.info(f"Moved {filename} to processed directory")
        finally:
            sftp.close()
            ssh.close()
