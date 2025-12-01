import pytest
from datetime import date
from app import create_app, db
from app.config import Config
from app.services.file_ingestion import FileIngestionService
from app.models import Trade

class TestConfig(Config):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'

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

class TestFileIngestion:
    def test_parse_format1(self, app):
        file_content = """TradeDate,AccountID,Ticker,Quantity,Price,TradeType,SettlementDate
2025-01-15,ACC001,AAPL,100,185.50,BUY,2025-01-17
2025-01-15,ACC001,MSFT,50,420.25,BUY,2025-01-17"""
        
        trades = FileIngestionService.parse_format1(file_content)
        
        assert len(trades) == 2
        assert trades[0].account_id == 'ACC001'
        assert trades[0].ticker == 'AAPL'
        assert trades[0].quantity == 100
        assert trades[0].price == 185.50
        assert trades[0].market_value == 18550.0
    
    def test_parse_format1_sell(self, app):
        file_content = """TradeDate,AccountID,Ticker,Quantity,Price,TradeType,SettlementDate
2025-01-15,ACC003,TSLA,150,238.45,SELL,2025-01-17"""
        
        trades = FileIngestionService.parse_format1(file_content)
        
        assert len(trades) == 1
        assert trades[0].quantity == -150
        assert trades[0].market_value == -35767.5
    
    def test_parse_format2(self, app):
        file_content = """20250115|ACC001|AAPL|100|18550.00|CUSTODIAN_A
20250115|ACC001|MSFT|50|21012.50|CUSTODIAN_A"""
        
        trades = FileIngestionService.parse_format2(file_content)
        
        assert len(trades) == 2
        assert trades[0].account_id == 'ACC001'
        assert trades[0].ticker == 'AAPL'
        assert trades[0].quantity == 100
        assert trades[0].market_value == 18550.00
        assert trades[0].source_system == 'CUSTODIAN_A'
    
    def test_detect_format(self, app):
        format1_content = "TradeDate,AccountID,Ticker,Quantity,Price,TradeType,SettlementDate"
        format2_content = "20250115|ACC001|AAPL|100|18550.00|CUSTODIAN_A"
        
        assert FileIngestionService.detect_format(format1_content) == 'format1'
        assert FileIngestionService.detect_format(format2_content) == 'format2'
    
    def test_ingest_file_format1(self, app):
        import tempfile
        import os
        
        file_content = """TradeDate,AccountID,Ticker,Quantity,Price,TradeType,SettlementDate
2025-01-15,ACC001,AAPL,100,185.50,BUY,2025-01-17"""
        
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.csv') as f:
            f.write(file_content)
            tmp_path = f.name
        
        try:
            count = FileIngestionService.ingest_file(tmp_path)
            assert count == 1
            
            trade = Trade.query.first()
            assert trade.account_id == 'ACC001'
            assert trade.ticker == 'AAPL'
        finally:
            os.remove(tmp_path)
    
    def test_ingest_file_format2(self, app):
        import tempfile
        import os
        
        file_content = """20250115|ACC001|AAPL|100|18550.00|CUSTODIAN_A"""
        
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            f.write(file_content)
            tmp_path = f.name
        
        try:
            count = FileIngestionService.ingest_file(tmp_path)
            assert count == 1
            
            trade = Trade.query.first()
            assert trade.account_id == 'ACC001'
            assert trade.ticker == 'AAPL'
            assert trade.source_system == 'CUSTODIAN_A'
        finally:
            os.remove(tmp_path)




