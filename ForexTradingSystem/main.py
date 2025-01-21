import eventlet
eventlet.monkey_patch()

import os
import sys
import logging
from decimal import Decimal
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_socketio import SocketIO
from flask_cors import CORS
import eventlet
eventlet.monkey_patch()

# Load environment variables from .env file
load_dotenv()
from modules.data_feed import DataFeed
from modules.signal_generator import SignalGenerator
from modules.mt_execution import MTExecution
from modules.risk_management import RiskManager
from modules.hedging import Hedging
from modules.arbitrage import Arbitrage
from modules.monitoring import Monitoring

# Initialize API server
app = Flask(__name__)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*")

# Authentication middleware
@app.before_request
def authenticate_request():
    # Skip authentication for health check
    if request.path == '/health':
        return
    
    # Get API key from headers
    api_key = request.headers.get('X-API-KEY')
    if not api_key or api_key != os.getenv('API_KEY'):
        return jsonify({'error': 'Unauthorized'}), 401
        
    # Get JWT token from headers
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return jsonify({'error': 'Unauthorized'}), 401
        
    token = auth_header.split(' ')[1]
    try:
        # Verify JWT token
        import jwt
        decoded = jwt.decode(
            token,
            os.getenv('JWT_SECRET'),
            algorithms=['HS256']
        )
        request.user = decoded
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'Token expired'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': 'Invalid token'}), 401

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'})

@app.route('/api/status', methods=['GET'])
def get_system_status():
    return jsonify({
        'trading_active': trading_system is not None,
        'last_trade': trading_system.execution.last_trade if trading_system else None,
        'risk_parameters': trading_system.risk_manager.get_current_risk() if trading_system else None
    })

@app.route('/api/control/start', methods=['POST'])
def start_trading():
    if trading_system:
        trading_system.logger.info("Trading started via API")
        return jsonify({'status': 'started'})
    return jsonify({'error': 'Trading system not initialized'}), 500

@app.route('/api/control/stop', methods=['POST'])
def stop_trading():
    if trading_system:
        trading_system.logger.info("Trading stopped via API")
        return jsonify({'status': 'stopped'})
    return jsonify({'error': 'Trading system not initialized'}), 500

# WebSocket event handlers
@socketio.on('connect')
def handle_connect():
    socketio.emit('system_status', {
        'status': 'connected',
        'trading_active': trading_system is not None
    })

@socketio.on('subscribe_market_data')
def handle_market_data_subscription():
    if trading_system:
        trading_system.data_feed.add_subscriber(request.sid)

@socketio.on('unsubscribe_market_data')
def handle_market_data_unsubscription():
    if trading_system:
        trading_system.data_feed.remove_subscriber(request.sid)

@socketio.on('subscribe_trades')
def handle_trade_subscription():
    if trading_system:
        trading_system.execution.add_subscriber(request.sid)

@socketio.on('unsubscribe_trades')
def handle_trade_unsubscription():
    if trading_system:
        trading_system.execution.remove_subscriber(request.sid)

class TradingSystem:
    def __init__(self):
        self.logger = self._setup_logger()
        self.data_feed = DataFeed()
        self.signal_generator = SignalGenerator()
        self.monitoring = Monitoring()
        # Initialize MetaTrader execution
        self.execution = MTExecution(
            api_url=os.getenv('MT_API_URL'),
            api_key=os.getenv('MT_API_KEY')
        )
        self.execution.monitoring = self.monitoring  # Set monitoring reference
        self.risk_manager = RiskManager()
        self.hedging = Hedging()
        self.arbitrage = Arbitrage()
        
        # Start monitoring in separate thread
        import threading
        self.monitoring_thread = threading.Thread(
            target=self.monitoring.run,
            daemon=True
        )
        self.monitoring_thread.start()
        
    def _setup_logger(self):
        """Configure main application logger"""
        logger = logging.getLogger('trading_system')
        logger.setLevel(logging.INFO)
        handler = logging.FileHandler('trading_system.log')
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        return logger
        
    def run(self):
        """Main trading system loop"""
        self.logger.info("Starting trading system")
        
        while True:
            try:
                # Check risk parameters before proceeding
                if not self.risk_manager.update_risk_parameters():
                    self.logger.warning("Risk parameters exceeded. Stopping trading.")
                    break
                    
                # Get market data
                data = self.data_feed.get_market_data()
                
                # Generate trading signals
                signals = self.signal_generator.generate_signals(data)
                
                # Execute trades if signals are valid
                if signals:
                    self.execution.execute_trades(signals)
                    
                # Manage hedging positions
                self.hedging.manage_hedges()
                
                # Check for arbitrage opportunities
                self.arbitrage.check_opportunities()
                
                # Sleep before next iteration
                time.sleep(60)
                
            except KeyboardInterrupt:
                self.logger.info("Shutting down trading system")
                break
            except Exception as e:
                self.logger.error(f"Error in main loop: {e}")
                time.sleep(60)

if __name__ == "__main__":
    # Initialize trading system
    trading_system = TradingSystem()
    
    # Start trading system in separate thread
    import threading
    trading_thread = threading.Thread(
        target=trading_system.run,
        daemon=True
    )
    trading_thread.start()
    
    # Start API server
    socketio.run(
        app,
        host=os.getenv('API_HOST'),
        port=int(os.getenv('API_PORT')),
        debug=False
    )
