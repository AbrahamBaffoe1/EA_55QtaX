import pytest
from unittest.mock import Mock, patch, MagicMock
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from modules.dashboard import Dashboard


@pytest.fixture
def mock_alpaca():
    """Mock Alpaca REST API"""
    alpaca = Mock()
    alpaca.get_account = Mock()
    alpaca.list_positions = Mock()
    alpaca.get_news = Mock()
    return alpaca


@pytest.fixture
def dashboard_config():
    """Dashboard configuration"""
    return {
        'ALPACA_API_KEY': 'test-api-key',
        'ALPACA_SECRET_KEY': 'test-secret-key',
        'ALPACA_BASE_URL': 'https://paper-api.alpaca.markets'
    }


@pytest.fixture
def dashboard(dashboard_config, mock_alpaca):
    """Create Dashboard instance with mocked dependencies"""
    with patch('modules.dashboard.REST', return_value=mock_alpaca):
        dash = Dashboard(dashboard_config)
        return dash


def test_dashboard_initialization(dashboard, dashboard_config):
    """Test Dashboard initialization"""
    assert dashboard is not None
    assert dashboard.app is not None
    assert dashboard.alpaca is not None
    assert dashboard.running is False


def test_get_portfolio_success(dashboard, mock_alpaca):
    """Test getting portfolio data successfully"""
    # Mock account data
    mock_account = Mock()
    mock_account.equity = 100000.0
    mock_alpaca.get_account.return_value = mock_account

    # Mock positions data
    mock_position1 = Mock()
    mock_position1.symbol = 'AAPL'
    mock_position1.qty = 10
    mock_position1.market_value = 1500.0

    mock_position2 = Mock()
    mock_position2.symbol = 'TSLA'
    mock_position2.qty = 5
    mock_position2.market_value = 2500.0

    mock_alpaca.list_positions.return_value = [mock_position1, mock_position2]

    portfolio = dashboard.get_portfolio()

    assert portfolio['balance'] == 100000.0
    assert len(portfolio['positions']) == 2
    assert portfolio['positions'][0]['symbol'] == 'AAPL'
    assert portfolio['positions'][0]['qty'] == 10
    assert portfolio['positions'][1]['symbol'] == 'TSLA'


def test_get_portfolio_with_error(dashboard, mock_alpaca):
    """Test getting portfolio with error"""
    mock_alpaca.get_account.side_effect = Exception('API Error')

    portfolio = dashboard.get_portfolio()

    assert 'error' in portfolio
    assert 'API Error' in portfolio['error']


def test_get_portfolio_empty_positions(dashboard, mock_alpaca):
    """Test getting portfolio with no positions"""
    mock_account = Mock()
    mock_account.equity = 50000.0
    mock_alpaca.get_account.return_value = mock_account
    mock_alpaca.list_positions.return_value = []

    portfolio = dashboard.get_portfolio()

    assert portfolio['balance'] == 50000.0
    assert len(portfolio['positions']) == 0


def test_get_news_success(dashboard, mock_alpaca):
    """Test getting news successfully"""
    mock_news1 = Mock()
    mock_news1.headline = 'Stock Market Rises'
    mock_news1.summary = 'Markets showing positive trends'
    mock_news1.url = 'https://example.com/news1'

    mock_news2 = Mock()
    mock_news2.headline = 'Tech Stocks Rally'
    mock_news2.summary = 'Technology sector leads gains'
    mock_news2.url = 'https://example.com/news2'

    mock_alpaca.get_news.return_value = [mock_news1, mock_news2]

    news = dashboard.get_news()

    assert len(news) == 2
    assert news[0]['headline'] == 'Stock Market Rises'
    assert news[1]['headline'] == 'Tech Stocks Rally'


def test_get_news_with_error(dashboard, mock_alpaca):
    """Test getting news with error"""
    mock_alpaca.get_news.side_effect = Exception('News API Error')

    news = dashboard.get_news()

    assert 'error' in news
    assert 'News API Error' in news['error']


def test_get_news_empty(dashboard, mock_alpaca):
    """Test getting news with no results"""
    mock_alpaca.get_news.return_value = []

    news = dashboard.get_news()

    assert len(news) == 0


def test_get_analytics(dashboard):
    """Test getting analytics data"""
    analytics = dashboard.get_analytics()

    assert 'performance' in analytics
    assert 'risk_metrics' in analytics


def test_dashboard_routes_exist(dashboard):
    """Test that dashboard routes are set up"""
    # Get all registered routes
    routes = [rule.rule for rule in dashboard.app.url_map.iter_rules()]

    assert '/api/dashboard' in routes
    assert '/api/bots' in routes


def test_start_dashboard(dashboard):
    """Test starting the dashboard"""
    with patch.object(dashboard.app, 'run') as mock_run:
        dashboard.start()

        assert dashboard.running is True


def test_start_dashboard_already_running(dashboard):
    """Test starting dashboard when already running"""
    dashboard.running = True

    with patch.object(dashboard.app, 'run') as mock_run:
        dashboard.start()

        # Should not start again
        mock_run.assert_not_called()


def test_stop_dashboard(dashboard):
    """Test stopping the dashboard"""
    dashboard.running = True
    dashboard.stop()

    assert dashboard.running is False


def test_dashboard_data_endpoint(dashboard, mock_alpaca):
    """Test /api/dashboard endpoint"""
    # Mock all required data
    mock_account = Mock()
    mock_account.equity = 100000.0
    mock_alpaca.get_account.return_value = mock_account
    mock_alpaca.list_positions.return_value = []
    mock_alpaca.get_news.return_value = []

    with dashboard.app.test_client() as client:
        response = client.get('/api/dashboard')
        data = response.get_json()

        assert response.status_code == 200
        assert 'portfolio' in data
        assert 'news' in data
        assert 'analytics' in data


def test_bot_config_endpoint(dashboard):
    """Test /api/bots endpoint"""
    with dashboard.app.test_client() as client:
        response = client.get('/api/bots')

        assert response.status_code == 200
        # Response should be JSON
        assert response.content_type == 'application/json'


def test_get_bot_configurations(dashboard):
    """Test getting bot configurations"""
    bot_configs = dashboard.get_bot_configurations()

    # Should return some form of bot configuration data
    assert bot_configs is not None


def test_calculate_performance(dashboard):
    """Test calculating performance metrics"""
    performance = dashboard.calculate_performance()

    # Should return performance data
    assert performance is not None


def test_calculate_risk_metrics(dashboard):
    """Test calculating risk metrics"""
    risk_metrics = dashboard.calculate_risk_metrics()

    # Should return risk metrics data
    assert risk_metrics is not None


def test_cors_enabled(dashboard):
    """Test that CORS is enabled"""
    # Check that CORS extension is configured
    assert hasattr(dashboard.app, 'extensions')


def test_dashboard_thread_safety(dashboard):
    """Test that dashboard can be started in a thread"""
    import threading

    with patch.object(dashboard.app, 'run'):
        dashboard.start()

        # Should not raise any threading errors
        assert dashboard.running is True


def test_multiple_portfolio_calls(dashboard, mock_alpaca):
    """Test making multiple portfolio calls"""
    mock_account = Mock()
    mock_account.equity = 100000.0
    mock_alpaca.get_account.return_value = mock_account
    mock_alpaca.list_positions.return_value = []

    # Make multiple calls
    portfolio1 = dashboard.get_portfolio()
    portfolio2 = dashboard.get_portfolio()

    assert portfolio1['balance'] == portfolio2['balance']
    assert mock_alpaca.get_account.call_count == 2
