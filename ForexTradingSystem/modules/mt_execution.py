import requests
import json
import time
import logging
from typing import Dict, Optional

class MTExecution:
    def __init__(self, api_url: str, api_key: str):
        self.api_url = api_url
        self.api_key = api_key
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json'
        })
        self.logger = self._setup_logger()
        
    def _setup_logger(self):
        logger = logging.getLogger('mt_execution')
        logger.setLevel(logging.INFO)
        handler = logging.FileHandler('mt_execution.log')
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        return logger
        
    def place_order(self, symbol: str, order_type: str, volume: float, 
                   price: Optional[float] = None, stop_loss: Optional[float] = None,
                   take_profit: Optional[float] = None) -> Dict:
        """Place an order on MetaTrader 4"""
        try:
            # Convert order type to MT4 format
            mt4_order_type = 0 if order_type.upper() == 'BUY' else 1
            
            payload = {
                'symbol': symbol,
                'type': mt4_order_type,
                'volume': volume,
                'price': price,
                'stoploss': stop_loss,
                'takeprofit': take_profit
            }
            
            response = self.session.post(
                f'{self.api_url}/order',
                data=json.dumps(payload)
            )
            response.raise_for_status()
            return response.json()
            
        except Exception as e:
            self.logger.error(f"Error placing order: {e}")
            raise
            
    def close_order(self, ticket: int) -> Dict:
        """Close an existing order in MT4"""
        try:
            response = self.session.delete(
                f'{self.api_url}/order/{ticket}'
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            self.logger.error(f"Error closing order: {e}")
            raise
            
    def get_account_info(self) -> Dict:
        """Get MT4 account information"""
        try:
            response = self.session.get(f'{self.api_url}/account')
            response.raise_for_status()
            return response.json()
        except Exception as e:
            self.logger.error(f"Error getting account info: {e}")
            raise
            
    def get_positions(self) -> Dict:
        """Get open positions in MT4"""
        try:
            response = self.session.get(f'{self.api_url}/positions')
            response.raise_for_status()
            return response.json()
        except Exception as e:
            self.logger.error(f"Error getting positions: {e}")
            raise
            
    def modify_order(self, ticket: int, stop_loss: Optional[float] = None,
                    take_profit: Optional[float] = None) -> Dict:
        """Modify an existing order in MT4"""
        try:
            payload = {
                'stoploss': stop_loss,
                'takeprofit': take_profit
            }
            
            response = self.session.patch(
                f'{self.api_url}/order/{ticket}',
                data=json.dumps(payload)
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            self.logger.error(f"Error modifying order: {e}")
            raise
            
    def execute_mql(self, code: str, params: Optional[Dict] = None) -> Dict:
        """Execute custom MQL4 code"""
        try:
            payload = {
                'code': code,
                'params': params or {}
            }
            
            response = self.session.post(
                f'{self.api_url}/mql/execute',
                data=json.dumps(payload)
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            self.logger.error(f"Error executing MQL code: {e}")
            raise
            
    def calculate_indicator(self, symbol: str, timeframe: str, 
                          indicator_name: str, params: Dict) -> Dict:
        """Calculate technical indicator using MQL4"""
        try:
            payload = {
                'symbol': symbol,
                'timeframe': timeframe,
                'indicator': indicator_name,
                'params': params
            }
            
            response = self.session.post(
                f'{self.api_url}/mql/indicator',
                data=json.dumps(payload)
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            self.logger.error(f"Error calculating indicator: {e}")
            raise
            
    def backtest_strategy(self, code: str, params: Dict, 
                         start_date: str, end_date: str) -> Dict:
        """Backtest a custom MQL4 strategy"""
        try:
            payload = {
                'code': code,
                'params': params,
                'start_date': start_date,
                'end_date': end_date
            }
            
            response = self.session.post(
                f'{self.api_url}/mql/backtest',
                data=json.dumps(payload)
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            self.logger.error(f"Error backtesting strategy: {e}")
            raise

    def execute_trades(self, signals: list) -> None:
        """Execute trades based on trading signals for MT4"""
        try:
            for signal in signals:
                # Convert signal to MT4 order parameters
                order_type = 'BUY' if signal['direction'] == 'long' else 'SELL'
                volume = signal['volume']
                price = signal.get('price')
                stop_loss = signal.get('stop_loss')
                take_profit = signal.get('take_profit')
                
                # Place order through MetaTrader 4 API
                order_response = self.place_order(
                    symbol=signal['symbol'],
                    order_type=order_type,
                    volume=volume,
                    price=price,
                    stop_loss=stop_loss,
                    take_profit=take_profit
                )
                
                # Log order execution
                self.logger.info(f"Executed trade: {order_response}")
                
                # Update monitoring if available
                if hasattr(self, 'monitoring'):
                    self.monitoring.update_trades(order_response)
                    
        except Exception as e:
            self.logger.error(f"Error executing trades: {e}")
            raise
