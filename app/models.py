from app import db
from datetime import datetime
from sqlalchemy import Index

class Trade(db.Model):
    __tablename__ = 'trades'
    
    id = db.Column(db.Integer, primary_key=True)
    trade_date = db.Column(db.Date, nullable=False, index=True)
    account_id = db.Column(db.String(50), nullable=False, index=True)
    ticker = db.Column(db.String(20), nullable=False, index=True)
    quantity = db.Column(db.Integer, nullable=False)
    price = db.Column(db.Numeric(15, 2), nullable=True)
    market_value = db.Column(db.Numeric(15, 2), nullable=True)
    trade_type = db.Column(db.String(10), nullable=True)  # BUY/SELL
    settlement_date = db.Column(db.Date, nullable=True)
    source_system = db.Column(db.String(50), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    __table_args__ = (
        Index('idx_trade_date_account', 'trade_date', 'account_id'),
        Index('idx_trade_date_ticker', 'trade_date', 'ticker'),
    )
    
    def to_dict(self):
        return {
            'id': self.id,
            'trade_date': self.trade_date.isoformat() if self.trade_date else None,
            'account_id': self.account_id,
            'ticker': self.ticker,
            'quantity': self.quantity,
            'price': float(self.price) if self.price else None,
            'market_value': float(self.market_value) if self.market_value else None,
            'trade_type': self.trade_type,
            'settlement_date': self.settlement_date.isoformat() if self.settlement_date else None,
            'source_system': self.source_system,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }




