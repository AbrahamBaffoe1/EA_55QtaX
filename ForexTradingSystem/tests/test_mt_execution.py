import pytest
from unittest.mock import Mock, patch, MagicMock
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Mock requests if not available
try:
    import requests
except ImportError:
    requests = type('requests', (), {
        'Session': type('Session', (), {}),
        'exceptions': type('exceptions', (), {
            'RequestException': type('RequestException', (Exception,), {})
        })()
    })()

from modules.mt_execution import MTExecution


@pytest.fixture
def mock_session():
    """Mock requests session"""
    session = Mock(spec=requests.Session)
    session.headers = {}
    session.post = Mock()
    session.get = Mock()
    session.delete = Mock()
    session.patch = Mock()
    return session


@pytest.fixture
def mt_execution(mock_session):
    """Create MTExecution instance with mocked session"""
    with patch('modules.mt_execution.requests.Session', return_value=mock_session):
        mt = MTExecution(api_url='http://localhost:8080', api_key='test-key')
        return mt


def test_mt_execution_initialization(mt_execution):
    """Test MTExecution initialization"""
    assert mt_execution is not None
    assert mt_execution.api_url == 'http://localhost:8080'
    assert mt_execution.api_key == 'test-key'
    assert mt_execution.logger is not None


def test_session_headers(mt_execution):
    """Test that session headers are set correctly"""
    assert 'Authorization' in mt_execution.session.headers
    assert mt_execution.session.headers['Authorization'] == 'Bearer test-key'
    assert mt_execution.session.headers['Content-Type'] == 'application/json'


def test_place_order_buy(mt_execution, mock_session):
    """Test placing a buy order"""
    mock_response = Mock()
    mock_response.json.return_value = {'ticket': 123, 'status': 'success'}
    mock_session.post.return_value = mock_response

    result = mt_execution.place_order(
        symbol='EURUSD',
        order_type='BUY',
        volume=1.0,
        price=1.1000,
        stop_loss=1.0950,
        take_profit=1.1100
    )

    assert result['ticket'] == 123
    assert result['status'] == 'success'
    mock_session.post.assert_called_once()


def test_place_order_sell(mt_execution, mock_session):
    """Test placing a sell order"""
    mock_response = Mock()
    mock_response.json.return_value = {'ticket': 124, 'status': 'success'}
    mock_session.post.return_value = mock_response

    result = mt_execution.place_order(
        symbol='GBPUSD',
        order_type='SELL',
        volume=0.5,
        price=1.2500
    )

    assert result['ticket'] == 124
    assert result['status'] == 'success'


def test_place_order_with_error(mt_execution, mock_session):
    """Test placing order with error"""
    mock_session.post.side_effect = requests.exceptions.RequestException('Connection error')

    with pytest.raises(requests.exceptions.RequestException):
        mt_execution.place_order(
            symbol='EURUSD',
            order_type='BUY',
            volume=1.0
        )


def test_close_order(mt_execution, mock_session):
    """Test closing an order"""
    mock_response = Mock()
    mock_response.json.return_value = {'status': 'closed'}
    mock_session.delete.return_value = mock_response

    result = mt_execution.close_order(ticket=123)

    assert result['status'] == 'closed'
    mock_session.delete.assert_called_once_with('http://localhost:8080/order/123')


def test_close_order_with_error(mt_execution, mock_session):
    """Test closing order with error"""
    mock_session.delete.side_effect = requests.exceptions.RequestException('Connection error')

    with pytest.raises(requests.exceptions.RequestException):
        mt_execution.close_order(ticket=123)


def test_get_account_info(mt_execution, mock_session):
    """Test getting account information"""
    mock_response = Mock()
    mock_response.json.return_value = {
        'balance': 10000.0,
        'equity': 10500.0,
        'margin': 500.0
    }
    mock_session.get.return_value = mock_response

    result = mt_execution.get_account_info()

    assert result['balance'] == 10000.0
    assert result['equity'] == 10500.0
    assert result['margin'] == 500.0
    mock_session.get.assert_called_once_with('http://localhost:8080/account')


def test_get_account_info_with_error(mt_execution, mock_session):
    """Test getting account info with error"""
    mock_session.get.side_effect = requests.exceptions.RequestException('Connection error')

    with pytest.raises(requests.exceptions.RequestException):
        mt_execution.get_account_info()


def test_get_positions(mt_execution, mock_session):
    """Test getting open positions"""
    mock_response = Mock()
    mock_response.json.return_value = {
        'positions': [
            {'ticket': 123, 'symbol': 'EURUSD', 'volume': 1.0, 'profit': 50.0},
            {'ticket': 124, 'symbol': 'GBPUSD', 'volume': 0.5, 'profit': -25.0}
        ]
    }
    mock_session.get.return_value = mock_response

    result = mt_execution.get_positions()

    assert len(result['positions']) == 2
    assert result['positions'][0]['ticket'] == 123
    mock_session.get.assert_called_once_with('http://localhost:8080/positions')


