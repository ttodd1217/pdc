import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY") or "dev-secret-key-change-in-production"
    SQLALCHEMY_DATABASE_URI = (
        os.environ.get("DATABASE_URL")
        or "postgresql://postgres:postgres@localhost:5432/pdc_db"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # API Security
    API_KEY = os.environ.get("API_KEY") or "dev-api-key-change-in-production"

    # SFTP Configuration
    SFTP_HOST = os.environ.get("SFTP_HOST") or "localhost"
    SFTP_PORT = int(os.environ.get("SFTP_PORT") or 22)
    SFTP_USERNAME = os.environ.get("SFTP_USERNAME") or "sftp_user"
    SFTP_KEY_PATH = os.environ.get("SFTP_KEY_PATH") or "~/.ssh/id_rsa"
    SFTP_REMOTE_PATH = os.environ.get("SFTP_REMOTE_PATH") or "/uploads"
    SFTP_PROCESSED_PATH = os.environ.get("SFTP_PROCESSED_PATH") or "/processed"

    # Alerting Configuration
    ALERT_SERVICE_URL = (
        os.environ.get("ALERT_SERVICE_URL") or "http://localhost:5001/alerts"
    )
    ALERT_API_KEY = os.environ.get("ALERT_API_KEY") or "alert-api-key"
