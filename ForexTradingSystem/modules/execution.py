import os
import ccxt
import logging
from decimal import Decimal
from typing import Dict, Any

class Execution:
    def __init__(self):
        self.exchange = self._initialize_exchange()
        self.logger = self._setup_logger()
        self.monitoring = None  # Will be set by main system
        self.subscribers = set()
        self.last_trade = None
        
    def _initialize_exchange(self):
        """Initialize exchange connection with API credentials"""
        exchange = ccxt.binance({
            'apiKey': os.getenv('EXCHANGE_API_KEY'),
            'secret': os.getenv('EXCHANGE_API_SECRET'),
            'enableRateLimit': True
        })
        return exchange
        
    def _setup_logger(self):
        """Configure execution logger"""
        logger = logging.getLogger('execution')
        logger.setLevel(logging.INFO)
        handler = logging.FileHandler('execution.log')
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        return logger
        
    def execute_trades(self, signals: Dict[str, Any]):
        """Execute trades based on generated signals"""
        try:
            # Get account balance
            balance = self._get_account_balance()
            
            # Calculate position size
            position_size = self._calculate_position_size(balance)
            
            # Execute trade based on signals
            if signals.get('ema') == 'bullish' and signals.get('macd') == 'bullish':
                self._place_order('buy', position_size)
            elif signals.get('ema') == 'bearish' and signals.get('macd') == 'bearish':
                self._place_order('sell', position_size)
                
        except Exception as e:
            self.logger.error(f"Error executing trade: {e}")
            
    def _get_account_balance(self) -> Decimal:
        """Get available account balance"""
        balance = self.exchange.fetch_balance()
        return Decimal(str(balance['free']['USDT']))
        
    def _calculate_position_size(self, balance: Decimal) -> Decimal:
        """Calculate position size based on risk parameters"""
        risk_per_trade = Decimal(os.getenv('RISK_PER_TRADE'))
        max_position_size = Decimal(os.getenv('MAX_POSITION_SIZE'))
        
        # Calculate position size based on risk per trade
        position_size = balance * risk_per_trade
        
        # Ensure position size doesn't exceed maximum allowed
        return min(position_size, balance * max_position_size)
        
    def _place_order(self, side: str, amount: Decimal):
        """Place market order with proper error handling"""
        try:
            symbol = 'BTC/USDT'
            order = self.exchange.create_market_order(symbol, side, float(amount))
            self.logger.info(f"Order executed: {order}")

            # Store last trade
            trade_data = {
                'symbol': symbol,
                'side': side,
                'amount': float(amount),
                'price': order.get('price'),
                'timestamp': order.get('timestamp')
            }
            self.last_trade = trade_data

            # Send trade data to monitoring system
            if self.monitoring:
                self.monitoring.add_trade(trade_data)

            # Notify subscribers
            self._notify_subscribers(trade_data)

        except ccxt.InsufficientFunds as e:
            self.logger.error(f"Insufficient funds to place order: {e}")
        except ccxt.NetworkError as e:
            self.logger.error(f"Network error while placing order: {e}")
        except Exception as e:
            self.logger.error(f"Error placing order: {e}")

    def add_subscriber(self, subscriber_id):
        """Add a subscriber for trade execution updates"""
        self.subscribers.add(subscriber_id)
        self.logger.info(f"Added trade subscriber: {subscriber_id}")

    def remove_subscriber(self, subscriber_id):
        """Remove a subscriber from trade execution updates"""
        self.subscribers.discard(subscriber_id)
        self.logger.info(f"Removed trade subscriber: {subscriber_id}")

    def _notify_subscribers(self, trade_data):
        """Notify all subscribers about a new trade"""
        # This would typically emit to websocket subscribers
        # Implementation depends on the socketio instance
        pass