def test_modify_order(mt_execution, mock_session):
    """Test modifying an order"""
    mock_response = Mock()
    mock_response.json.return_value = {'status': 'modified'}
    mock_session.patch.return_value = mock_response

    result = mt_execution.modify_order(
        ticket=123,
        stop_loss=1.0900,
        take_profit=1.1200
    )

    assert result['status'] == 'modified'
    mock_session.patch.assert_called_once()


def test_modify_order_with_error(mt_execution, mock_session):
    """Test modifying order with error"""
    mock_session.patch.side_effect = requests.exceptions.RequestException('Connection error')

    with pytest.raises(requests.exceptions.RequestException):
        mt_execution.modify_order(ticket=123, stop_loss=1.0900)


def test_execute_mql(mt_execution, mock_session):
    """Test executing MQL code"""
    mock_response = Mock()
    mock_response.json.return_value = {'result': 'success', 'output': 'Hello World'}
    mock_session.post.return_value = mock_response

    result = mt_execution.execute_mql(
        code='Print("Hello World");',
        params={'param1': 'value1'}
    )

    assert result['result'] == 'success'
    assert result['output'] == 'Hello World'


def test_calculate_indicator(mt_execution, mock_session):
    """Test calculating technical indicator"""
    mock_response = Mock()
    mock_response.json.return_value = {
        'indicator': 'RSI',
        'value': 65.5
    }
    mock_session.post.return_value = mock_response

    result = mt_execution.calculate_indicator(
        symbol='EURUSD',
        timeframe='H1',
        indicator_name='RSI',
        params={'period': 14}
    )

    assert result['indicator'] == 'RSI'
    assert result['value'] == 65.5


def test_backtest_strategy(mt_execution, mock_session):
    """Test backtesting a strategy"""
    mock_response = Mock()
    mock_response.json.return_value = {
        'total_trades': 100,
        'win_rate': 0.65,
        'profit': 5000.0
    }
    mock_session.post.return_value = mock_response

    result = mt_execution.backtest_strategy(
        code='// EA code here',
        params={'lot_size': 0.1},
        start_date='2023-01-01',
        end_date='2023-12-31'
    )

    assert result['total_trades'] == 100
    assert result['win_rate'] == 0.65
    assert result['profit'] == 5000.0


def test_execute_trades(mt_execution, mock_session):
    """Test executing multiple trades"""
    mock_response = Mock()
    mock_response.json.return_value = {'ticket': 123, 'status': 'success'}
    mock_session.post.return_value = mock_response

    signals = [
        {
            'symbol': 'EURUSD',
            'direction': 'long',
            'volume': 1.0,
            'price': 1.1000,
            'stop_loss': 1.0950,
            'take_profit': 1.1100
        },
        {
            'symbol': 'GBPUSD',
            'direction': 'short',
            'volume': 0.5,
            'price': 1.2500
        }
    ]

    mt_execution.execute_trades(signals)

    assert mock_session.post.call_count == 2


def test_execute_trades_with_error(mt_execution, mock_session):
    """Test executing trades with error"""
    mock_session.post.side_effect = Exception('API Error')

    signals = [
        {
            'symbol': 'EURUSD',
            'direction': 'long',
            'volume': 1.0
        }
    ]

    with pytest.raises(Exception):
        mt_execution.execute_trades(signals)


def test_get_bot_performance(mt_execution, mock_session):
    """Test getting bot performance"""
    mock_response = Mock()
    mock_response.json.return_value = {
        'bot_id': 'bot123',
        'metrics': {
            'win_rate': 0.65,
            'drawdown': 0.15,
            'profit_factor': 1.8,
            'total_trades': 150,
            'profit': 3000.0
        }
    }
    mock_session.get.return_value = mock_response

    result = mt_execution.get_bot_performance('bot123')

    assert result['bot_id'] == 'bot123'
    assert result['metrics']['win_rate'] == 0.65
    assert result['metrics']['total_trades'] == 150


def test_get_bot_performance_with_error(mt_execution, mock_session):
    """Test getting bot performance with error"""
    mock_session.get.side_effect = Exception('API Error')

    result = mt_execution.get_bot_performance('bot123')

    assert result['bot_id'] == 'bot123'
    assert 'error' in result
    assert result['metrics']['win_rate'] == 0


def test_order_type_conversion(mt_execution, mock_session):
    """Test that order types are converted correctly"""
    mock_response = Mock()
    mock_response.json.return_value = {'ticket': 123}
    mock_session.post.return_value = mock_response

    # Test BUY order type conversion
    mt_execution.place_order('EURUSD', 'BUY', 1.0)
    call_args = mock_session.post.call_args
    # Check that the payload includes type: 0 for BUY

    # Test SELL order type conversion
    mt_execution.place_order('EURUSD', 'SELL', 1.0)
    call_args = mock_session.post.call_args
    # Check that the payload includes type: 1 for SELL
