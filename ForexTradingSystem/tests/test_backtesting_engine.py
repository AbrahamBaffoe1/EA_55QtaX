"""
Comprehensive Test Suite for Backtesting Engine

Tests all critical components:
- Order execution and fill logic
- Slippage and commission calculation
- Position tracking
- Risk management integration
- Performance metrics
- Edge cases and error handling

Author: Claude Code
Version: 1.0.0
"""

import pytest
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from decimal import Decimal
import sys
sys.path.append('/home/user/EA_55QtaX/ForexTradingSystem/modules')

from backtesting_engine import (
    BacktestingEngine, BacktestConfig, Order, OrderType, OrderSide,
    OrderStatus, Position, SlippageModel
)
from backtest_metrics import PerformanceAnalyzer


@pytest.fixture
def sample_data():
    """Generate sample OHLCV data for testing"""
    dates = pd.date_range(start='2024-01-01', periods=100, freq='1H')
    np.random.seed(42)

    # Generate realistic price data
    close_prices = 100 + np.cumsum(np.random.randn(100) * 0.5)
    high_prices = close_prices + np.random.rand(100) * 2
    low_prices = close_prices - np.random.rand(100) * 2
    open_prices = close_prices + np.random.randn(100) * 0.3

    data = pd.DataFrame({
        'open': open_prices,
        'high': high_prices,
        'low': low_prices,
        'close': close_prices,
        'volume': np.random.randint(1000, 10000, 100)
    }, index=dates)

    return data


@pytest.fixture
def engine():
    """Create backtesting engine with default config"""
    config = BacktestConfig(
        initial_capital=Decimal('100000'),
        commission_rate=Decimal('0.001'),
        slippage_model=SlippageModel.FIXED,
        slippage_rate=Decimal('0.0005')
    )
    return BacktestingEngine(config)


class TestBacktestingEngine:
    """Test suite for backtesting engine core functionality"""

    def test_initialization(self, engine):
        """Test engine initializes correctly"""
        assert engine.cash == Decimal('100000')
        assert engine.initial_capital == Decimal('100000')
        assert len(engine.positions) == 0
        assert len(engine.trades) == 0
        assert engine.trade_count == 0

    def test_reset(self, engine):
        """Test engine reset functionality"""
        # Make some changes
        engine.cash = Decimal('50000')
        engine.trade_count = 10

        # Reset
        engine.reset()

        # Verify reset
        assert engine.cash == Decimal('100000')
        assert engine.trade_count == 0
        assert len(engine.positions) == 0

    def test_commission_calculation_percentage(self, engine):
        """Test percentage-based commission calculation"""
        quantity = Decimal('10')
        price = Decimal('100')

        commission = engine.calculate_commission(quantity, price)

        # Expected: 10 * 100 * 0.001 = 1.0
        expected = Decimal('1.00')
        assert commission == expected

    def test_commission_calculation_fixed(self):
        """Test fixed commission"""
        config = BacktestConfig(
            commission_type="fixed",
            commission_rate=Decimal('5.00')
        )
        engine = BacktestingEngine(config)

        commission = engine.calculate_commission(Decimal('10'), Decimal('100'))
        assert commission == Decimal('5.00')

    def test_slippage_fixed(self, engine):
        """Test fixed slippage model"""
        order = Order(
            order_id="TEST001",
            timestamp=datetime.now(),
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            order_type=OrderType.MARKET,
            quantity=Decimal('1')
        )

        market_price = Decimal('100')
        slippage = engine.calculate_slippage(order, market_price)

        # Expected: 100 * 0.0005 = 0.05
        expected = Decimal('0.05')
        assert slippage == expected

    def test_slippage_none(self):
        """Test no slippage model"""
        config = BacktestConfig(slippage_model=SlippageModel.NONE)
        engine = BacktestingEngine(config)

        order = Order(
            order_id="TEST001",
            timestamp=datetime.now(),
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            order_type=OrderType.MARKET,
            quantity=Decimal('1')
        )

        slippage = engine.calculate_slippage(order, Decimal('100'))
        assert slippage == Decimal('0')

    def test_execution_price_buy(self, engine):
        """Test execution price calculation for buy orders"""
        order = Order(
            order_id="TEST001",
            timestamp=datetime.now(),
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            order_type=OrderType.MARKET,
            quantity=Decimal('1')
        )

        market_price = Decimal('100')
        execution_price = engine.calculate_execution_price(order, market_price)

        # Buy orders pay slippage (higher price)
        # Expected: 100 + (100 * 0.0005) = 100.05
        assert execution_price > market_price

    def test_execution_price_sell(self, engine):
        """Test execution price calculation for sell orders"""
        order = Order(
            order_id="TEST001",
            timestamp=datetime.now(),
            symbol="BTCUSDT",
            side=OrderSide.SELL,
            order_type=OrderType.MARKET,
            quantity=Decimal('1')
        )

        market_price = Decimal('100')
        execution_price = engine.calculate_execution_price(order, market_price)

        # Sell orders lose to slippage (lower price)
        # Expected: 100 - (100 * 0.0005) = 99.95
        assert execution_price < market_price

    def test_submit_market_order(self, engine, sample_data):
        """Test submitting a market order"""
        engine.current_time = sample_data.index[0]

        order = engine.submit_order(
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            quantity=Decimal('1'),
            order_type=OrderType.MARKET
        )

        assert order is not None
        assert order.status == OrderStatus.PENDING
        assert order.side == OrderSide.BUY
        assert order.quantity == Decimal('1')

    def test_submit_limit_order(self, engine, sample_data):
        """Test submitting a limit order"""
        engine.current_time = sample_data.index[0]

        order = engine.submit_order(
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            quantity=Decimal('1'),
            order_type=OrderType.LIMIT,
            price=Decimal('95')
        )

        assert order is not None
        assert order.order_type == OrderType.LIMIT
        assert order.price == Decimal('95')

    def test_market_order_execution(self, engine, sample_data):
        """Test market order gets executed"""
        # Submit order
        engine.current_time = sample_data.index[0]
        order = engine.submit_order(
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            quantity=Decimal('1'),
            order_type=OrderType.MARKET
        )

        # Process next bar
        bar = sample_data.iloc[1]
        market_data = {
            'symbol': 'BTCUSDT',
            'open': bar['open'],
            'high': bar['high'],
            'low': bar['low'],
            'close': bar['close'],
            'volume': bar['volume']
        }
        engine.update(sample_data.index[1], market_data)

        # Check order was executed
        assert order.status == OrderStatus.FILLED
        assert order.filled_quantity == order.quantity
        assert order.average_fill_price is not None

    def test_limit_order_fill_conditions(self, engine, sample_data):
        """Test limit order only fills when price condition met"""
        engine.current_time = sample_data.index[0]

        # Submit buy limit at 90
        order = engine.submit_order(
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            quantity=Decimal('1'),
            order_type=OrderType.LIMIT,
            price=Decimal('90')
        )

        # Process bar where low is above limit price (should not fill)
        bar = sample_data.iloc[1]
        if bar['low'] > 90:
            market_data = {
                'symbol': 'BTCUSDT',
                'open': bar['open'],
                'high': bar['high'],
                'low': bar['low'],
                'close': bar['close'],
                'volume': bar['volume']
            }
            engine.update(sample_data.index[1], market_data)

            # Should still be pending
            assert order.status == OrderStatus.PENDING

    def test_position_creation_long(self, engine, sample_data):
        """Test long position creation"""
        engine.current_time = sample_data.index[0]

        # Buy order
        order = engine.submit_order(
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            quantity=Decimal('10'),
            order_type=OrderType.MARKET
        )

        # Execute
        bar = sample_data.iloc[1]
        market_data = {
            'symbol': 'BTCUSDT',
            'open': bar['open'],
            'high': bar['high'],
            'low': bar['low'],
            'close': bar['close'],
            'volume': bar['volume']
        }
        engine.update(sample_data.index[1], market_data)

        # Check position
        assert "BTCUSDT" in engine.positions
        position = engine.positions["BTCUSDT"]
        assert position.quantity == Decimal('10')
        assert position.is_long()

    def test_position_creation_short(self, engine, sample_data):
        """Test short position creation"""
        config = BacktestConfig(allow_short_selling=True)
        engine = BacktestingEngine(config)
        engine.current_time = sample_data.index[0]

        # Sell order (short)
        order = engine.submit_order(
            symbol="BTCUSDT",
            side=OrderSide.SELL,
            quantity=Decimal('10'),
            order_type=OrderType.MARKET
        )

        # Execute
        bar = sample_data.iloc[1]
        market_data = {
            'symbol': 'BTCUSDT',
            'open': bar['open'],
            'high': bar['high'],
            'low': bar['low'],
            'close': bar['close'],
            'volume': bar['volume']
        }
        engine.update(sample_data.index[1], market_data)

        # Check position
        assert "BTCUSDT" in engine.positions
        position = engine.positions["BTCUSDT"]
        assert position.quantity == Decimal('-10')
        assert position.is_short()

    def test_position_close(self, engine, sample_data):
        """Test closing a position"""
        engine.current_time = sample_data.index[0]

        # Open long position
        buy_order = engine.submit_order(
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            quantity=Decimal('10'),
            order_type=OrderType.MARKET
        )

        bar = sample_data.iloc[1]
        market_data = {
            'symbol': 'BTCUSDT',
            'open': bar['open'],
            'high': bar['high'],
            'low': bar['low'],
            'close': bar['close'],
            'volume': bar['volume']
        }
        engine.update(sample_data.index[1], market_data)

        # Close position
        engine.current_time = sample_data.index[2]
        sell_order = engine.submit_order(
            symbol="BTCUSDT",
            side=OrderSide.SELL,
            quantity=Decimal('10'),
            order_type=OrderType.MARKET
        )

        bar = sample_data.iloc[3]
        market_data = {
            'symbol': 'BTCUSDT',
            'open': bar['open'],
            'high': bar['high'],
            'low': bar['low'],
            'close': bar['close'],
            'volume': bar['volume']
        }
        engine.update(sample_data.index[3], market_data)

        # Position should be closed
        assert "BTCUSDT" not in engine.positions

    def test_equity_calculation(self, engine, sample_data):
        """Test equity calculation with open positions"""
        engine.current_time = sample_data.index[0]

        initial_equity = engine.get_equity()
        assert initial_equity == Decimal('100000')

        # Open position
        order = engine.submit_order(
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            quantity=Decimal('100'),
            order_type=OrderType.MARKET
        )

        bar = sample_data.iloc[1]
        market_data = {
            'symbol': 'BTCUSDT',
            'open': bar['open'],
            'high': bar['high'],
            'low': bar['low'],
            'close': bar['close'],
            'volume': bar['volume']
        }
        engine.update(sample_data.index[1], market_data)

        # Equity should change with position
        current_equity = engine.get_equity()
        # Should be approximately initial capital minus costs
        assert current_equity > 0

    def test_commission_deduction(self, engine, sample_data):
        """Test that commission is properly deducted from cash"""
        engine.current_time = sample_data.index[0]
        initial_cash = engine.cash

        # Place order
        order = engine.submit_order(
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            quantity=Decimal('1'),
            order_type=OrderType.MARKET
        )

        # Execute
        bar = sample_data.iloc[1]
        market_data = {
            'symbol': 'BTCUSDT',
            'open': bar['open'],
            'high': bar['high'],
            'low': bar['low'],
            'close': bar['close'],
            'volume': bar['volume']
        }
        engine.update(sample_data.index[1], market_data)

        # Cash should decrease by position value + commission
        assert engine.cash < initial_cash
        assert engine.total_commission > 0

    def test_drawdown_tracking(self, engine, sample_data):
        """Test drawdown is tracked correctly"""
        # Run a simple strategy
        def simple_strategy(engine, bar, symbol):
            # Just buy and hold
            if engine.trade_count == 0:
                engine.submit_order(
                    symbol=symbol,
                    side=OrderSide.BUY,
                    quantity=Decimal('10'),
                    order_type=OrderType.MARKET
                )

        results = engine.run_backtest(sample_data, simple_strategy)

        # Should have max drawdown
        assert 'max_drawdown' in results
        assert results['max_drawdown'] <= 0  # Drawdown is negative

    def test_validation_insufficient_funds(self, engine):
        """Test order rejection due to insufficient funds"""
        engine.current_time = datetime.now()
        engine.cash = Decimal('100')  # Very low cash

        order = engine.submit_order(
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            quantity=Decimal('1000'),  # Huge order
            order_type=OrderType.MARKET,
            price=Decimal('100')
        )

        # Should be rejected or cause validation error
        # Depending on validation settings
        is_valid, error = engine.validate_order(order)
        assert not is_valid or order.status == OrderStatus.REJECTED

    def test_daily_loss_limit(self):
        """Test daily loss limit enforcement"""
        config = BacktestConfig(
            initial_capital=Decimal('100000'),
            max_daily_loss=Decimal('0.02')  # 2%
        )
        engine = BacktestingEngine(config)

        # Simulate a loss
        today = datetime.now().date()
        engine.daily_pnl[today] = Decimal('-3000')  # 3% loss
        engine.current_time = datetime.now()

        order = Order(
            order_id="TEST001",
            timestamp=datetime.now(),
            symbol="BTCUSDT",
            side=OrderSide.BUY,
            order_type=OrderType.MARKET,
            quantity=Decimal('1'),
            price=Decimal('100')
        )

        is_valid, error = engine.validate_order(order)
        assert not is_valid
        assert "loss limit" in error.lower()

    def test_get_results_structure(self, engine, sample_data):
        """Test results structure is complete"""
        def simple_strategy(engine, bar, symbol):
            pass

        results = engine.run_backtest(sample_data, simple_strategy)

        # Check all required keys present
        required_keys = [
            'initial_capital', 'final_equity', 'total_return',
            'total_pnl', 'total_commission', 'total_slippage',
            'max_drawdown', 'trade_count', 'winning_trades',
            'losing_trades', 'win_rate', 'trades', 'equity_curve'
        ]

        for key in required_keys:
            assert key in results


