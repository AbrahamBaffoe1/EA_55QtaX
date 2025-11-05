# Missing Implementations - Task Checklist

## CRITICAL BLOCKING ISSUES (System Won't Run)

### 1. Missing Method Implementations - DataFeed Module
**File:** `modules/data_feed.py`

- [ ] Implement `add_subscriber(client_id)` method
  - Purpose: Add WebSocket client to subscriber list
  - Called from: `main.py:99`
  - Should maintain list of connected clients
  
- [ ] Implement `remove_subscriber(client_id)` method
  - Purpose: Remove disconnected WebSocket client
  - Called from: `main.py:104`
  - Should remove from subscriber list
  
- [ ] Add/rename method: `get_data()` → `get_market_data()`
  - Current: `get_data()` exists at line 20
  - Expected: Called as `get_market_data()` in `main.py:162`
  - Action: Rename or add alias

- [ ] Add attribute: `subscribers` list
  - Should be initialized in `__init__`
  - Default: empty list `[]`

**Related WebSocket Broadcasting:**
- [ ] After getting new data, broadcast to subscribers
  - Trigger: After `self.exchange.fetch_ohlcv()` call
  - Event data: New OHLCV data
  - Method: Via global socketio object

---

### 2. Missing Method Implementations - MT Execution Module
**File:** `modules/mt_execution.py`

- [ ] Implement `add_subscriber(client_id)` method
  - Purpose: Add WebSocket client to trade update list
  - Called from: `main.py:109`
  - Should maintain list of trade subscribers
  
- [ ] Implement `remove_subscriber(client_id)` method
  - Purpose: Remove disconnected WebSocket client from trade updates
  - Called from: `main.py:114`
  - Should remove from subscriber list

- [ ] Add attribute: `subscribers` list
  - Should be initialized in `__init__`
  - Default: empty list `[]`

- [ ] Fix `execute_trades()` method
  - Current: Calls non-existent `self.monitoring.update_trades()`
  - Line: 192
  - Should: Check if monitoring exists and call with order_response data

---

### 3. Missing Method Implementation - Monitoring Module
**File:** `modules/monitoring.py`

- [ ] Implement `update_trades(trade_data)` method
  - Purpose: Record trade execution in trade history
  - Called from: `mt_execution.py:192`
  - Parameters:
    ```python
    trade_data = {
        'timestamp': datetime,
        'pair': str,
        'side': 'buy'|'sell',
        'price': float,
        'quantity': float,
        'pnl': float  # optional
    }
    ```
  - Action: Append to `self.trade_history` DataFrame and trigger dashboard update

- [ ] Fix `run()` method
  - Issue: Dashboard shows "Loading..." forever
  - Problem: No actual dashboard content generated
  - Should: Generate proper Dash layout with callbacks

- [ ] Add WebSocket integration
  - Should broadcast trade updates to connected clients
  - Event name: `trade_update`
  - Event data: New trade information

---

### 4. Missing Methods - API Server
**File:** `api_server.py`

- [ ] Implement `get_portfolio()` method
  - Purpose: Return portfolio data
  - Called from: `api_server.py:63`
  - Should return:
    ```python
    {
        'balance': float,
        'positions': [
            {'symbol': str, 'quantity': float, 'value': float},
            ...
        ],
        'totalValue': float,
        'dailyChange': float
    }
    ```
  - Source: `self.execution.get_account_balance()` or query database

- [ ] Implement `get_news()` method
  - Purpose: Return financial news
  - Called from: `api_server.py:64`
  - Should return:
    ```python
    [
        {
            'id': str,
            'headline': str,
            'summary': str,
            'source': str,
            'url': str,
            'timestamp': datetime
        },
        ...
    ]
    ```
  - Source: External news API or database

- [ ] Implement `get_analytics()` method
  - Purpose: Return trading analytics
  - Called from: `api_server.py:65`
  - Should return:
    ```python
    {
        'profitLoss': [...],      # Time-series data
        'tradeVolume': [...],     # Time-series data
        'winRate': [...],         # Chart data
        'performance': {...},     # Performance metrics
        'riskMetrics': {...}      # Risk metrics
    }
    ```
  - Source: Query monitoring/database

- [ ] Implement `get_bot_configurations()` method
  - Purpose: Return all bot configurations
  - Called from: `api_server.py:74`, `api_server.py:119`
  - Should return:
    ```python
    [
        {
            'id': str,
            'name': str,
            'status': 'active'|'inactive',
            'config': {
                'strategy': str,
                'riskPercentage': float,
                'maxTrades': int,
                'autoTrade': bool
            },
            'performance': {...}
        },
        ...
    ]
    ```
  - Source: Database (needs to be created)

---

### 5. Missing Import - Main Module
**File:** `main.py`

- [ ] Add missing import
  - Line 178 uses `time.sleep()` but `time` is not imported
  - Add at top: `import time`
  - Currently has: eventlet, os, sys, logging, decimal, dotenv, flask modules
  - Missing: `import time`

---

## MAJOR ISSUES (Core Functionality)

### 6. Database/Persistence Layer - ALL MODULES
**Status:** COMPLETELY MISSING

- [ ] Set up SQLAlchemy ORM
  - Add to requirements: `sqlalchemy` and `flask-sqlalchemy`
  - Create `models.py` file with data models

- [ ] Create database models:
  - [ ] `Trade` model
    ```
    id, user_id, pair, side, quantity, entry_price, exit_price, 
    entry_time, exit_time, pnl, status, notes
    ```
  
  - [ ] `BotConfig` model
    ```
    id, user_id, name, status, strategy, risk_percentage, max_trades,
    auto_trade, created_at, updated_at
    ```
  
  - [ ] `Portfolio` model
    ```
    id, user_id, total_value, cash, positions_json, created_at
    ```
  
  - [ ] `PerformanceMetric` model
    ```
    id, bot_id, date, trades_count, win_rate, profit_loss, drawdown
    ```

- [ ] Create database migrations
  - Use Flask-Migrate or Alembic
  - Initialize: `flask db init`
  - Create: `flask db migrate`
  - Apply: `flask db upgrade`

- [ ] Update modules to use database:
  - [ ] Monitoring: Save trades to database instead of just DataFrame
  - [ ] RiskManager: Track daily PnL in database
  - [ ] Execution: Log all trades to database
  - [ ] Dashboard: Query database for historical data

---

### 7. Frontend-Backend Integration Issues

**File:** `api_server.py` and `frontend/src/services/apiService.js`

- [ ] Complete route handlers in API Server
  - [ ] `/api/dashboard` - Connect `get_portfolio()`, `get_news()`, `get_analytics()`
  - [ ] `/api/bots` - Connect `get_bot_configurations()`
  - [ ] `/api/portfolio` - Create new endpoint
  - [ ] `/api/analytics` - Create new endpoint
  - [ ] `/api/news` - Create new endpoint
  - [ ] `/api/research` - Create new endpoint
  - [ ] `/api/bots/{botId}` - GET, PUT, DELETE methods
  - [ ] `/api/trades` - GET (history), POST (execute)

- [ ] Fix frontend hardcoded URLs
  - [ ] `apiService.js:3` - Use environment variable
  - [ ] `websocketService.js:62` - Use environment variable
  - [ ] Create `.env.example` for frontend
  - [ ] Update build process to use env vars

- [ ] Implement proper error handling
  - [ ] Frontend: Add error boundaries
  - [ ] Frontend: Handle 401/403 responses
  - [ ] Frontend: Retry logic for failed requests
  - [ ] Backend: Return proper error status codes

---

### 8. WebSocket Integration
**Files:** `main.py`, `api_server.py`, `frontend/src/utils/websocketService.js`

- [ ] Implement WebSocket message broadcasting
  - [ ] Create broadcaster utility in `main.py` or separate module
  - [ ] Broadcast `market_data` updates after fetching
  - [ ] Broadcast `trade_update` after execution
  - [ ] Broadcast `portfolio_update` after trades
  - [ ] Broadcast `alert` for risk triggers

- [ ] Implement subscriber management
  - [ ] Main.py: Track connected clients
  - [ ] Main.py: Broadcast to specific subscribers
  - [ ] Main.py: Clean up disconnected clients

- [ ] Add WebSocket authentication
  - [ ] Main.py: Verify JWT token on connect
  - [ ] Main.py: Associate client with user
  - [ ] Main.py: Only broadcast data user is authorized for

---

### 9. Authentication System
**Files:** `main.py`, `api_server.py`, `frontend/src/`

