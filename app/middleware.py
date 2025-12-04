from flask import request, jsonify, current_app
from app.config import Config


def api_key_middleware():
    # Skip authentication for health check endpoints
    if request.path in ["/health", "/metrics", "/"]:
        return None

    api_key = request.headers.get("X-API-Key") or request.args.get("api_key")
    expected_key = current_app.config.get("API_KEY", Config.API_KEY)

    if not api_key or api_key != expected_key:
        return jsonify({"error": "Unauthorized: Invalid or missing API key"}), 401

    return None
