import pytest
from unittest.mock import Mock, patch, MagicMock
from decimal import Decimal
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from modules.hedging import Hedging

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
    exchange.fetch_ticker = Mock()
    exchange.create_market_order = Mock()
    return exchange


@pytest.fixture
def hedging(mock_exchange):
    """Create Hedging instance with mocked exchange"""
    with patch('modules.hedging.ccxt.binance') as mock_binance:
        mock_binance.return_value = mock_exchange
        hedge = Hedging()
        return hedge


def test_hedging_initialization(hedging):
    """Test Hedging initialization"""
    assert hedging is not None
    assert hedging.exchange is not None
    assert hedging.logger is not None
    assert hedging.hedge_ratio == Decimal('0.5')


def test_get_positions(hedging, mock_exchange):
    """Test getting current positions"""
    mock_exchange.fetch_balance.return_value = {
        'free': {
            'BTC': 2.5,
            'USDT': 50000.0
        }
    }

    positions = hedging._get_positions()

    assert positions['BTC'] == Decimal('2.5')
    assert positions['USDT'] == Decimal('50000.0')
    mock_exchange.fetch_balance.assert_called_once()


def test_get_btc_price(hedging, mock_exchange):
    """Test getting BTC price"""
    mock_exchange.fetch_ticker.return_value = {
        'last': 50000.0
    }

    price = hedging._get_btc_price()

    assert price == Decimal('50000.0')
    mock_exchange.fetch_ticker.assert_called_once_with('BTC/USDT')


def test_calculate_hedge_amount_positive(hedging, mock_exchange):
    """Test calculating hedge amount when need to buy"""
    positions = {
        'BTC': Decimal('1.0'),
        'USDT': Decimal('50000.0')
    }

    mock_exchange.fetch_ticker.return_value = {
        'last': 50000.0
    }

    hedge_amount = hedging._calculate_hedge_amount(positions)

    # BTC value = 1.0 * 50000 = 50000
    # Total value = 50000 + 50000 = 100000
    # Target hedge = 100000 * 0.5 = 50000
    # Required hedge = 50000 - 50000 = 0
    assert hedge_amount == Decimal('0')


def test_calculate_hedge_amount_negative(hedging, mock_exchange):
    """Test calculating hedge amount when need to sell"""
    positions = {
        'BTC': Decimal('2.0'),
        'USDT': Decimal('20000.0')
    }

    mock_exchange.fetch_ticker.return_value = {
        'last': 50000.0
    }

    hedge_amount = hedging._calculate_hedge_amount(positions)

    # BTC value = 2.0 * 50000 = 100000
    # Total value = 100000 + 20000 = 120000
    # Target hedge = 120000 * 0.5 = 60000
    # Required hedge = 60000 - 100000 = -40000
    assert hedge_amount == Decimal('-40000')


def test_place_hedge_order_buy(hedging, mock_exchange):
    """Test placing buy hedge order"""
    mock_exchange.create_market_order.return_value = {
        'id': '123',
        'status': 'filled'
    }

    hedging._place_hedge_order(Decimal('1000'))

    mock_exchange.create_market_order.assert_called_once_with(
        'BTC/USDT',
        'buy',
        1000.0
    )


def test_place_hedge_order_sell(hedging, mock_exchange):
    """Test placing sell hedge order"""
    mock_exchange.create_market_order.return_value = {
        'id': '124',
        'status': 'filled'
    }

    hedging._place_hedge_order(Decimal('-1000'))

    mock_exchange.create_market_order.assert_called_once_with(
        'BTC/USDT',
        'sell',
        1000.0
    )


def test_place_hedge_order_insufficient_funds(hedging, mock_exchange):
    """Test placing hedge order with insufficient funds"""
    mock_exchange.create_market_order.side_effect = ccxt.InsufficientFunds('Not enough funds')

    # Should not raise exception, but log error
    hedging._place_hedge_order(Decimal('1000'))

    mock_exchange.create_market_order.assert_called_once()


def test_place_hedge_order_network_error(hedging, mock_exchange):
    """Test placing hedge order with network error"""
    mock_exchange.create_market_order.side_effect = ccxt.NetworkError('Connection lost')

    # Should not raise exception, but log error
    hedging._place_hedge_order(Decimal('1000'))

    mock_exchange.create_market_order.assert_called_once()


def test_manage_hedges_with_hedge_needed(hedging, mock_exchange):
    """Test managing hedges when hedge is needed"""
    mock_exchange.fetch_balance.return_value = {
        'free': {
            'BTC': 0.5,
            'USDT': 75000.0
        }
    }
    mock_exchange.fetch_ticker.return_value = {
        'last': 50000.0
    }
    mock_exchange.create_market_order.return_value = {
        'id': '123',
        'status': 'filled'
    }

    hedging.manage_hedges()

    # BTC value = 0.5 * 50000 = 25000
    # Total value = 25000 + 75000 = 100000
    # Target hedge = 100000 * 0.5 = 50000
    # Required hedge = 50000 - 25000 = 25000
    mock_exchange.create_market_order.assert_called_once()


def test_manage_hedges_no_hedge_needed(hedging, mock_exchange):
    """Test managing hedges when no hedge is needed"""
    mock_exchange.fetch_balance.return_value = {
        'free': {
            'BTC': 1.0,
            'USDT': 50000.0
        }
    }
    mock_exchange.fetch_ticker.return_value = {
        'last': 50000.0
    }

    hedging.manage_hedges()

    # Hedge amount should be 0
    mock_exchange.create_market_order.assert_not_called()


def test_manage_hedges_exception(hedging, mock_exchange):
    """Test managing hedges with exception"""
    mock_exchange.fetch_balance.side_effect = Exception('API Error')

    # Should not raise exception, but log error
    hedging.manage_hedges()

    mock_exchange.fetch_balance.assert_called_once()


def test_custom_hedge_ratio():
    """Test custom hedge ratio"""
    with patch('modules.hedging.ccxt.binance') as mock_binance:
        mock_exchange = Mock()
        mock_binance.return_value = mock_exchange
        hedge = Hedging()
        hedge.hedge_ratio = Decimal('0.7')

        assert hedge.hedge_ratio == Decimal('0.7')