Backend:
- [ ] Fix authentication in API routes
  - Current: `main.py:31-60` defines `authenticate_request()` but doesn't enforce it
  - Should: Apply to all routes except `/health`
  - Should: Not require auth for auth endpoints (if any)

- [ ] Create login endpoint
  - [ ] Route: `POST /api/auth/login`
  - [ ] Parameters: username, password
  - [ ] Returns: JWT token, user info
  - [ ] Hash passwords with bcrypt (already in requirements)

- [ ] Create token refresh endpoint
  - [ ] Route: `POST /api/auth/refresh`
  - [ ] Parameters: refresh_token
  - [ ] Returns: New JWT token

Frontend:
- [ ] Create login page
  - [ ] Component: `LoginPage.jsx`
  - [ ] Form: username, password
  - [ ] Store JWT in localStorage
  - [ ] Redirect to dashboard on success

- [ ] Add token to API requests
  - [ ] Update `apiService.js`: Add Authorization header
  - [ ] Get token from localStorage
  - [ ] Refresh token on 401 response

- [ ] Protect routes
  - [ ] Redirect to login if no token
  - [ ] Check token expiry

---

### 10. Configuration Management
**All modules**

- [ ] Replace hardcoded values with configuration
  - [ ] Create `config.py` or use environment variables
  - [ ] `data_feed.py:24` - Parameterize BTC/USDT
  - [ ] `execution.py:69` - Parameterize BTC/USDT
  - [ ] `hedging.py:11` - Parameterize hedge ratio
  - [ ] `hedging.py:74` - Parameterize BTC/USDT
  - [ ] `arbitrage.py:36` - Parameterize BTC/USDT
  - [ ] `arbitrage.py:11` - Parameterize profit threshold

- [ ] Create configuration file
  - [ ] `config.py` with Config class
  - [ ] Support environment-specific configs (dev, test, prod)
  - [ ] Document all environment variables in `.env.example`

- [ ] Add configuration validation
  - [ ] Validate on startup
  - [ ] Provide helpful error messages if missing

---

## MODERATE ISSUES (Quality & Features)

### 11. Input Validation & Error Handling
**All modules**

- [ ] Add request validation in `api_server.py`
  - [ ] Use marshmallow or pydantic
  - [ ] Validate trade execution requests
  - [ ] Validate bot configuration updates
  - [ ] Return 400 for invalid input

- [ ] Add error recovery
  - [ ] Retry failed API calls
  - [ ] Handle exchange connection failures gracefully
  - [ ] Continue trading if one module fails
  - [ ] Log errors with full context

- [ ] Improve exception handling
  - [ ] Replace generic `except Exception:` with specific exceptions
  - [ ] Create custom exception classes
  - [ ] Log exceptions with stack traces
  - [ ] Send alerts on critical errors

---

### 12. Documentation Completion
**Project root**

- [ ] Create `README.md`
  - [ ] Project overview
  - [ ] Quick start guide
  - [ ] Architecture diagram
  - [ ] Feature list
  - [ ] Requirements
  - [ ] Installation steps
  - [ ] Usage examples

- [ ] Create `API_DOCUMENTATION.md`
  - [ ] Document all endpoints
  - [ ] Request/response formats
  - [ ] Authentication
  - [ ] Error codes
  - [ ] Rate limiting

- [ ] Create `DEPLOYMENT.md`
  - [ ] Server requirements
  - [ ] Installation steps
  - [ ] Database setup
  - [ ] Environment configuration
  - [ ] Running in production
  - [ ] Monitoring

- [ ] Create `ARCHITECTURE.md`
  - [ ] System design overview
  - [ ] Module descriptions
  - [ ] Data flow diagrams
  - [ ] API flow diagrams
  - [ ] WebSocket message flow

- [ ] Add module docstrings
  - [ ] Every module should have docstring
  - [ ] Every class should have docstring
  - [ ] Every public method should have docstring

---

### 13. Testing Implementation
**Files:** `tests/test_*.py`

- [ ] Complete `tests/test_data_feed.py`
  - [ ] `test_fetch_market_data()` - Not just `pass`
  - [ ] `test_process_data()` - Not just `pass`
  - [ ] Add: `test_subscriber_management()`
  - [ ] Add: `test_historical_data_retention()`
  - [ ] Add: `test_exchange_initialization()`

- [ ] Create `tests/test_signal_generator.py`
  - [ ] Test RSI signal generation
  - [ ] Test EMA signal generation
  - [ ] Test MACD signal generation
  - [ ] Test with edge cases (empty data, NaN values)

