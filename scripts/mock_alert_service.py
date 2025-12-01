#!/usr/bin/env python3
"""
Mock alerting service for demonstration purposes.
Shows the structure of alerts that would be sent to a real alerting service.
"""
from flask import Flask, request, jsonify
from datetime import datetime
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Store alerts in memory (in production, this would be a database or external service)
alerts = []

@app.route('/alerts', methods=['POST'])
def receive_alert():
    """Receive and log alerts"""
    data = request.json
    
    # Validate API key
    api_key = request.headers.get('X-API-Key')
    if api_key != 'alert-api-key':
        return jsonify({'error': 'Unauthorized'}), 401
    
    alert = {
        'id': len(alerts) + 1,
        'received_at': datetime.utcnow().isoformat(),
        'alert_type': data.get('alert_type'),
        'data': data.get('data'),
        'timestamp': data.get('timestamp')
    }
    
    alerts.append(alert)
    
    # Log the alert
    logging.info(f"Received alert: {alert['alert_type']} - {alert['data'].get('message', 'No message')}")
    
    # In a real system, this would:
    # - Send email/SMS notifications
    # - Create tickets in ticketing system
    # - Trigger automated remediation
    # - Store in alerting database
    
    return jsonify({
        'status': 'received',
        'alert_id': alert['id']
    }), 201

@app.route('/alerts', methods=['GET'])
def list_alerts():
    """List all received alerts"""
    return jsonify({
        'alerts': alerts,
        'count': len(alerts)
    })

@app.route('/alerts/<int:alert_id>', methods=['GET'])
def get_alert(alert_id):
    """Get a specific alert"""
    alert = next((a for a in alerts if a['id'] == alert_id), None)
    if not alert:
        return jsonify({'error': 'Alert not found'}), 404
    return jsonify(alert)

@app.route('/health', methods=['GET'])
def health():
    """Health check"""
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    print("Mock Alert Service running on http://localhost:5002")
    print("Example alerts that will be received:")
    print("1. Compliance Violation: Account with >20% holding")
    print("2. Ingestion Failure: File processing errors")
    print("3. Data Quality: Data quality issues")
    app.run(host='0.0.0.0', port=5002, debug=True)




