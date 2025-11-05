import pytest
from unittest.mock import Mock, patch, MagicMock
from decimal import Decimal
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from modules.execution import Execution

# Mock ccxt module
try:
    import ccxt
except ImportError:
    ccxt = type('ccxt', (), {
        'InsufficientFunds': type('InsufficientFunds', (Exception,), {}),
        'NetworkError': type('NetworkError', (Exception,), {})
    })()


@pytest.fixture
def mock_exchange():
    """Mock exchange object"""
    exchange = Mock()
    exchange.fetch_balance = Mock()
    exchange.create_market_order = Mock()
    return exchange


@pytest.fixture
def mock_monitoring():
    """Mock monitoring object"""
    monitoring = Mock()
    monitoring.add_trade = Mock()
    return monitoring


@pytest.fixture
def execution(mock_exchange, mock_monitoring):
    """Create Execution instance with mocked dependencies"""
    with patch('modules.execution.ccxt.binance') as mock_binance, \
         patch.dict(os.environ, {'RISK_PER_TRADE': '0.02', 'MAX_POSITION_SIZE': '0.1'}):
        mock_binance.return_value = mock_exchange
        exec_obj = Execution()
        exec_obj.monitoring = mock_monitoring
        return exec_obj


def test_execution_initialization(execution):
    """Test Execution initialization"""
    assert execution is not None
    assert execution.exchange is not None
    assert execution.logger is not None
    assert execution.monitoring is not None


def test_get_account_balance(execution, mock_exchange):
    """Test getting account balance"""
    mock_exchange.fetch_balance.return_value = {
        'free': {'USDT': 10000.0}
    }

    balance = execution._get_account_balance()

    assert balance == Decimal('10000.0')
    mock_exchange.fetch_balance.assert_called_once()


def test_calculate_position_size(execution):
    """Test position size calculation"""
    balance = Decimal('10000')

    position_size = execution._calculate_position_size(balance)

    # Should be min(10000 * 0.02, 10000 * 0.1) = min(200, 1000) = 200
    assert position_size == Decimal('200')


def test_calculate_position_size_max_constraint(execution):
    """Test position size with maximum constraint"""
    balance = Decimal('100000')

    position_size = execution._calculate_position_size(balance)

    # Should be min(100000 * 0.02, 100000 * 0.1) = min(2000, 10000) = 2000
    assert position_size == Decimal('2000')


def test_place_order_buy(execution, mock_exchange, mock_monitoring):
    """Test placing a buy order"""
    mock_exchange.create_market_order.return_value = {
        'id': '123',
        'price': 50000.0,
        'timestamp': 1234567890,
        'status': 'filled'
    }

    execution._place_order('buy', Decimal('1.5'))

    mock_exchange.create_market_order.assert_called_once_with('BTC/USDT', 'buy', 1.5)
    mock_monitoring.add_trade.assert_called_once()


def test_place_order_sell(execution, mock_exchange, mock_monitoring):
    """Test placing a sell order"""
    mock_exchange.create_market_order.return_value = {
        'id': '124',
        'price': 50000.0,
        'timestamp': 1234567890,
        'status': 'filled'
    }

    execution._place_order('sell', Decimal('2.0'))

    mock_exchange.create_market_order.assert_called_once_with('BTC/USDT', 'sell', 2.0)
    mock_monitoring.add_trade.assert_called_once()


def test_place_order_insufficient_funds(execution, mock_exchange, mock_monitoring):
    """Test placing order with insufficient funds"""
    mock_exchange.create_market_order.side_effect = ccxt.InsufficientFunds('Not enough funds')

    # Should not raise exception, but log error
    execution._place_order('buy', Decimal('1.5'))

    mock_exchange.create_market_order.assert_called_once()
    mock_monitoring.add_trade.assert_not_called()


def test_place_order_network_error(execution, mock_exchange, mock_monitoring):
    """Test placing order with network error"""
    mock_exchange.create_market_order.side_effect = ccxt.NetworkError('Connection lost')

    # Should not raise exception, but log error
    execution._place_order('buy', Decimal('1.5'))

    mock_exchange.create_market_order.assert_called_once()
    mock_monitoring.add_trade.assert_not_called()


def test_place_order_without_monitoring(execution, mock_exchange):
    """Test placing order without monitoring system"""
    execution.monitoring = None
    mock_exchange.create_market_order.return_value = {
        'id': '123',
        'price': 50000.0,
        'timestamp': 1234567890,
        'status': 'filled'
    }

    # Should not raise exception when monitoring is None
    execution._place_order('buy', Decimal('1.5'))

    mock_exchange.create_market_order.assert_called_once()


def test_execute_trades_bullish_signals(execution, mock_exchange, mock_monitoring):
    """Test executing trades with bullish signals"""
    signals = {
        'ema': 'bullish',
        'macd': 'bullish'
    }

    mock_exchange.fetch_balance.return_value = {
        'free': {'USDT': 10000.0}
    }
    mock_exchange.create_market_order.return_value = {
        'id': '123',
        'price': 50000.0,
        'timestamp': 1234567890
    }

    execution.execute_trades(signals)

    mock_exchange.create_market_order.assert_called_once()
    call_args = mock_exchange.create_market_order.call_args[0]
    assert call_args[1] == 'buy'  # Should be a buy order


def test_execute_trades_bearish_signals(execution, mock_exchange, mock_monitoring):
    """Test executing trades with bearish signals"""
    signals = {
        'ema': 'bearish',
        'macd': 'bearish'
    }

    mock_exchange.fetch_balance.return_value = {
        'free': {'USDT': 10000.0}
    }
    mock_exchange.create_market_order.return_value = {
        'id': '123',
        'price': 50000.0,
        'timestamp': 1234567890
    }

    execution.execute_trades(signals)

    mock_exchange.create_market_order.assert_called_once()
    call_args = mock_exchange.create_market_order.call_args[0]
    assert call_args[1] == 'sell'  # Should be a sell order


def test_execute_trades_mixed_signals(execution, mock_exchange):
    """Test executing trades with mixed signals"""
    signals = {
        'ema': 'bullish',
        'macd': 'bearish'
    }

    mock_exchange.fetch_balance.return_value = {
        'free': {'USDT': 10000.0}
    }

    execution.execute_trades(signals)

    # Should not place any orders with mixed signals
    mock_exchange.create_market_order.assert_not_called()


def test_execute_trades_exception(execution, mock_exchange):
    """Test executing trades with exception"""
    signals = {
        'ema': 'bullish',
        'macd': 'bullish'
    }

    mock_exchange.fetch_balance.side_effect = Exception('API Error')

    # Should not raise exception, but log error
    execution.execute_trades(signals)

    mock_exchange.fetch_balance.assert_called_once()