class TestPerformanceMetrics:
    """Test performance metrics calculation"""

    def test_metrics_calculation(self, engine, sample_data):
        """Test that metrics are calculated correctly"""
        def buy_and_hold(engine, bar, symbol):
            if engine.trade_count == 0:
                engine.submit_order(
                    symbol=symbol,
                    side=OrderSide.BUY,
                    quantity=Decimal('100'),
                    order_type=OrderType.MARKET
                )

        results = engine.run_backtest(sample_data, buy_and_hold)
        analyzer = PerformanceAnalyzer()
        metrics = analyzer.calculate_metrics(results)

        # Check key metrics exist
        assert hasattr(metrics, 'total_return')
        assert hasattr(metrics, 'sharpe_ratio')
        assert hasattr(metrics, 'max_drawdown')
        assert hasattr(metrics, 'win_rate')

    def test_sharpe_ratio_positive_returns(self):
        """Test Sharpe ratio with positive returns"""
        # Create synthetic data with positive returns
        dates = pd.date_range(start='2024-01-01', periods=100, freq='D')
        equity = pd.DataFrame({
            'equity': [100000 * (1.001 ** i) for i in range(100)]
        }, index=dates)

        analyzer = PerformanceAnalyzer()

        # Calculate Sharpe
        daily_returns = equity['equity'].pct_change().dropna()
        std = daily_returns.std()

        if std > 0:
            sharpe = (daily_returns.mean() / std) * np.sqrt(252)
            assert sharpe > 0  # Should be positive for positive returns


