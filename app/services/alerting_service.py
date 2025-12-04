import os
import requests
import logging
from app.config import Config
from datetime import datetime

logger = logging.getLogger(__name__)

_NO_PROXY_DEFAULT = "localhost,127.0.0.1,::1"
if not os.environ.get("NO_PROXY"):
    os.environ["NO_PROXY"] = _NO_PROXY_DEFAULT
if not os.environ.get("no_proxy"):
    os.environ["no_proxy"] = _NO_PROXY_DEFAULT


class AlertingService:
    def __init__(self):
        self.service_url = Config.ALERT_SERVICE_URL
        self.api_key = Config.ALERT_API_KEY

    def send_alert(self, alert_type, data):
        """Send an alert to the alerting service"""
        payload = {
            "alert_type": alert_type,
            "timestamp": datetime.utcnow().isoformat(),
            "data": data,
        }

        headers = {"Content-Type": "application/json", "X-API-Key": self.api_key}

        try:
            response = requests.post(
                self.service_url, json=payload, headers=headers, timeout=5
            )
            response.raise_for_status()
            logger.info(f"Alert sent successfully: {alert_type}")
            return True
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to send alert: {str(e)}")
            return False

    def send_compliance_violation_alert(self, account_id, ticker, percentage, date):
        """Alert for compliance violation (>20% holding)"""
        return self.send_alert(
            "compliance_violation",
            {
                "account_id": account_id,
                "ticker": ticker,
                "percentage": percentage,
                "date": date,
                "threshold": 20.0,
                "severity": "high",
                "message": f"Account {account_id} has {percentage}% holding in {ticker}, exceeding 20% threshold",
            },
        )

    def send_ingestion_failure_alert(self, filename, error_message):
        """Alert for file ingestion failures"""
        return self.send_alert(
            "ingestion_failure",
            {
                "filename": filename,
                "error": error_message,
                "severity": "medium",
                "message": f"Failed to ingest file {filename}: {error_message}",
            },
        )

    def send_data_quality_alert(self, filename, issues):
        """Alert for data quality issues"""
        return self.send_alert(
            "data_quality",
            {
                "filename": filename,
                "issues": issues,
                "severity": "low",
                "message": f"Data quality issues detected in {filename}: {', '.join(issues)}",
            },
        )
