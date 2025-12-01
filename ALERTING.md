# Alerting Service Documentation

This document describes the alerting service integration and the types of alerts sent by the PDC system.

## Alert Service Endpoint

The alerting service endpoint is configurable via the `ALERT_SERVICE_URL` environment variable. The service expects POST requests with JSON payloads.

## Authentication

All alerts are sent with an API key in the `X-API-Key` header:
```
X-API-Key: <ALERT_API_KEY>
```

## Alert Types

### 1. Compliance Violation Alert

**Trigger**: When any account has a holding exceeding 20% of the account value in a single ticker.

**Alert Type**: `compliance_violation`

**Severity**: `high`

**Payload Example**:
```json
{
  "alert_type": "compliance_violation",
  "timestamp": "2025-01-15T10:30:00.000Z",
  "data": {
    "account_id": "ACC003",
    "ticker": "NVDA",
    "percentage": 91.4,
    "date": "2025-01-15",
    "threshold": 20.0,
    "severity": "high",
    "message": "Account ACC003 has 91.4% holding in NVDA, exceeding 20% threshold"
  }
}
```

**Use Cases**:
- Immediate notification to compliance team
- Automatic ticket creation in ticketing system
- Email/SMS to portfolio managers
- Dashboard alert in monitoring system

### 2. Ingestion Failure Alert

**Trigger**: When file processing fails due to errors (parsing, database, network, etc.).

**Alert Type**: `ingestion_failure`

**Severity**: `medium`

**Payload Example**:
```json
{
  "alert_type": "ingestion_failure",
  "timestamp": "2025-01-15T08:15:00.000Z",
  "data": {
    "filename": "trades_20250115.csv",
    "error": "Database connection timeout",
    "severity": "medium",
    "message": "Failed to ingest file trades_20250115.csv: Database connection timeout"
  }
}
```

**Use Cases**:
- Notification to operations team
- Automatic retry mechanism trigger
- Log aggregation in monitoring system
- Escalation if multiple failures occur

### 3. Data Quality Alert

**Trigger**: When data quality issues are detected (missing fields, invalid values, etc.).

**Alert Type**: `data_quality`

**Severity**: `low`

**Payload Example**:
```json
{
  "alert_type": "data_quality",
  "timestamp": "2025-01-15T09:00:00.000Z",
  "data": {
    "filename": "positions_20250115.txt",
    "issues": [
      "Missing price for 3 trades",
      "Invalid date format in row 45",
      "Negative quantity without SELL trade type"
    ],
    "severity": "low",
    "message": "Data quality issues detected in positions_20250115.txt: Missing price for 3 trades, Invalid date format in row 45, Negative quantity without SELL trade type"
  }
}
```

**Use Cases**:
- Data quality dashboard updates
- Weekly reports to data team
- Automated data validation workflows
- Historical trend analysis

## Mock Alert Service

A mock alert service is provided in `scripts/mock_alert_service.py` for testing and demonstration:

```bash
python scripts/mock_alert_service.py
```

The mock service:
- Receives and logs all alerts
- Stores alerts in memory
- Provides endpoints to view received alerts
- Demonstrates the expected API structure

## Production Alert Service Integration

In production, replace the mock service with one of:

1. **PagerDuty**: For on-call alerting
   - Create PagerDuty service
   - Use PagerDuty Events API v2
   - Map severity levels to PagerDuty urgency

2. **Datadog**: For monitoring and alerting
   - Use Datadog Events API
   - Create monitors based on alert types
   - Set up notification channels

3. **AWS SNS/SQS**: For AWS-native alerting
   - Create SNS topics for each alert type
   - Subscribe email/SMS/Lambda functions
   - Use SQS for reliable delivery

4. **CloudWatch Alarms**: For AWS monitoring
   - Create CloudWatch custom metrics
   - Set up alarms with thresholds
   - Configure SNS notifications

5. **Custom Service**: Build your own
   - Implement the same API structure
   - Add business logic for routing
   - Integrate with internal systems

## Alert Routing Example

Example routing logic for a custom alert service:

```python
def route_alert(alert):
    alert_type = alert['alert_type']
    severity = alert['data']['severity']
    
    if alert_type == 'compliance_violation':
        # High priority - notify immediately
        send_sms(compliance_team)
        create_ticket(alert)
        update_dashboard(alert)
    
    elif alert_type == 'ingestion_failure':
        # Medium priority - notify operations
        send_email(operations_team)
        trigger_retry(alert['data']['filename'])
    
    elif alert_type == 'data_quality':
        # Low priority - log and report
        log_to_database(alert)
        add_to_weekly_report(alert)
```

## Testing Alerts

Test alerts can be sent using the mock service:

```bash
# Start mock service
python scripts/mock_alert_service.py

# In another terminal, test compliance alert
curl -X POST http://localhost:5001/alerts \
  -H "Content-Type: application/json" \
  -H "X-API-Key: alert-api-key" \
  -d '{
    "alert_type": "compliance_violation",
    "timestamp": "2025-01-15T10:30:00Z",
    "data": {
      "account_id": "ACC003",
      "ticker": "NVDA",
      "percentage": 91.4,
      "date": "2025-01-15",
      "threshold": 20.0,
      "severity": "high",
      "message": "Account ACC003 has 91.4% holding in NVDA"
    }
  }'
```




