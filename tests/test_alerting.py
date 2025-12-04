import pytest
from unittest.mock import patch, MagicMock
from app.services.alerting_service import AlertingService


class TestAlertingService:
    def test_send_compliance_violation_alert(self):
        service = AlertingService()

        with patch("app.services.alerting_service.requests.post") as mock_post:
            mock_response = MagicMock()
            mock_response.raise_for_status = MagicMock()
            mock_post.return_value = mock_response

            result = service.send_compliance_violation_alert(
                "ACC001", "AAPL", 25.5, "2025-01-15"
            )

            assert result is True
            mock_post.assert_called_once()
            call_args = mock_post.call_args
            assert call_args[1]["json"]["alert_type"] == "compliance_violation"
            assert call_args[1]["json"]["data"]["account_id"] == "ACC001"
            assert call_args[1]["json"]["data"]["percentage"] == 25.5

    def test_send_ingestion_failure_alert(self):
        service = AlertingService()

        with patch("app.services.alerting_service.requests.post") as mock_post:
            mock_response = MagicMock()
            mock_response.raise_for_status = MagicMock()
            mock_post.return_value = mock_response

            result = service.send_ingestion_failure_alert("file.csv", "Parse error")

            assert result is True
            call_args = mock_post.call_args
            assert call_args[1]["json"]["alert_type"] == "ingestion_failure"
            assert call_args[1]["json"]["data"]["filename"] == "file.csv"

    def test_send_data_quality_alert(self):
        service = AlertingService()

        with patch("app.services.alerting_service.requests.post") as mock_post:
            mock_response = MagicMock()
            mock_response.raise_for_status = MagicMock()
            mock_post.return_value = mock_response

            result = service.send_data_quality_alert(
                "file.csv", ["Missing price", "Invalid date"]
            )

            assert result is True
            call_args = mock_post.call_args
            assert call_args[1]["json"]["alert_type"] == "data_quality"
            assert len(call_args[1]["json"]["data"]["issues"]) == 2
