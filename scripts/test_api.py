#!/usr/bin/env python3
"""
Quick script to test API endpoints and show the correct API key to use.
"""
import os
from app import create_app
from app.config import Config

app = create_app(Config)

print("=" * 60)
print("API Key Configuration")
print("=" * 60)
print(f"Current API Key: {Config.API_KEY}")
print()
print("To test the API, use:")
print(f'curl -H "X-API-Key: {Config.API_KEY}" "http://127.0.0.1:5001/api/blotter?date=2025-01-15"')
print()
print("Or use query parameter:")
print(f'curl "http://127.0.0.1:5001/api/blotter?date=2025-01-15&api_key={Config.API_KEY}"')
print("=" * 60)




