from datetime import datetime

from flask import Blueprint, jsonify, request
from sqlalchemy import case, func

from app import db
from app.models import Trade

api_bp = Blueprint("api", __name__)


def register_health_routes(app):
    """Register health check routes directly on app (no auth)"""

    @app.route("/health", methods=["GET"])
    def health_check():
        """Health check endpoint for observability"""
        try:
            # Check database connection
            db.session.execute(db.text("SELECT 1"))
            db_status = "healthy"
        except Exception as e:
            db_status = f"unhealthy: {str(e)}"

        return jsonify(
            {
                "status": "healthy" if db_status == "healthy" else "degraded",
                "database": db_status,
                "timestamp": datetime.utcnow().isoformat(),
            }
        )

    @app.route("/metrics", methods=["GET"])
    def metrics():
        """Basic metrics endpoint for observability"""
        total_trades = Trade.query.count()
        latest_trade = Trade.query.order_by(Trade.trade_date.desc()).first()

        return jsonify(
            {
                "total_trades": total_trades,
                "latest_trade_date": (
                    latest_trade.trade_date.isoformat() if latest_trade else None
                ),
                "timestamp": datetime.utcnow().isoformat(),
            }
        )


@api_bp.route("/blotter", methods=["GET"])
def get_blotter():
    """Returns the data from the reports in a simplified format for the given date"""
    date_str = request.args.get("date")

    if not date_str:
        return jsonify({"error": "date parameter is required"}), 400

    try:
        query_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        return jsonify({"error": "Invalid date format. Use YYYY-MM-DD"}), 400

    trades = Trade.query.filter_by(trade_date=query_date).all()

    result = {
        "date": date_str,
        "records": [trade.to_dict() for trade in trades],
        "count": len(trades),
    }

    return jsonify(result)


@api_bp.route("/positions", methods=["GET"])
def get_positions():
    """Returns the percentage of funds by ticker for each account for the given date"""
    date_str = request.args.get("date")

    if not date_str:
        return jsonify({"error": "date parameter is required"}), 400

    try:
        query_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        return jsonify({"error": "Invalid date format. Use YYYY-MM-DD"}), 400

    # Calculate total market value per account (use absolute values)
    account_totals = (
        db.session.query(
            Trade.account_id,
            func.sum(func.abs(Trade.market_value)).label("total_value"),
        )
        .filter(Trade.trade_date == query_date)
        .group_by(Trade.account_id)
        .subquery()
    )

    # Calculate positions with percentages (use absolute values for calculations)
    positions = (
        db.session.query(
            Trade.account_id,
            Trade.ticker,
            func.sum(func.abs(Trade.market_value)).label("ticker_value"),
            func.abs(account_totals.c.total_value).label("total_value"),
        )
        .join(account_totals, Trade.account_id == account_totals.c.account_id)
        .filter(Trade.trade_date == query_date)
        .group_by(Trade.account_id, Trade.ticker, account_totals.c.total_value)
        .all()
    )

    result = {"date": date_str, "positions": []}

    for pos in positions:
        percentage = (
            (float(pos.ticker_value) / float(pos.total_value) * 100)
            if pos.total_value
            else 0
        )
        result["positions"].append(
            {
                "account_id": pos.account_id,
                "ticker": pos.ticker,
                "market_value": float(pos.ticker_value),
                "percentage": round(percentage, 2),
            }
        )

    return jsonify(result)


@api_bp.route("/alarms", methods=["GET"])
def get_alarms():
    """Returns true for any account that has over 20% of any ticker for the given date"""
    date_str = request.args.get("date")

    if not date_str:
        return jsonify({"error": "date parameter is required"}), 400

    try:
        query_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        return jsonify({"error": "Invalid date format. Use YYYY-MM-DD"}), 400

    # Calculate total market value per account (use absolute values)
    account_totals = (
        db.session.query(
            Trade.account_id,
            func.sum(func.abs(Trade.market_value)).label("total_value"),
        )
        .filter(Trade.trade_date == query_date)
        .group_by(Trade.account_id)
        .subquery()
    )

    # Find positions over 20% (use absolute values for calculations)
    violations = (
        db.session.query(
            Trade.account_id,
            Trade.ticker,
            func.sum(func.abs(Trade.market_value)).label("ticker_value"),
            func.abs(account_totals.c.total_value).label("total_value"),
        )
        .join(account_totals, Trade.account_id == account_totals.c.account_id)
        .filter(Trade.trade_date == query_date)
        .group_by(Trade.account_id, Trade.ticker, account_totals.c.total_value)
        .having(
            (
                func.sum(func.abs(Trade.market_value))
                / func.abs(account_totals.c.total_value)
                * 100
            )
            > 20
        )
        .all()
    )

    result = {"date": date_str, "alarms": []}

    for violation in violations:
        percentage = (
            (float(violation.ticker_value) / float(violation.total_value) * 100)
            if violation.total_value
            else 0
        )
        result["alarms"].append(
            {
                "account_id": violation.account_id,
                "ticker": violation.ticker,
                "percentage": round(percentage, 2),
                "violation": True,
            }
        )

    return jsonify(result)
