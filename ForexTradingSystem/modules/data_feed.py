import os
import ccxt
import pandas as pd
from datetime import datetime, timedelta

class DataFeed:
    def __init__(self):
        self.exchange = self._initialize_exchange()
        self.historical_data = None
        
    def _initialize_exchange(self):
        """Initialize exchange connection with API credentials"""
        exchange = ccxt.binance({
            'apiKey': os.getenv('EXCHANGE_API_KEY'),
            'secret': os.getenv('EXCHANGE_API_SECRET'),
            'enableRateLimit': True
        })
        return exchange
        
    def get_data(self):
        """Get real-time market data"""
        try:
            # Get latest OHLCV data
            timeframe = f"{int(os.getenv('DATA_FEED_INTERVAL'))}s"
            ohlcv = self.exchange.fetch_ohlcv('BTC/USDT', timeframe, limit=1)
            
            # Convert to DataFrame
            df = pd.DataFrame(ohlcv, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
            
            # Update historical data
            self._update_historical_data(df)
            
            return df
            
        except Exception as e:
            print(f"Error fetching market data: {e}")
            return pd.DataFrame()

    def _update_historical_data(self, new_data):
        """Maintain historical data for analysis"""
        if self.historical_data is None:
            self.historical_data = new_data
        else:
            self.historical_data = pd.concat([self.historical_data, new_data])
            
        # Keep only the last N days of data
        days_to_keep = int(os.getenv('HISTORICAL_DATA_DAYS'))
        cutoff = datetime.now() - timedelta(days=days_to_keep)
        self.historical_data = self.historical_data[
            self.historical_data['timestamp'] > cutoff
        ]