- [ ] Create `tests/test_risk_management.py`
  - [ ] Test daily loss limit checking
  - [ ] Test position size calculation
  - [ ] Test PnL tracking

- [ ] Create `tests/test_execution.py`
  - [ ] Test order placement
  - [ ] Test account balance retrieval
  - [ ] Test error handling

- [ ] Create integration tests
  - [ ] Test data_feed → signal_generator flow
  - [ ] Test signal_generator → execution flow
  - [ ] Test full trading loop

- [ ] Create API endpoint tests
  - [ ] Test `/api/dashboard` endpoint
  - [ ] Test `/api/bots` endpoint
  - [ ] Test authentication
  - [ ] Test error responses

- [ ] Aim for 80%+ code coverage

---

### 14. Frontend Completion
**File:** `frontend/src/pages/ResearchPage.jsx`

- [ ] Implement ResearchPage
  - [ ] Currently just a stub (7 lines)
  - [ ] Add market research tools
  - [ ] Add chart analysis tools
  - [ ] Add technical indicator visualization
  - [ ] Add strategy backtesting interface

- [ ] Add error boundaries
  - [ ] Create `ErrorBoundary.jsx` component
  - [ ] Wrap page routes with error boundary
  - [ ] Display user-friendly error messages

- [ ] Add loading states
  - [ ] Show loading spinner while fetching
  - [ ] Skeleton screens for better UX
  - [ ] Handle timeout scenarios

- [ ] Add environment variable support
  - [ ] Create `.env.example` file
  - [ ] Update webpack config to support env vars
  - [ ] Use `process.env.REACT_APP_*` pattern

---

### 15. Integration Issues - Broker Mismatch
**Files:** `modules/dashboard.py`, others

- [ ] Fix broker inconsistency
  - Current: `dashboard.py` uses Alpaca API
  - Other modules use Binance/CCXT
  - Action: Standardize on one broker or support multiple
  - Recommend: Remove dashboard.py or refactor to use same broker as others

---

## TESTING & QUALITY METRICS

### Current Status:
- Unit tests written: 0% (only stubs exist)
- Code coverage: Unknown (likely < 10%)
- Integration tests: 0
- API documentation: Missing
- Module documentation: 10% (some comments only)

### Goals:
- [ ] 80%+ unit test coverage
- [ ] All critical paths tested
- [ ] API documented with Swagger/OpenAPI
- [ ] All modules have docstrings
- [ ] All public methods documented

---

## PRIORITY SEQUENCE FOR FIXING

1. **WEEK 1: Critical Blockers**
   - [ ] Fix missing `time` import
   - [ ] Implement all missing subscriber methods
   - [ ] Implement `update_trades()` in Monitoring
   - [ ] Implement API endpoint handlers
   - [ ] Add `get_market_data()` alias to DataFeed

2. **WEEK 2: Backend Core**
   - [ ] Set up database with SQLAlchemy
   - [ ] Create all database models
   - [ ] Implement database persistence in modules
   - [ ] Complete API endpoints

3. **WEEK 3: Frontend Integration**
   - [ ] Fix hardcoded URLs
   - [ ] Implement WebSocket broadcasting
   - [ ] Add frontend error handling
   - [ ] Complete ResearchPage

4. **WEEK 4: Authentication & Security**
   - [ ] Implement login system
   - [ ] Add token management
   - [ ] Secure WebSocket connections
   - [ ] Add input validation

5. **WEEK 5: Testing**
   - [ ] Write unit tests for all modules
   - [ ] Write integration tests
   - [ ] Add API endpoint tests

6. **WEEK 6: Documentation**
   - [ ] Write README
   - [ ] Create architecture documentation
   - [ ] Write deployment guide
   - [ ] Add API documentation

---

## VERIFICATION CHECKLIST

After completing all fixes, verify:

- [ ] System starts without errors
- [ ] Trading loop executes without exceptions
- [ ] API endpoints return proper JSON responses
- [ ] Frontend connects to backend successfully
- [ ] WebSocket real-time updates work
- [ ] Trades are persisted to database
- [ ] Tests pass with 80%+ coverage
- [ ] No hardcoded URLs or credentials
- [ ] Proper error handling on all error paths
- [ ] Documentation is complete and accurate

