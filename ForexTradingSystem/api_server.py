import os
import json
import logging
from flask import Flask, jsonify, request
from flask_socketio import SocketIO
from flask_cors import CORS
from dotenv import load_dotenv
from modules.data_feed import DataFeed
from modules.signal_generator import SignalGenerator
from modules.mt_execution import MTExecution
from modules.risk_management import RiskManager
from modules.hedging import Hedging
from modules.arbitrage import Arbitrage
from modules.monitoring import Monitoring

# Load environment variables
load_dotenv()

class APIServer:
    def __init__(self):
        self.app = Flask(__name__)
        CORS(self.app)
        self.socketio = SocketIO(self.app, cors_allowed_origins="*")
        self.logger = self._setup_logger()
        
        # Initialize trading system components
        self.data_feed = DataFeed()
        self.signal_generator = SignalGenerator()
        self.monitoring = Monitoring()
        self.execution = MTExecution(
            api_url=os.getenv('MT_API_URL'),
            api_key=os.getenv('MT_API_KEY')
        )
        self.risk_manager = RiskManager()
        self.hedging = Hedging()
        self.arbitrage = Arbitrage()
        
        self.setup_routes()
        self.setup_socket_events()
        
    def _setup_logger(self):
        logger = logging.getLogger('api_server')
        logger.setLevel(logging.INFO)
        handler = logging.FileHandler('api_server.log')
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        return logger
        
    def setup_routes(self):
        @self.app.route('/api/dashboard', methods=['GET'])
        def get_dashboard():
            try:
                return jsonify({
                    'portfolio': self.get_portfolio(),
                    'news': self.get_news(),
                    'analytics': self.get_analytics()
                })
            except Exception as e:
                self.logger.error(f"Dashboard error: {e}")
                return jsonify({'error': str(e)}), 500
                
        @self.app.route('/api/bots', methods=['GET'])
        def get_bots():
            try:
                return jsonify(self.get_bot_configurations())
            except Exception as e:
                self.logger.error(f"Bots error: {e}")
                return jsonify({'error': str(e)}), 500
                
        # Add other required endpoints here
        
    def setup_socket_events(self):
        @self.socketio.on('connect')
        def handle_connect():
            self.logger.info('Client connected')
            
        @self.socketio.on('disconnect')
        def handle_disconnect():
            self.logger.info('Client disconnected')
            
        # Add other socket events here
        
    def start(self):
        self.socketio.run(self.app, 
                         host=os.getenv('API_HOST', '0.0.0.0'),
                         port=int(os.getenv('API_PORT', 5000)))
                         
    def stop(self):
        self.socketio.stop()

if __name__ == "__main__":
    api_server = APIServer()
    api_server.start()
