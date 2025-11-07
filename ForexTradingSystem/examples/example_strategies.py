"""
Example Trading Strategies for Backtesting

This module demonstrates how to create strategies for the backtesting engine.
These examples show best practices and common patterns.

Strategies included:
1. Moving Average Crossover
2. RSI Mean Reversion
3. MACD Trend Following
4. Bollinger Bands Breakout
5. Multi-Timeframe Strategy

Author: Claude Code
Version: 1.0.0
"""

import sys
sys.path.append('/home/user/EA_55QtaX/ForexTradingSystem/modules')

from decimal import Decimal
import pandas as pd
import numpy as np
from backtesting_engine import BacktestingEngine, OrderSide, OrderType
from collections import deque


class MovingAverageCrossover:
    """
    Classic moving average crossover strategy

    Rules:
    - Buy when fast MA crosses above slow MA
    - Sell when fast MA crosses below slow MA
    - Use risk management for position sizing
    """

    def __init__(self, fast_period: int = 10, slow_period: int = 30):
        """
        Initialize strategy

        Args:
            fast_period: Fast moving average period
            slow_period: Slow moving average period
        """
        self.fast_period = fast_period
        self.slow_period = slow_period
        self.price_history = deque(maxlen=slow_period)
        self.position_size = Decimal('0')

    def __call__(self, engine: BacktestingEngine, bar: pd.Series, symbol: str):
        """Strategy logic executed on each bar"""
        # Track price history
        self.price_history.append(bar['close'])

        # Need enough history
        if len(self.price_history) < self.slow_period:
            return

        # Calculate moving averages
        prices = list(self.price_history)
        fast_ma = np.mean(prices[-self.fast_period:])
        slow_ma = np.mean(prices[-self.slow_period:])

        # Previous values for crossover detection
        if len(self.price_history) >= self.slow_period + 1:
            prev_prices = prices[:-1]
            prev_fast_ma = np.mean(prev_prices[-self.fast_period:])
            prev_slow_ma = np.mean(prev_prices[-self.slow_period:])
        else:
            return

        # Get current position
        current_position = engine.get_position_quantity(symbol)

        # Calculate position size (2% risk)
        equity = engine.get_equity()
        risk_amount = equity * Decimal('0.02')
        position_size = risk_amount / Decimal(str(bar['close']))

        # Crossover signals
        bullish_cross = prev_fast_ma <= prev_slow_ma and fast_ma > slow_ma
        bearish_cross = prev_fast_ma >= prev_slow_ma and fast_ma < slow_ma

        # Entry signals
        if bullish_cross and current_position == 0:
            # Buy signal
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.BUY,
                quantity=position_size,
                order_type=OrderType.MARKET
            )

        elif bearish_cross and current_position > 0:
            # Close long position
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.SELL,
                quantity=current_position,
                order_type=OrderType.MARKET
            )


class RSIMeanReversion:
    """
    RSI-based mean reversion strategy

    Rules:
    - Buy when RSI < 30 (oversold)
    - Sell when RSI > 70 (overbought)
    - Exit when RSI returns to 50 (neutral)
    """

    def __init__(self, rsi_period: int = 14, oversold: int = 30, overbought: int = 70):
        """
        Initialize strategy

        Args:
            rsi_period: RSI calculation period
            oversold: Oversold threshold
            overbought: Overbought threshold
        """
        self.rsi_period = rsi_period
        self.oversold = oversold
        self.overbought = overbought
        self.price_history = deque(maxlen=rsi_period + 1)

    def calculate_rsi(self) -> float:
        """Calculate RSI from price history"""
        if len(self.price_history) < self.rsi_period + 1:
            return 50  # Neutral

        prices = list(self.price_history)
        deltas = np.diff(prices)

        gains = deltas.copy()
        losses = deltas.copy()
        gains[gains < 0] = 0
        losses[losses > 0] = 0
        losses = abs(losses)

        avg_gain = np.mean(gains[-self.rsi_period:])
        avg_loss = np.mean(losses[-self.rsi_period:])

        if avg_loss == 0:
            return 100

        rs = avg_gain / avg_loss
        rsi = 100 - (100 / (1 + rs))

        return rsi

    def __call__(self, engine: BacktestingEngine, bar: pd.Series, symbol: str):
        """Strategy logic"""
        self.price_history.append(bar['close'])

        if len(self.price_history) < self.rsi_period + 1:
            return

        rsi = self.calculate_rsi()
        current_position = engine.get_position_quantity(symbol)

        # Position sizing
        equity = engine.get_equity()
        risk_amount = equity * Decimal('0.02')
        position_size = risk_amount / Decimal(str(bar['close']))

        # Mean reversion signals
        if rsi < self.oversold and current_position == 0:
            # Oversold - buy
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.BUY,
                quantity=position_size,
                order_type=OrderType.MARKET
            )

        elif rsi > self.overbought and current_position > 0:
            # Overbought - sell
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.SELL,
                quantity=current_position,
                order_type=OrderType.MARKET
            )

        elif current_position > 0 and rsi > 50:
            # Exit long when returning to neutral
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.SELL,
                quantity=current_position,
                order_type=OrderType.MARKET
            )


