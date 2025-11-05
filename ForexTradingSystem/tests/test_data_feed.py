import pytest
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from modules.data_feed import DataFeed

@pytest.fixture
def data_feed():
    return DataFeed()

def test_data_feed_initialization(data_feed):
    assert data_feed is not None
    # Add more initialization tests

def test_fetch_market_data(data_feed):
    # Test market data fetching
    pass

def test_process_data(data_feed):
    # Test data processing
    pass
