import pytest
from unittest.mock import Mock, patch, MagicMock
from decimal import Decimal
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from modules.arbitrage import Arbitrage

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
    exchange.fetch_order_book = Mock()
    exchange.create_limit_buy_order = Mock()
    exchange.create_limit_sell_order = Mock()
    return exchange


@pytest.fixture
def arbitrage(mock_exchange):
    """Create Arbitrage instance with mocked exchange"""
    with patch('modules.arbitrage.ccxt.binance') as mock_binance:
        mock_binance.return_value = mock_exchange
        arb = Arbitrage()
        return arb


def test_arbitrage_initialization(arbitrage):
    """Test Arbitrage initialization"""
    assert arbitrage is not None
    assert arbitrage.exchange is not None
    assert arbitrage.logger is not None
    assert arbitrage.min_profit_threshold == Decimal('0.005')


def test_find_arbitrage_opportunity_with_profit(arbitrage):
    """Test finding arbitrage opportunity when profit exists"""
    order_book = {
        'bids': [[50100, 1.5]],  # Higher bid price
        'asks': [[50000, 2.0]]   # Lower ask price
    }

    opportunity = arbitrage._find_arbitrage_opportunity(order_book)

    assert opportunity is not None
    assert opportunity['bid_price'] == Decimal('50100')
    assert opportunity['ask_price'] == Decimal('50000')
    assert opportunity['quantity'] == Decimal('1.5')


def test_find_arbitrage_opportunity_no_profit(arbitrage):
    """Test when no arbitrage opportunity exists"""
    order_book = {
        'bids': [[50000, 1.5]],
        'asks': [[50100, 2.0]]  # Ask higher than bid (normal)
    }

    opportunity = arbitrage._find_arbitrage_opportunity(order_book)

    assert opportunity is None


def test_find_arbitrage_opportunity_below_threshold(arbitrage):
    """Test when spread exists but below profit threshold"""
    order_book = {
        'bids': [[50010, 1.5]],
        'asks': [[50000, 2.0]]  # Spread of only 10 (0.02% - below 0.5% threshold)
    }

    opportunity = arbitrage._find_arbitrage_opportunity(order_book)

    assert opportunity is None


def test_execute_arbitrage_success(arbitrage, mock_exchange):
    """Test successful arbitrage execution"""
    opportunity = {
        'bid_price': Decimal('50100'),
        'ask_price': Decimal('50000'),
        'quantity': Decimal('1.5')
    }

    mock_exchange.create_limit_buy_order.return_value = {'id': '123', 'status': 'filled'}
    mock_exchange.create_limit_sell_order.return_value = {'id': '124', 'status': 'filled'}

    arbitrage._execute_arbitrage(opportunity)

    mock_exchange.create_limit_buy_order.assert_called_once_with(
        'BTC/USDT',
        1.5,
        50000.0
    )
    mock_exchange.create_limit_sell_order.assert_called_once_with(
        'BTC/USDT',
        1.5,
        50100.0
    )


def test_execute_arbitrage_insufficient_funds(arbitrage, mock_exchange):
    """Test arbitrage execution with insufficient funds"""
    opportunity = {
        'bid_price': Decimal('50100'),
        'ask_price': Decimal('50000'),
        'quantity': Decimal('1.5')
    }

    mock_exchange.create_limit_buy_order.side_effect = ccxt.InsufficientFunds('Not enough funds')

    # Should not raise exception, but log error
    arbitrage._execute_arbitrage(opportunity)

    mock_exchange.create_limit_buy_order.assert_called_once()


def test_execute_arbitrage_network_error(arbitrage, mock_exchange):
    """Test arbitrage execution with network error"""
    opportunity = {
        'bid_price': Decimal('50100'),
        'ask_price': Decimal('50000'),
        'quantity': Decimal('1.5')
    }

    mock_exchange.create_limit_buy_order.side_effect = ccxt.NetworkError('Connection lost')

    # Should not raise exception, but log error
    arbitrage._execute_arbitrage(opportunity)

    mock_exchange.create_limit_buy_order.assert_called_once()


def test_check_opportunities_success(arbitrage, mock_exchange):
    """Test checking for opportunities successfully"""
    order_book = {
        'bids': [[50500, 1.5]],
        'asks': [[50000, 2.0]]
    }

    mock_exchange.fetch_order_book.return_value = order_book
    mock_exchange.create_limit_buy_order.return_value = {'id': '123'}
    mock_exchange.create_limit_sell_order.return_value = {'id': '124'}

    arbitrage.check_opportunities()

    mock_exchange.fetch_order_book.assert_called_once_with('BTC/USDT')
    mock_exchange.create_limit_buy_order.assert_called_once()
    mock_exchange.create_limit_sell_order.assert_called_once()


def test_check_opportunities_no_opportunity(arbitrage, mock_exchange):
    """Test checking for opportunities when none exist"""
    order_book = {
        'bids': [[50000, 1.5]],
        'asks': [[50100, 2.0]]
    }

    mock_exchange.fetch_order_book.return_value = order_book

    arbitrage.check_opportunities()

    mock_exchange.fetch_order_book.assert_called_once_with('BTC/USDT')
    mock_exchange.create_limit_buy_order.assert_not_called()
    mock_exchange.create_limit_sell_order.assert_not_called()


def test_check_opportunities_exception(arbitrage, mock_exchange):
    """Test checking opportunities with exception"""
    mock_exchange.fetch_order_book.side_effect = Exception('API Error')

    # Should not raise exception, but log error
    arbitrage.check_opportunities()

    mock_exchange.fetch_order_book.assert_called_once()