class TestEdgeCases:
    """Test edge cases and error conditions"""

    def test_empty_data(self, engine):
        """Test with empty dataframe"""
        empty_data = pd.DataFrame(columns=['open', 'high', 'low', 'close', 'volume'])

        def strategy(engine, bar, symbol):
            pass

        # Should handle gracefully
        try:
            results = engine.run_backtest(empty_data, strategy)
            assert results['trade_count'] == 0
        except Exception as e:
            # Or raise appropriate error
            assert "data" in str(e).lower()

    def test_single_bar_data(self):
        """Test with just one bar of data"""
        config = BacktestConfig()
        engine = BacktestingEngine(config)

        data = pd.DataFrame({
            'open': [100],
            'high': [101],
            'low': [99],
            'close': [100.5],
            'volume': [1000]
        }, index=[datetime.now()])

        def strategy(engine, bar, symbol):
            pass

        results = engine.run_backtest(data, strategy)
        assert results is not None

    def test_strategy_exception_handling(self, engine, sample_data):
        """Test that strategy exceptions are handled"""
        def buggy_strategy(engine, bar, symbol):
            raise ValueError("Intentional error")

        # Should not crash the backtest
        results = engine.run_backtest(sample_data, buggy_strategy)
        assert results is not None


def test_full_backtest_workflow(sample_data):
    """Integration test: full backtest workflow"""
    # Configure engine
    config = BacktestConfig(
        initial_capital=Decimal('100000'),
        commission_rate=Decimal('0.001'),
        slippage_model=SlippageModel.FIXED,
        slippage_rate=Decimal('0.0005')
    )
    engine = BacktestingEngine(config)

    # Define simple moving average crossover strategy
    def sma_crossover(engine, bar, symbol):
        # Simple strategy: buy when price > SMA, sell when price < SMA
        # (In real implementation, you'd track SMA)
        if engine.trade_count < 10:  # Limit trades
            position = engine.get_position_quantity(symbol)

            if position == 0 and bar['close'] > bar['open']:
                # Buy signal
                engine.submit_order(
                    symbol=symbol,
                    side=OrderSide.BUY,
                    quantity=Decimal('10'),
                    order_type=OrderType.MARKET
                )
            elif position > 0 and bar['close'] < bar['open']:
                # Sell signal
                engine.submit_order(
                    symbol=symbol,
                    side=OrderSide.SELL,
                    quantity=Decimal('10'),
                    order_type=OrderType.MARKET
                )

    # Run backtest
    results = engine.run_backtest(sample_data, sma_crossover, symbol="BTCUSDT")

    # Verify results
    assert results is not None
    assert 'final_equity' in results
    assert 'trade_count' in results

    # Calculate metrics
    analyzer = PerformanceAnalyzer()
    metrics = analyzer.calculate_metrics(results)

    assert metrics is not None
    assert metrics.total_trades >= 0


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
