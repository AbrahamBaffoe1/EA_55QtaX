import pandas as pd
import pandas_ta as ta
from typing import Dict, Any

class SignalGenerator:
    def __init__(self):
        self.indicators = {
            'rsi': {'length': 14},
            'ema': {'length': 20},
            'macd': {'fast': 12, 'slow': 26, 'signal': 9},
            'atr': {'length': 14}
        }
        
    def generate_signals(self, data: pd.DataFrame) -> Dict[str, Any]:
        """Generate trading signals based on technical indicators"""
        if data.empty:
            return {}
            
        signals = {}
        
        # Calculate indicators
        for indicator, params in self.indicators.items():
            if indicator == 'rsi':
                data['rsi'] = ta.rsi(data['close'], length=params['length'])
            elif indicator == 'ema':
                data['ema'] = ta.ema(data['close'], length=params['length'])
            elif indicator == 'macd':
                macd = ta.macd(data['close'], 
                             fast=params['fast'],
                             slow=params['slow'],
                             signal=params['signal'])
                data = pd.concat([data, macd], axis=1)
            elif indicator == 'atr':
                data['atr'] = ta.atr(data['high'], 
                                   data['low'], 
                                   data['close'], 
                                   length=params['length'])
        
        # Generate signals
        signals['rsi'] = self._generate_rsi_signal(data)
        signals['ema'] = self._generate_ema_signal(data)
        signals['macd'] = self._generate_macd_signal(data)
        signals['atr'] = data['atr'].iloc[-1]
        
        return signals
        
    def _generate_rsi_signal(self, data: pd.DataFrame) -> str:
        """Generate RSI-based signal"""
        last_rsi = data['rsi'].iloc[-1]
        if last_rsi > 70:
            return 'overbought'
        elif last_rsi < 30:
            return 'oversold'
        return 'neutral'
        
    def _generate_ema_signal(self, data: pd.DataFrame) -> str:
        """Generate EMA-based signal"""
        last_close = data['close'].iloc[-1]
        last_ema = data['ema'].iloc[-1]
        if last_close > last_ema:
            return 'bullish'
        return 'bearish'
        
    def _generate_macd_signal(self, data: pd.DataFrame) -> str:
        """Generate MACD-based signal"""
        if data['MACD_12_26_9'].iloc[-1] > data['MACDs_12_26_9'].iloc[-1]:
            return 'bullish'
        return 'bearish'
