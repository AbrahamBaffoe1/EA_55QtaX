import pytest
from unittest.mock import Mock, patch, MagicMock
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Mock pandas if not available
try:
    import pandas as pd
except ImportError:
    pd = None
    pytest.skip("pandas not installed", allow_module_level=True)

from modules.monitoring import Monitoring


@pytest.fixture
def monitoring():
    """Create Monitoring instance"""
    return Monitoring()


def test_monitoring_initialization(monitoring):
    """Test Monitoring initialization"""
    assert monitoring is not None
    assert monitoring.logger is not None
    assert monitoring.app is not None
    assert isinstance(monitoring.trade_history, pd.DataFrame)
    assert list(monitoring.trade_history.columns) == [
        'timestamp', 'pair', 'side', 'price', 'quantity', 'pnl'
    ]


def test_monitoring_initial_trade_history_empty(monitoring):
    """Test that initial trade history is empty"""
    assert len(monitoring.trade_history) == 0


def test_add_trade(monitoring):
    """Test adding a trade to history"""
    trade_data = {
        'timestamp': '2023-01-01 10:00:00',
        'pair': 'BTC/USDT',
        'side': 'buy',
        'price': 50000.0,
        'quantity': 1.5,
        'pnl': 100.0
    }

    monitoring.add_trade(trade_data)

    assert len(monitoring.trade_history) == 1
    assert monitoring.trade_history.iloc[0]['pair'] == 'BTC/USDT'
    assert monitoring.trade_history.iloc[0]['side'] == 'buy'
    assert monitoring.trade_history.iloc[0]['price'] == 50000.0


def test_add_multiple_trades(monitoring):
    """Test adding multiple trades"""
    trades = [
        {
            'timestamp': '2023-01-01 10:00:00',
            'pair': 'BTC/USDT',
            'side': 'buy',
            'price': 50000.0,
            'quantity': 1.0,
            'pnl': 50.0
        },
        {
            'timestamp': '2023-01-01 11:00:00',
            'pair': 'ETH/USDT',
            'side': 'sell',
            'price': 3000.0,
            'quantity': 2.0,
            'pnl': -25.0
        },
        {
            'timestamp': '2023-01-01 12:00:00',
            'pair': 'BTC/USDT',
            'side': 'sell',
            'price': 50500.0,
            'quantity': 1.0,
            'pnl': 100.0
        }
    ]

    for trade in trades:
        monitoring.add_trade(trade)

    assert len(monitoring.trade_history) == 3
    assert monitoring.trade_history['pnl'].sum() == 125.0


def test_add_trade_with_exception(monitoring):
    """Test adding trade with invalid data"""
    # Pass invalid data that might cause an exception
    invalid_trade = None

    # Should not raise exception, but log error
    monitoring.add_trade(invalid_trade)

    # Trade history should remain empty
    assert len(monitoring.trade_history) == 0


def test_update_dashboard(monitoring):
    """Test dashboard update"""
    trade_data = {
        'timestamp': '2023-01-01 10:00:00',
        'pair': 'BTC/USDT',
        'side': 'buy',
        'price': 50000.0,
        'quantity': 1.5,
        'pnl': 100.0
    }

    monitoring.add_trade(trade_data)

    # Check that cumulative PnL was calculated
    assert 'cumulative_pnl' in monitoring.trade_history.columns
    assert monitoring.trade_history['cumulative_pnl'].iloc[0] == 100.0


def test_cumulative_pnl_calculation(monitoring):
    """Test cumulative PnL calculation"""
    trades = [
        {
            'timestamp': '2023-01-01 10:00:00',
            'pair': 'BTC/USDT',
            'side': 'buy',
            'price': 50000.0,
            'quantity': 1.0,
            'pnl': 100.0
        },
        {
            'timestamp': '2023-01-01 11:00:00',
            'pair': 'BTC/USDT',
            'side': 'sell',
            'price': 50500.0,
            'quantity': 1.0,
            'pnl': 150.0
        },
        {
            'timestamp': '2023-01-01 12:00:00',
            'pair': 'BTC/USDT',
            'side': 'buy',
            'price': 50200.0,
            'quantity': 1.0,
            'pnl': -50.0
        }
    ]

    for trade in trades:
        monitoring.add_trade(trade)

    # Cumulative PnL should be 100, 250, 200
    assert monitoring.trade_history['cumulative_pnl'].iloc[0] == 100.0
    assert monitoring.trade_history['cumulative_pnl'].iloc[1] == 250.0
    assert monitoring.trade_history['cumulative_pnl'].iloc[2] == 200.0


def test_app_layout_exists(monitoring):
    """Test that app layout is initialized"""
    assert monitoring.app.layout is not None


def test_app_layout_after_trade(monitoring):
    """Test that app layout is updated after adding trade"""
    trade_data = {
        'timestamp': '2023-01-01 10:00:00',
        'pair': 'BTC/USDT',
        'side': 'buy',
        'price': 50000.0,
        'quantity': 1.5,
        'pnl': 100.0
    }

    monitoring.add_trade(trade_data)

    # Layout should be updated
    assert monitoring.app.layout is not None


@patch('modules.monitoring.os.getenv')
def test_run_with_default_port(mock_getenv, monitoring):
    """Test running monitoring with default port"""
    mock_getenv.return_value = None

    with patch.object(monitoring.app, 'run_server') as mock_run:
        monitoring.run()
        mock_run.assert_called_once_with(host='0.0.0.0', port=8051)


@patch('modules.monitoring.os.getenv')
def test_run_with_custom_port(mock_getenv, monitoring):
    """Test running monitoring with custom port"""
    mock_getenv.return_value = '9000'

    with patch.object(monitoring.app, 'run_server') as mock_run:
        monitoring.run()
        mock_run.assert_called_once_with(host='0.0.0.0', port=9000)


def test_run_with_exception(monitoring):
    """Test running monitoring with exception"""
    with patch.object(monitoring.app, 'run_server', side_effect=Exception('Server error')):
        # Should not raise exception, but log error
        monitoring.run()


def test_trade_history_columns(monitoring):
    """Test that trade history has correct columns"""
    expected_columns = ['timestamp', 'pair', 'side', 'price', 'quantity', 'pnl']

    assert list(monitoring.trade_history.columns) == expected_columns


def test_trade_data_persistence(monitoring):
    """Test that trade data persists across operations"""
    trade1 = {
        'timestamp': '2023-01-01 10:00:00',
        'pair': 'BTC/USDT',
        'side': 'buy',
        'price': 50000.0,
        'quantity': 1.0,
        'pnl': 100.0
    }

    trade2 = {
        'timestamp': '2023-01-01 11:00:00',
        'pair': 'ETH/USDT',
        'side': 'sell',
        'price': 3000.0,
        'quantity': 2.0,
        'pnl': -50.0
    }

    monitoring.add_trade(trade1)
    assert len(monitoring.trade_history) == 1

    monitoring.add_trade(trade2)
    assert len(monitoring.trade_history) == 2

    # First trade should still be there
    assert monitoring.trade_history.iloc[0]['pair'] == 'BTC/USDT'
    assert monitoring.trade_history.iloc[1]['pair'] == 'ETH/USDT'
