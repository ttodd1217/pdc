# Scripts

## smoketest.py

Smoke test script for validating API endpoints. Can be run locally or in CI/CD pipeline.

Usage:
```bash
export API_URL=http://your-api-url
export API_KEY=your-api-key
python scripts/smoketest.py
```

## ingest_files.py

Manual file ingestion script. Processes files from SFTP server and ingests into database.

Usage:
```bash
python scripts/ingest_files.py
```

## mock_alert_service.py

Mock alerting service for demonstration. Shows the structure of alerts that would be sent.

Usage:
```bash
python scripts/mock_alert_service.py
```

The mock service will receive and log alerts. In production, this would be replaced with:
- PagerDuty
- Datadog
- CloudWatch Alarms
- Custom alerting service
- Email/SMS notifications




