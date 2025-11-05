import pytest
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Mock pandas and numpy if not available
try:
    import pandas as pd
    import numpy as np
except ImportError:
    pd = None
    np = None
    pytest.skip("pandas and numpy not installed", allow_module_level=True)

from modules.signal_generator import SignalGenerator


@pytest.fixture
def signal_generator():
    """Create SignalGenerator instance"""
    return SignalGenerator()


@pytest.fixture
def sample_data():
    """Create sample market data for testing"""
    dates = pd.date_range(start='2023-01-01', periods=100, freq='1h')
    data = pd.DataFrame({
        'timestamp': dates,
        'open': np.random.uniform(50000, 51000, 100),
        'high': np.random.uniform(51000, 52000, 100),
        'low': np.random.uniform(49000, 50000, 100),
        'close': np.random.uniform(50000, 51000, 100),
        'volume': np.random.uniform(100, 1000, 100)
    })
    return data


def test_signal_generator_initialization(signal_generator):
    """Test SignalGenerator initialization"""
    assert signal_generator is not None
    assert 'rsi' in signal_generator.indicators
    assert 'ema' in signal_generator.indicators
    assert 'macd' in signal_generator.indicators
    assert 'atr' in signal_generator.indicators


def test_indicator_parameters(signal_generator):
    """Test indicator parameters are set correctly"""
    assert signal_generator.indicators['rsi']['length'] == 14
    assert signal_generator.indicators['ema']['length'] == 20
    assert signal_generator.indicators['macd']['fast'] == 12
    assert signal_generator.indicators['macd']['slow'] == 26
    assert signal_generator.indicators['macd']['signal'] == 9
    assert signal_generator.indicators['atr']['length'] == 14


def test_generate_signals_with_valid_data(signal_generator, sample_data):
    """Test generating signals with valid data"""
    signals = signal_generator.generate_signals(sample_data)

    assert isinstance(signals, dict)
    assert 'rsi' in signals
    assert 'ema' in signals
    assert 'macd' in signals
    assert 'atr' in signals


def test_generate_signals_with_empty_data(signal_generator):
    """Test generating signals with empty data"""
    empty_data = pd.DataFrame()

    signals = signal_generator.generate_signals(empty_data)

    assert signals == {}


def test_generate_rsi_signal_overbought(signal_generator):
    """Test RSI signal generation for overbought condition"""
    data = pd.DataFrame({
        'close': [100, 105, 110, 115, 120, 125, 130, 135, 140, 145, 150, 155, 160, 165, 170],
        'rsi': [50, 55, 60, 65, 70, 75, 80, 82, 84, 85, 86, 87, 88, 89, 90]
    })

    signal = signal_generator._generate_rsi_signal(data)

    assert signal == 'overbought'


def test_generate_rsi_signal_oversold(signal_generator):
    """Test RSI signal generation for oversold condition"""
    data = pd.DataFrame({
        'close': [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50, 45, 40, 35, 30],
        'rsi': [50, 45, 40, 35, 30, 25, 20, 18, 16, 15, 14, 13, 12, 11, 10]
    })

    signal = signal_generator._generate_rsi_signal(data)

    assert signal == 'oversold'


def test_generate_rsi_signal_neutral(signal_generator):
    """Test RSI signal generation for neutral condition"""
    data = pd.DataFrame({
        'close': [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114],
        'rsi': [50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 59, 58, 57, 56]
    })

    signal = signal_generator._generate_rsi_signal(data)

    assert signal == 'neutral'


def test_generate_ema_signal_bullish(signal_generator):
    """Test EMA signal generation for bullish condition"""
    data = pd.DataFrame({
        'close': [100, 101, 102, 103, 104],
        'ema': [98, 98.5, 99, 99.5, 100]
    })

    signal = signal_generator._generate_ema_signal(data)

    assert signal == 'bullish'


def test_generate_ema_signal_bearish(signal_generator):
    """Test EMA signal generation for bearish condition"""
    data = pd.DataFrame({
        'close': [100, 99, 98, 97, 96],
        'ema': [102, 101.5, 101, 100.5, 100]
    })

    signal = signal_generator._generate_ema_signal(data)

    assert signal == 'bearish'


def test_generate_macd_signal_bullish(signal_generator):
    """Test MACD signal generation for bullish condition"""
    data = pd.DataFrame({
        'MACD_12_26_9': [10, 12, 14, 16, 18],
        'MACDs_12_26_9': [8, 10, 12, 14, 15]
    })

    signal = signal_generator._generate_macd_signal(data)

    assert signal == 'bullish'


def test_generate_macd_signal_bearish(signal_generator):
    """Test MACD signal generation for bearish condition"""
    data = pd.DataFrame({
        'MACD_12_26_9': [10, 8, 6, 4, 2],
        'MACDs_12_26_9': [12, 10, 8, 6, 5]
    })

    signal = signal_generator._generate_macd_signal(data)

    assert signal == 'bearish'


def test_generate_signals_data_with_indicators(signal_generator, sample_data):
    """Test that signals are generated correctly and data is not empty"""
    signals = signal_generator.generate_signals(sample_data)

    assert signals['rsi'] in ['overbought', 'oversold', 'neutral']
    assert signals['ema'] in ['bullish', 'bearish']
    assert signals['macd'] in ['bullish', 'bearish']
    assert isinstance(signals['atr'], (float, np.floating))


def test_custom_indicator_parameters():
    """Test creating SignalGenerator with custom parameters"""
    sg = SignalGenerator()
    sg.indicators['rsi']['length'] = 20
    sg.indicators['ema']['length'] = 50

    assert sg.indicators['rsi']['length'] == 20
    assert sg.indicators['ema']['length'] == 50


def test_generate_signals_with_trending_data(signal_generator):
    """Test signal generation with clearly trending data"""
    # Create uptrending data
    dates = pd.date_range(start='2023-01-01', periods=50, freq='1h')
    close_prices = np.linspace(50000, 55000, 50)
    data = pd.DataFrame({
        'timestamp': dates,
        'open': close_prices * 0.99,
        'high': close_prices * 1.01,
        'low': close_prices * 0.98,
        'close': close_prices,
        'volume': np.random.uniform(100, 1000, 50)
    })

    signals = signal_generator.generate_signals(data)

    assert signals['ema'] == 'bullish'  # Should be bullish in uptrend
    assert isinstance(signals['atr'], (float, np.floating))
    assert signals['atr'] > 0
