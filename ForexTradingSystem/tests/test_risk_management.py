import pytest
from unittest.mock import Mock, patch
from decimal import Decimal
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from modules.risk_management import RiskManager


@pytest.fixture
def risk_manager():
    """Create RiskManager instance with test environment variables"""
    with patch.dict(os.environ, {
        'MAX_DAILY_LOSS': '1000',
        'RISK_PER_TRADE': '0.02',
        'MAX_POSITION_SIZE': '0.1'
    }):
        return RiskManager()


def test_risk_manager_initialization(risk_manager):
    """Test RiskManager initialization"""
    assert risk_manager is not None
    assert risk_manager.logger is not None
    assert risk_manager.daily_loss_limit == Decimal('1000')
    assert risk_manager.risk_per_trade == Decimal('0.02')
    assert risk_manager.max_position_size == Decimal('0.1')
    assert risk_manager.daily_pnl == Decimal('0')


def test_update_risk_parameters_within_limit(risk_manager):
    """Test updating risk parameters within daily loss limit"""
    risk_manager.daily_pnl = Decimal('-500')

    result = risk_manager.update_risk_parameters()

    assert result is True


def test_update_risk_parameters_at_limit(risk_manager):
    """Test updating risk parameters at daily loss limit"""
    risk_manager.daily_pnl = Decimal('-1000')

    result = risk_manager.update_risk_parameters()

    assert result is False


def test_update_risk_parameters_exceeds_limit(risk_manager):
    """Test updating risk parameters exceeding daily loss limit"""
    risk_manager.daily_pnl = Decimal('-1500')

    result = risk_manager.update_risk_parameters()

    assert result is False


def test_update_risk_parameters_with_profit(risk_manager):
    """Test updating risk parameters with positive PnL"""
    risk_manager.daily_pnl = Decimal('500')

    result = risk_manager.update_risk_parameters()

    assert result is True


def test_calculate_position_size(risk_manager):
    """Test calculating position size"""
    balance = Decimal('10000')
    atr = Decimal('100')

    position_size = risk_manager.calculate_position_size(balance, atr)

    # Risk amount = 10000 * 0.02 = 200
    # Position size = 200 / 100 = 2
    # Max size = 10000 * 0.1 = 1000
    # Should return min(2, 1000) = 2
    assert position_size == Decimal('2')


def test_calculate_position_size_with_max_constraint(risk_manager):
    """Test calculating position size with max constraint"""
    balance = Decimal('10000')
    atr = Decimal('1')  # Very small ATR

    position_size = risk_manager.calculate_position_size(balance, atr)

    # Risk amount = 10000 * 0.02 = 200
    # Position size = 200 / 1 = 200
    # Max size = 10000 * 0.1 = 1000
    # Should return min(200, 1000) = 200
    assert position_size == Decimal('200')


def test_calculate_position_size_high_volatility(risk_manager):
    """Test calculating position size with high volatility"""
    balance = Decimal('10000')
    atr = Decimal('500')  # High ATR (high volatility)

    position_size = risk_manager.calculate_position_size(balance, atr)

    # Risk amount = 10000 * 0.02 = 200
    # Position size = 200 / 500 = 0.4
    # Max size = 10000 * 0.1 = 1000
    # Should return min(0.4, 1000) = 0.4
    assert position_size == Decimal('0.4')


def test_calculate_position_size_zero_atr(risk_manager):
    """Test calculating position size with zero ATR"""
    balance = Decimal('10000')
    atr = Decimal('0')

    # Should handle division by zero gracefully
    position_size = risk_manager.calculate_position_size(balance, atr)

    # Should return 0 or handle error
    assert position_size == Decimal('0')


def test_update_pnl_positive(risk_manager):
    """Test updating PnL with positive change"""
    risk_manager.update_pnl(Decimal('100'))

    assert risk_manager.daily_pnl == Decimal('100')


def test_update_pnl_negative(risk_manager):
    """Test updating PnL with negative change"""
    risk_manager.update_pnl(Decimal('-50'))

    assert risk_manager.daily_pnl == Decimal('-50')


def test_update_pnl_multiple_updates(risk_manager):
    """Test updating PnL multiple times"""
    risk_manager.update_pnl(Decimal('100'))
    risk_manager.update_pnl(Decimal('-50'))
    risk_manager.update_pnl(Decimal('25'))

    assert risk_manager.daily_pnl == Decimal('75')


def test_get_risk_status(risk_manager):
    """Test getting risk status"""
    risk_manager.daily_pnl = Decimal('-250')

    status = risk_manager.get_risk_status()

    assert status['daily_pnl'] == -250.0
    assert status['daily_loss_limit'] == 1000.0
    assert status['risk_per_trade'] == 0.02
    assert status['max_position_size'] == 0.1


def test_get_risk_status_structure(risk_manager):
    """Test risk status structure"""
    status = risk_manager.get_risk_status()

    assert 'daily_pnl' in status
    assert 'daily_loss_limit' in status
    assert 'risk_per_trade' in status
    assert 'max_position_size' in status
    assert isinstance(status['daily_pnl'], float)
    assert isinstance(status['daily_loss_limit'], float)
    assert isinstance(status['risk_per_trade'], float)
    assert isinstance(status['max_position_size'], float)


def test_risk_manager_with_custom_parameters():
    """Test RiskManager with custom parameters"""
    with patch.dict(os.environ, {
        'MAX_DAILY_LOSS': '2000',
        'RISK_PER_TRADE': '0.01',
        'MAX_POSITION_SIZE': '0.05'
    }):
        rm = RiskManager()

        assert rm.daily_loss_limit == Decimal('2000')
        assert rm.risk_per_trade == Decimal('0.01')
        assert rm.max_position_size == Decimal('0.05')
