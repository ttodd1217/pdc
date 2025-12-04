import csv
import io
from datetime import datetime
from app import db
from app.models import Trade
import logging

logger = logging.getLogger(__name__)


class FileIngestionService:
    @staticmethod
    def parse_format1(file_content):
        """Parse CSV format: TradeDate,AccountID,Ticker,Quantity,Price,TradeType,SettlementDate"""
        trades = []
        reader = csv.DictReader(io.StringIO(file_content))

        for row in reader:
            try:
                trade_date = datetime.strptime(row["TradeDate"], "%Y-%m-%d").date()
                settlement_date = (
                    datetime.strptime(row["SettlementDate"], "%Y-%m-%d").date()
                    if row.get("SettlementDate")
                    else None
                )

                quantity = int(row["Quantity"])
                price = float(row["Price"])
                market_value = quantity * price

                # Handle SELL trades (negative quantity)
                if row.get("TradeType", "").upper() == "SELL":
                    quantity = -abs(quantity)
                    market_value = -abs(market_value)

                trade = Trade(
                    trade_date=trade_date,
                    account_id=row["AccountID"],
                    ticker=row["Ticker"],
                    quantity=quantity,
                    price=price,
                    market_value=market_value,
                    trade_type=row.get("TradeType", "BUY"),
                    settlement_date=settlement_date,
                )
                trades.append(trade)
            except Exception as e:
                logger.error(f"Error parsing row {row}: {str(e)}")
                continue

        return trades

    @staticmethod
    def parse_format2(file_content):
        """Parse pipe-delimited format: REPORT_DATE|ACCOUNT_ID|SECURITY_TICKER|SHARES|MARKET_VALUE|SOURCE_SYSTEM"""
        trades = []
        lines = file_content.strip().split("\n")

        for line in lines:
            if not line.strip():
                continue

            try:
                parts = line.split("|")
                if len(parts) < 6:
                    continue

                # Parse date from YYYYMMDD format
                date_str = parts[0]
                trade_date = datetime.strptime(date_str, "%Y%m%d").date()

                shares = int(parts[3])
                market_value = float(parts[4])

                trade = Trade(
                    trade_date=trade_date,
                    account_id=parts[1],
                    ticker=parts[2],
                    quantity=shares,
                    market_value=market_value,
                    price=abs(market_value / shares) if shares != 0 else None,
                    source_system=parts[5] if len(parts) > 5 else None,
                )
                trades.append(trade)
            except Exception as e:
                logger.error(f"Error parsing line {line}: {str(e)}")
                continue

        return trades

    @staticmethod
    def detect_format(file_content):
        """Detect file format based on content"""
        first_line = file_content.strip().split("\n")[0] if file_content.strip() else ""

        if "|" in first_line:
            return "format2"
        elif "," in first_line and "TradeDate" in first_line:
            return "format1"
        else:
            raise ValueError("Unknown file format")

    @staticmethod
    def ingest_file(file_path):
        """Ingest a file and save trades to database"""
        with open(file_path, "r", encoding="utf-8") as f:
            file_content = f.read()

        format_type = FileIngestionService.detect_format(file_content)

        if format_type == "format1":
            trades = FileIngestionService.parse_format1(file_content)
        elif format_type == "format2":
            trades = FileIngestionService.parse_format2(file_content)
        else:
            raise ValueError(f"Unsupported format: {format_type}")

        # Save to database
        try:
            for trade in trades:
                db.session.add(trade)
            db.session.commit()
            logger.info(f"Successfully ingested {len(trades)} trades from {file_path}")
            return len(trades)
        except Exception as e:
            db.session.rollback()
            logger.error(f"Error saving trades to database: {str(e)}")
            raise
