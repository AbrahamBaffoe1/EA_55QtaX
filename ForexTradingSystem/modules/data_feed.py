import os
import logging
import ccxt
import pandas as pd
from datetime import datetime, timedelta

class DataFeed:
    def __init__(self):
        self.logger = self._setup_logger()
        self.exchange = self._initialize_exchange()
        self.historical_data = None
        self.subscribers = set()

    def _setup_logger(self):
        """Configure data feed logger"""
        logger = logging.getLogger('data_feed')
        logger.setLevel(logging.INFO)
        handler = logging.FileHandler('data_feed.log')
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        return logger
        
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
            timeframe = f"{int(os.getenv('DATA_FEED_INTERVAL', '60'))}s"
            ohlcv = self.exchange.fetch_ohlcv('BTC/USDT', timeframe, limit=1)

            # Convert to DataFrame
            df = pd.DataFrame(ohlcv, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')

            # Update historical data
            self._update_historical_data(df)

            return df

        except ccxt.NetworkError as e:
            self.logger.error(f"Network error fetching market data: {e}")
            return pd.DataFrame()
        except ccxt.ExchangeError as e:
            self.logger.error(f"Exchange error fetching market data: {e}")
            return pd.DataFrame()
        except Exception as e:
            self.logger.error(f"Unexpected error fetching market data: {e}")
            return pd.DataFrame()

    def get_market_data(self):
        """Alias for get_data() for compatibility"""
        return self.get_data()

    def _update_historical_data(self, new_data):
        """Maintain historical data for analysis"""
        if self.historical_data is None:
            self.historical_data = new_data
        else:
            self.historical_data = pd.concat([self.historical_data, new_data])

        # Keep only the last N days of data
        days_to_keep = int(os.getenv('HISTORICAL_DATA_DAYS', '30'))
        cutoff = datetime.now() - timedelta(days=days_to_keep)
        self.historical_data = self.historical_data[
            self.historical_data['timestamp'] > cutoff
        ]

    def add_subscriber(self, subscriber_id):
        """Add a subscriber for real-time market data updates"""
        self.subscribers.add(subscriber_id)
        self.logger.info(f"Added subscriber: {subscriber_id}")

    def remove_subscriber(self, subscriber_id):
        """Remove a subscriber from market data updates"""
        self.subscribers.discard(subscriber_id)
        self.logger.info(f"Removed subscriber: {subscriber_id}")
