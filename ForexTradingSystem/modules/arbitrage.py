import os
import ccxt
import logging
from decimal import Decimal
from typing import Dict, Any, Optional

class Arbitrage:
    def __init__(self):
        self.exchange = self._initialize_exchange()
        self.logger = self._setup_logger()
        self.min_profit_threshold = Decimal('0.005')  # 0.5% minimum profit
        
    def _initialize_exchange(self):
        """Initialize exchange connection with API credentials"""
        exchange = ccxt.binance({
            'apiKey': os.getenv('EXCHANGE_API_KEY'),
            'secret': os.getenv('EXCHANGE_API_SECRET'),
            'enableRateLimit': True
        })
        return exchange
        
    def _setup_logger(self):
        """Configure arbitrage logger"""
        logger = logging.getLogger('arbitrage')
        logger.setLevel(logging.INFO)
        handler = logging.FileHandler('arbitrage.log')
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        return logger
        
    def check_opportunities(self):
        """Check for arbitrage opportunities"""
        try:
            # Get order book data
            order_book = self.exchange.fetch_order_book('BTC/USDT')
            
            # Calculate potential arbitrage
            opportunity = self._find_arbitrage_opportunity(order_book)
            
            if opportunity:
                self._execute_arbitrage(opportunity)
                
        except Exception as e:
            self.logger.error(f"Error checking arbitrage opportunities: {e}")
            
    def _find_arbitrage_opportunity(self, order_book: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Find arbitrage opportunity in order book"""
        best_bid = Decimal(str(order_book['bids'][0][0]))
        best_ask = Decimal(str(order_book['asks'][0][0]))
        
        # Calculate spread
        spread = best_bid - best_ask
        
        # Check if spread meets profit threshold
        if spread > best_ask * self.min_profit_threshold:
            return {
                'bid_price': best_bid,
                'ask_price': best_ask,
                'quantity': Decimal(str(min(
                    order_book['bids'][0][1],
                    order_book['asks'][0][1]
                )))
            }
        return None
        
    def _execute_arbitrage(self, opportunity: Dict[str, Any]):
        """Execute arbitrage trade"""
        try:
            # Place buy order at ask price
            buy_order = self.exchange.create_limit_buy_order(
                'BTC/USDT',
                float(opportunity['quantity']),
                float(opportunity['ask_price'])
            )
            
            # Place sell order at bid price
            sell_order = self.exchange.create_limit_sell_order(
                'BTC/USDT',
                float(opportunity['quantity']),
                float(opportunity['bid_price'])
            )
            
            self.logger.info(f"Arbitrage executed - Buy: {buy_order}, Sell: {sell_order}")
            
        except ccxt.InsufficientFunds:
            self.logger.error("Insufficient funds to execute arbitrage")
        except ccxt.NetworkError:
            self.logger.error("Network error while executing arbitrage")
        except Exception as e:
            self.logger.error(f"Error executing arbitrage: {e}")