class BollingerBandsBreakout:
    """
    Bollinger Bands breakout strategy

    Rules:
    - Buy when price breaks above upper band
    - Sell when price breaks below lower band
    - Exit when price returns to middle band
    """

    def __init__(self, period: int = 20, std_dev: float = 2.0):
        """
        Initialize strategy

        Args:
            period: Moving average period
            std_dev: Standard deviation multiplier
        """
        self.period = period
        self.std_dev = std_dev
        self.price_history = deque(maxlen=period)

    def calculate_bands(self, current_price: float):
        """Calculate Bollinger Bands"""
        if len(self.price_history) < self.period:
            return current_price, current_price, current_price

        prices = list(self.price_history)
        middle = np.mean(prices)
        std = np.std(prices)

        upper = middle + (self.std_dev * std)
        lower = middle - (self.std_dev * std)

        return lower, middle, upper

    def __call__(self, engine: BacktestingEngine, bar: pd.Series, symbol: str):
        """Strategy logic"""
        current_price = bar['close']
        self.price_history.append(current_price)

        if len(self.price_history) < self.period:
            return

        lower, middle, upper = self.calculate_bands(current_price)
        current_position = engine.get_position_quantity(symbol)

        # Position sizing
        equity = engine.get_equity()
        risk_amount = equity * Decimal('0.02')
        position_size = risk_amount / Decimal(str(bar['close']))

        # Breakout signals
        if current_price > upper and current_position == 0:
            # Upper band breakout - buy
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.BUY,
                quantity=position_size,
                order_type=OrderType.MARKET
            )

        elif current_price < middle and current_position > 0:
            # Return to middle band - close long
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.SELL,
                quantity=current_position,
                order_type=OrderType.MARKET
            )


class MACDTrendFollowing:
    """
    MACD trend following strategy

    Rules:
    - Buy when MACD crosses above signal line
    - Sell when MACD crosses below signal line
    - Use histogram for strength confirmation
    """

    def __init__(self, fast: int = 12, slow: int = 26, signal: int = 9):
        """
        Initialize strategy

        Args:
            fast: Fast EMA period
            slow: Slow EMA period
            signal: Signal line period
        """
        self.fast_period = fast
        self.slow_period = slow
        self.signal_period = signal
        self.price_history = deque(maxlen=slow + signal)
        self.macd_history = deque(maxlen=signal)

    def calculate_ema(self, prices: list, period: int) -> float:
        """Calculate EMA"""
        if len(prices) < period:
            return np.mean(prices)

        multiplier = 2 / (period + 1)
        ema = prices[0]

        for price in prices[1:]:
            ema = (price - ema) * multiplier + ema

        return ema

    def calculate_macd(self):
        """Calculate MACD, signal line, and histogram"""
        if len(self.price_history) < self.slow_period:
            return 0, 0, 0

        prices = list(self.price_history)

        # Calculate MACD line
        fast_ema = self.calculate_ema(prices[-self.fast_period:], self.fast_period)
        slow_ema = self.calculate_ema(prices[-self.slow_period:], self.slow_period)
        macd_line = fast_ema - slow_ema

        # Store MACD history for signal line
        self.macd_history.append(macd_line)

        if len(self.macd_history) < self.signal_period:
            return macd_line, 0, macd_line

        # Calculate signal line
        signal_line = self.calculate_ema(list(self.macd_history), self.signal_period)

        # Calculate histogram
        histogram = macd_line - signal_line

        return macd_line, signal_line, histogram

    def __call__(self, engine: BacktestingEngine, bar: pd.Series, symbol: str):
        """Strategy logic"""
        self.price_history.append(bar['close'])

        if len(self.price_history) < self.slow_period + 1:
            return

        # Calculate current and previous MACD
        macd, signal, histogram = self.calculate_macd()

        # Need previous values for crossover
        if len(self.macd_history) < self.signal_period + 1:
            return

        prev_macd_hist = list(self.macd_history)
        if len(prev_macd_hist) >= 2:
            prev_macd = prev_macd_hist[-2]
            prev_signal = self.calculate_ema(prev_macd_hist[:-1], self.signal_period)
        else:
            return

        current_position = engine.get_position_quantity(symbol)

        # Position sizing
        equity = engine.get_equity()
        risk_amount = equity * Decimal('0.02')
        position_size = risk_amount / Decimal(str(bar['close']))

        # Crossover signals
        bullish_cross = prev_macd <= prev_signal and macd > signal
        bearish_cross = prev_macd >= prev_signal and macd < signal

        if bullish_cross and current_position == 0:
            # Buy signal
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.BUY,
                quantity=position_size,
                order_type=OrderType.MARKET
            )

        elif bearish_cross and current_position > 0:
            # Sell signal
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.SELL,
                quantity=current_position,
                order_type=OrderType.MARKET
            )


# Example: How to use these strategies
if __name__ == "__main__":
    print("Example Trading Strategies")
    print("=" * 80)
    print()
    print("Available strategies:")
    print("1. MovingAverageCrossover - Classic trend following")
    print("2. RSIMeanReversion - Mean reversion on oversold/overbought")
    print("3. BollingerBandsBreakout - Breakout strategy")
    print("4. MACDTrendFollowing - MACD crossover")
    print()
    print("See README_BACKTESTING.md for usage examples")
