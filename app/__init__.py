from flask import Flask, jsonify
from flask_sqlalchemy import SQLAlchemy
from app.config import Config

db = SQLAlchemy()

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)
    
    db.init_app(app)
    
    from app.routes import api_bp, register_health_routes
    from app.middleware import api_key_middleware
    
    app.before_request(api_key_middleware)
    app.register_blueprint(api_bp, url_prefix='/api')
    
    # Register health routes directly on app (no auth required)
    register_health_routes(app)
    
    @app.route('/')
    def root():
        return jsonify({
            'service': 'Portfolio Data Clearinghouse',
            'version': '1.0.0',
            'endpoints': {
                'blotter': '/api/blotter?date=YYYY-MM-DD',
                'positions': '/api/positions?date=YYYY-MM-DD',
                'alarms': '/api/alarms?date=YYYY-MM-DD',
                'health': '/health',
                'metrics': '/metrics'
            }
        })
    
    with app.app_context():
        db.create_all()
    
    return app

