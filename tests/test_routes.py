from datetime import date

import pytest

from app import create_app, db
from app.config import Config
from app.models import Trade


class TestConfig(Config):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    API_KEY = "test-api-key"


@pytest.fixture
def app():
    app = create_app(TestConfig)
    with app.app_context():
        db.create_all()
        yield app
        db.drop_all()


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def sample_trades(app):
    """Create sample trades for testing"""
    trades = [
        Trade(
            trade_date=date(2025, 1, 15),
            account_id="ACC001",
            ticker="AAPL",
            quantity=100,
            price=185.50,
            market_value=18550.00,
            trade_type="BUY",
        ),
        Trade(
            trade_date=date(2025, 1, 15),
            account_id="ACC001",
            ticker="MSFT",
            quantity=50,
            price=420.25,
            market_value=21012.50,
            trade_type="BUY",
        ),
        Trade(
            trade_date=date(2025, 1, 15),
            account_id="ACC002",
            ticker="AAPL",
            quantity=200,
            price=185.50,
            market_value=37100.00,
            trade_type="BUY",
        ),
        # Create a violation: 60% of account in one ticker
        Trade(
            trade_date=date(2025, 1, 15),
            account_id="ACC003",
            ticker="NVDA",
            quantity=1000,
            price=505.30,
            market_value=505300.00,
            trade_type="BUY",
        ),
        Trade(
            trade_date=date(2025, 1, 15),
            account_id="ACC003",
            ticker="TSLA",
            quantity=200,
            price=238.45,
            market_value=47690.00,
            trade_type="BUY",
        ),
    ]

    for trade in trades:
        db.session.add(trade)
    db.session.commit()

    return trades


class TestRoutes:
    def test_blotter_missing_api_key(self, client):
        response = client.get("/api/blotter?date=2025-01-15")
        assert response.status_code == 401

    def test_blotter_success(self, client, sample_trades):
        response = client.get(
            "/api/blotter?date=2025-01-15", headers={"X-API-Key": "test-api-key"}
        )
        assert response.status_code == 200
        data = response.get_json()
        assert data["date"] == "2025-01-15"
        assert data["count"] == 5
        assert len(data["records"]) == 5

    def test_blotter_invalid_date(self, client):
        response = client.get(
            "/api/blotter?date=invalid", headers={"X-API-Key": "test-api-key"}
        )
        assert response.status_code == 400

    def test_positions_success(self, client, sample_trades):
        response = client.get(
            "/api/positions?date=2025-01-15", headers={"X-API-Key": "test-api-key"}
        )
        assert response.status_code == 200
        data = response.get_json()
        assert data["date"] == "2025-01-15"
        assert len(data["positions"]) > 0

        # Check that percentages are calculated
        for pos in data["positions"]:
            assert "percentage" in pos
            assert "account_id" in pos
            assert "ticker" in pos

    def test_alarms_success(self, client, sample_trades):
        response = client.get(
            "/api/alarms?date=2025-01-15", headers={"X-API-Key": "test-api-key"}
        )
        assert response.status_code == 200
        data = response.get_json()
        assert data["date"] == "2025-01-15"

        # ACC003 should have NVDA > 20%
        violations = [
            a
            for a in data["alarms"]
            if a["account_id"] == "ACC003" and a["ticker"] == "NVDA"
        ]
        assert len(violations) > 0
        assert violations[0]["percentage"] > 20
        assert violations[0]["violation"] is True

    def test_health_check(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        data = response.get_json()
        assert "status" in data
        assert "database" in data

    def test_metrics(self, client, sample_trades):
        response = client.get("/metrics")
        assert response.status_code == 200
        data = response.get_json()
        assert "total_trades" in data
        assert data["total_trades"] == 5
