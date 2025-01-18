from flask import Flask, jsonify
from flask_cors import CORS
from alpaca_trade_api import REST
import threading
import json

class Dashboard:
    def __init__(self, config):
        self.app = Flask(__name__)
        CORS(self.app)
        self.alpaca = REST(
            key_id=config['ALPACA_API_KEY'],
            secret_key=config['ALPACA_SECRET_KEY'],
            base_url=config['ALPACA_BASE_URL']
        )
        
        self.setup_routes()
        self.running = False
        
    def setup_routes(self):
        @self.app.route('/api/dashboard')
        def dashboard_data():
            return jsonify({
                'portfolio': self.get_portfolio(),
                'news': self.get_news(),
                'analytics': self.get_analytics()
            })
            
        @self.app.route('/api/bots')
        def bot_config():
            return jsonify(self.get_bot_configurations())
            
    def get_portfolio(self):
        # Get portfolio data from Alpaca
        try:
            portfolio = self.alpaca.get_account()
            positions = self.alpaca.list_positions()
            return {
                'balance': portfolio.equity,
                'positions': [{
                    'symbol': p.symbol,
                    'qty': p.qty,
                    'market_value': p.market_value
                } for p in positions]
            }
        except Exception as e:
            return {'error': str(e)}
            
    def get_news(self):
        # Get financial news
        try:
            news = self.alpaca.get_news('AAPL', limit=10)
            return [{
                'headline': n.headline,
                'summary': n.summary,
                'url': n.url
            } for n in news]
        except Exception as e:
            return {'error': str(e)}
            
    def get_analytics(self):
        # Generate trading analytics
        return {
            'performance': self.calculate_performance(),
            'risk_metrics': self.calculate_risk_metrics()
        }
        
    def start(self):
        if not self.running:
            self.running = True
            threading.Thread(target=self.app.run).start()
            
    def stop(self):
        self.running = False
