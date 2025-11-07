# Production-Grade Backtesting Engine

## 🎯 Overview

This is a **professional-grade backtesting engine** designed to prevent the 80-95% failure rate of algorithmic trading systems by addressing the key failure points:

✅ **Prevents Overfitting** - Walk-forward analysis with in-sample/out-of-sample validation
✅ **Realistic Costs** - Accurate slippage and commission modeling
✅ **Market Regime Awareness** - Detects strategy decay and changing conditions
✅ **Robust Risk Management** - Position sizing, daily loss limits, drawdown tracking
✅ **Comprehensive Metrics** - Sharpe, Sortino, Calmar, profit factor, and more

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Core Features](#core-features)
3. [Running a Basic Backtest](#running-a-basic-backtest)
4. [Walk-Forward Analysis](#walk-forward-analysis)
5. [Market Regime Detection](#market-regime-detection)
6. [Performance Metrics](#performance-metrics)
7. [Visualization](#visualization)
8. [Example Strategies](#example-strategies)
9. [Best Practices](#best-practices)
10. [API Reference](#api-reference)

---

## 🚀 Quick Start

### Installation

```bash
cd /home/user/EA_55QtaX/ForexTradingSystem
pip install -r requirements.txt
```

### Basic Example

```python
import sys
sys.path.append('/home/user/EA_55QtaX/ForexTradingSystem/modules')

import pandas as pd
from decimal import Decimal
from backtesting_engine import BacktestingEngine, BacktestConfig, OrderSide, OrderType
from backtest_metrics import PerformanceAnalyzer
from backtest_visualization import BacktestVisualizer

# Load your data
data = pd.read_csv('your_data.csv', index_col='timestamp', parse_dates=True)
# Data should have columns: open, high, low, close, volume

# Configure backtest
config = BacktestConfig(
    initial_capital=Decimal('100000'),
    commission_rate=Decimal('0.001'),  # 0.1%
    slippage_rate=Decimal('0.0005')    # 5 basis points
)

# Create engine
engine = BacktestingEngine(config)

# Define strategy
def my_strategy(engine, bar, symbol):
    current_position = engine.get_position_quantity(symbol)

    # Example: simple buy and hold
    if engine.trade_count == 0:
        engine.submit_order(
            symbol=symbol,
            side=OrderSide.BUY,
            quantity=Decimal('10'),
            order_type=OrderType.MARKET
        )

# Run backtest
results = engine.run_backtest(data, my_strategy, symbol="BTCUSDT")

# Analyze results
analyzer = PerformanceAnalyzer()
metrics = analyzer.calculate_metrics(results)
analyzer.print_report(metrics)

# Visualize
visualizer = BacktestVisualizer()
visualizer.plot_equity_curve(results['equity_curve'])
```

---

## 🔧 Core Features

### 1. Event-Driven Architecture

The engine processes market data bar-by-bar, simulating realistic order execution:

- **Market Orders**: Fill at next bar's open/close
- **Limit Orders**: Fill when price touches limit
- **Stop Orders**: Trigger when stop price is hit
- **Partial Fills**: Optional support for realistic fills

### 2. Slippage Models

Choose from multiple slippage models:

```python
from backtesting_engine import SlippageModel

config = BacktestConfig(
    slippage_model=SlippageModel.FIXED,  # Options:
    # NONE - No slippage (unrealistic)
    # FIXED - Fixed basis points
    # PERCENTAGE - Percentage of price
    # VOLUME_BASED - Based on order size vs volume
    # SPREAD_BASED - Based on bid-ask spread
    slippage_rate=Decimal('0.0005')
)
```

### 3. Commission Models

Realistic commission structures:

```python
config = BacktestConfig(
    commission_type="percentage",  # Options: "fixed", "percentage", "tiered"
    commission_rate=Decimal('0.001'),  # 0.1%
    min_commission=Decimal('1.00')  # Minimum per trade
)
```

### 4. Risk Management

Built-in risk controls:

```python
config = BacktestConfig(
    max_position_size=Decimal('0.10'),  # 10% of portfolio
    max_daily_loss=Decimal('0.02'),     # 2% daily loss limit
    risk_per_trade=Decimal('0.02'),     # 2% risk per trade
    max_leverage=Decimal('1.0'),        # No leverage
    allow_short_selling=True
)
```

---

## 📊 Running a Basic Backtest

### Step 1: Prepare Data

```python
import pandas as pd
import numpy as np

# Your data should be a DataFrame with OHLCV columns
# Index should be datetime

# Example: Generate sample data
dates = pd.date_range(start='2023-01-01', end='2024-01-01', freq='1H')
data = pd.DataFrame({
    'open': 100 + np.cumsum(np.random.randn(len(dates)) * 0.5),
    'high': 100 + np.cumsum(np.random.randn(len(dates)) * 0.5) + 1,
    'low': 100 + np.cumsum(np.random.randn(len(dates)) * 0.5) - 1,
    'close': 100 + np.cumsum(np.random.randn(len(dates)) * 0.5),
    'volume': np.random.randint(1000, 10000, len(dates))
}, index=dates)
```

### Step 2: Create Strategy

```python
from decimal import Decimal
from collections import deque

class MovingAverageCrossover:
    def __init__(self, fast=10, slow=30):
        self.fast = fast
        self.slow = slow
        self.prices = deque(maxlen=slow)

    def __call__(self, engine, bar, symbol):
        self.prices.append(bar['close'])

        if len(self.prices) < self.slow:
            return

        fast_ma = np.mean(list(self.prices)[-self.fast:])
        slow_ma = np.mean(list(self.prices)[-self.slow:])

        current_position = engine.get_position_quantity(symbol)

        # Position sizing (2% risk)
        equity = engine.get_equity()
        position_size = equity * Decimal('0.02') / Decimal(str(bar['close']))

        # Trading logic
        if fast_ma > slow_ma and current_position == 0:
            # Buy signal
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.BUY,
                quantity=position_size,
                order_type=OrderType.MARKET
            )
        elif fast_ma < slow_ma and current_position > 0:
            # Sell signal
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.SELL,
                quantity=current_position,
                order_type=OrderType.MARKET
            )

strategy = MovingAverageCrossover(fast=10, slow=30)
```

### Step 3: Run and Analyze

```python
results = engine.run_backtest(data, strategy, symbol="BTCUSDT")

# Get metrics
metrics = analyzer.calculate_metrics(results)

# Print detailed report
analyzer.print_report(metrics)

# Access specific metrics
print(f"Sharpe Ratio: {metrics.sharpe_ratio:.2f}")
print(f"Max Drawdown: {metrics.max_drawdown:.2%}")
print(f"Win Rate: {metrics.win_rate:.2%}")
print(f"Total Return: {metrics.total_return:.2%}")
```

---

## 🔄 Walk-Forward Analysis

**Critical for preventing overfitting!**

Walk-forward analysis optimizes parameters on in-sample data and tests on out-of-sample data, rolling this process forward through time.

### Basic Walk-Forward

```python
from walk_forward import WalkForwardAnalyzer, WalkForwardConfig

# Configure walk-forward
wf_config = WalkForwardConfig(
    in_sample_ratio=0.7,  # 70% in-sample, 30% out-of-sample
    anchored=False,  # Rolling window (True for anchored)
    min_in_sample_days=90,
    min_out_sample_days=30,
    optimization_metric="sharpe_ratio",
    optimization_method="grid"  # or "differential_evolution"
)

# Create analyzer
wf_analyzer = WalkForwardAnalyzer(wf_config, backtest_config)

# Define parameter grid
param_grid = {
    'fast_period': [5, 10, 15, 20],
    'slow_period': [20, 30, 40, 50]
}

# Strategy factory function
def strategy_factory(engine, bar, symbol, fast_period, slow_period):
    # Your strategy logic using these parameters
    pass

# Run walk-forward analysis
wf_results = wf_analyzer.run_walk_forward(
    data=data,
    strategy_func=strategy_factory,
    param_grid=param_grid,
    symbol="BTCUSDT"
)

# Print results
wf_analyzer._print_summary(wf_results)

# Check if strategy is valid
if wf_results.is_strategy_valid:
    print("✅ Strategy passes walk-forward validation!")
else:
    print("❌ Strategy shows signs of overfitting")

for rec in wf_results.recommendations:
    print(rec)
```

### Interpreting Walk-Forward Results

- **Overfitting Score < 0.3**: ✅ Good - minimal overfitting
- **Overfitting Score 0.3-0.5**: ⚠️ Moderate - review carefully
- **Overfitting Score > 0.5**: ❌ High - likely overfit

**Parameter Stability > 0.7**: Parameters are consistent across periods (good)

---

## 🌡️ Market Regime Detection

Detect when market conditions change to prevent strategy decay.

### Detecting Regimes

```python
from market_regimes import RegimeDetector

# Create detector
detector = RegimeDetector(
    trend_lookback=20,
    volatility_lookback=20
)

# Detect regimes
regime_series = detector.detect_market_regime(data)

print(f"Current regime: {regime_series.iloc[-1]}")

# Analyze strategy by regime
regime_analysis = detector.analyze_strategy_by_regime(
    data=data,
    trades=pd.DataFrame(results['trades']),
    equity_curve=pd.DataFrame(results['equity_curve'])
)

# Print regime report
detector.print_regime_report(regime_analysis)
```

### Regime Types

1. **TRENDING_HIGH_VOL**: Strong directional moves with high volatility
2. **TRENDING_LOW_VOL**: Steady trends with low volatility
3. **RANGING_HIGH_VOL**: Choppy, sideways markets
4. **RANGING_LOW_VOL**: Quiet, low-volatility consolidation

### Using Regime Detection in Strategy

```python
def regime_aware_strategy(engine, bar, symbol):
    # Get current regime
    regime = detector.detect_market_regime(data.loc[:bar.name])[-1]

    # Adapt strategy based on regime
    if regime == MarketRegime.TRENDING_LOW_VOL:
        # Use trend-following
        # ... your trend logic
        pass
    elif regime == MarketRegime.RANGING_HIGH_VOL:
        # Use mean-reversion
        # ... your mean-reversion logic
        pass
```

---

## 📈 Performance Metrics

### Available Metrics

**Returns:**
- Total Return
- Annualized Return
- CAGR (Compound Annual Growth Rate)

**Risk Metrics:**
- Volatility (annualized)
- Sharpe Ratio
- Sortino Ratio
- Calmar Ratio
- Omega Ratio
- Max Drawdown
- Max Drawdown Duration
- Recovery Factor

**Trade Statistics:**
- Total Trades
- Win Rate
- Profit Factor
- Expectancy
- Average Win / Loss
- Largest Win / Loss

**Consistency:**
- Best/Worst Day
- Best/Worst Month
- Positive Days %
- Positive Months %
- Consecutive Wins/Losses

**Distribution:**
- Skewness
- Kurtosis
- VaR (Value at Risk)
- CVaR (Conditional VaR)

**Costs:**
- Total Commission
- Total Slippage
- Commission % of Profit
- Slippage % of Profit

### Accessing Metrics

```python
# Calculate all metrics
metrics = analyzer.calculate_metrics(results)

# Convert to dict for JSON export
metrics_dict = metrics.to_dict()

# Access specific metrics
print(f"Sharpe Ratio: {metrics.sharpe_ratio:.2f}")
print(f"Max Drawdown: {metrics.max_drawdown:.2%}")
print(f"Win Rate: {metrics.win_rate:.2%}")
print(f"Profit Factor: {metrics.profit_factor:.2f}")

# Get monthly/yearly returns
monthly_returns = metrics.monthly_returns
yearly_returns = metrics.yearly_returns
```

---

## 📊 Visualization

Create professional charts and reports:

### Equity Curve

```python
visualizer = BacktestVisualizer()

# Plot equity with drawdown
visualizer.plot_equity_curve(
    equity_curve=results['equity_curve'],
    title="Strategy Equity Curve",
    save_path="equity_curve.png"
)
```

### Monthly Returns Heatmap

```python
visualizer.plot_monthly_returns(
    equity_curve=results['equity_curve'],
    title="Monthly Returns",
    save_path="monthly_returns.png"
)
```

### Trade Analysis

```python
visualizer.plot_trade_analysis(
    trades=results['trades'],
    title="Trade Analysis",
    save_path="trade_analysis.png"
)
```

### Metrics Dashboard

```python
metrics_dict = metrics.to_dict()

visualizer.plot_metrics_dashboard(
    metrics=metrics_dict,
    title="Performance Dashboard",
    save_path="dashboard.png"
)
```

### Complete Report

```python
# Generate complete report with all charts
report_id = visualizer.create_full_report(
    results=results,
    metrics=metrics_dict,
    output_dir="./backtest_reports"
)

print(f"Report saved: {report_id}")
```

---

## 💡 Example Strategies

Pre-built strategies in `examples/example_strategies.py`:

### 1. Moving Average Crossover

```python
from examples.example_strategies import MovingAverageCrossover

strategy = MovingAverageCrossover(fast_period=10, slow_period=30)
results = engine.run_backtest(data, strategy, symbol="BTCUSDT")
```

### 2. RSI Mean Reversion

```python
from examples.example_strategies import RSIMeanReversion

strategy = RSIMeanReversion(rsi_period=14, oversold=30, overbought=70)
results = engine.run_backtest(data, strategy, symbol="BTCUSDT")
```

### 3. MACD Trend Following

```python
from examples.example_strategies import MACDTrendFollowing

strategy = MACDTrendFollowing(fast=12, slow=26, signal=9)
results = engine.run_backtest(data, strategy, symbol="BTCUSDT")
```

### 4. Bollinger Bands Breakout

```python
from examples.example_strategies import BollingerBandsBreakout

strategy = BollingerBandsBreakout(period=20, std_dev=2.0)
results = engine.run_backtest(data, strategy, symbol="BTCUSDT")
```

---

## ✅ Best Practices

### 1. Always Use Walk-Forward Analysis

```python
# ❌ BAD: Optimize on all data
results = engine.run_backtest(all_data, strategy)

# ✅ GOOD: Use walk-forward analysis
wf_results = wf_analyzer.run_walk_forward(all_data, strategy, param_grid)
```

### 2. Account for Realistic Costs

```python
# ❌ BAD: No slippage or commission
config = BacktestConfig(
    slippage_model=SlippageModel.NONE,
    commission_rate=Decimal('0')
)

# ✅ GOOD: Realistic costs
config = BacktestConfig(
    slippage_model=SlippageModel.VOLUME_BASED,
    commission_rate=Decimal('0.001'),  # 0.1%
    slippage_rate=Decimal('0.0005')    # 5 bps
)
```

### 3. Use Proper Position Sizing

```python
# ❌ BAD: Fixed position size
quantity = Decimal('100')

# ✅ GOOD: Risk-based position sizing
equity = engine.get_equity()
risk_amount = equity * Decimal('0.02')  # 2% risk
quantity = risk_amount / Decimal(str(atr))  # Based on volatility
```

### 4. Monitor Regime Changes

```python
# ✅ Check if regime has changed recently
regime_changed, confidence = detector.detect_regime_change(
    regime_series,
    window=20
)

if regime_changed:
    print(f"⚠️ Regime change detected (confidence: {confidence:.2%})")
    # Consider pausing trading or adapting parameters
```

### 5. Track Key Metrics

```python
# Minimum acceptable metrics
if metrics.sharpe_ratio < 1.0:
    print("⚠️ Low Sharpe ratio")

if metrics.max_drawdown < -0.25:
    print("⚠️ High drawdown")

if metrics.win_rate < 0.40:
    print("⚠️ Low win rate")

if metrics.profit_factor < 1.5:
    print("⚠️ Low profit factor")
```

### 6. Test on Multiple Timeframes

```python
# Test strategy on different timeframes
for timeframe in ['1H', '4H', '1D']:
    resampled_data = data.resample(timeframe).agg({
        'open': 'first',
        'high': 'max',
        'low': 'min',
        'close': 'last',
        'volume': 'sum'
    })

    results = engine.run_backtest(resampled_data, strategy)
    print(f"{timeframe}: Sharpe = {metrics.sharpe_ratio:.2f}")
```

---

## 📚 API Reference

### BacktestConfig

```python
BacktestConfig(
    initial_capital: Decimal = Decimal('100000'),
    commission_type: str = "percentage",
    commission_rate: Decimal = Decimal('0.001'),
    min_commission: Decimal = Decimal('0'),
    slippage_model: SlippageModel = SlippageModel.FIXED,
    slippage_rate: Decimal = Decimal('0.0005'),
    max_position_size: Decimal = Decimal('0.1'),
    max_leverage: Decimal = Decimal('1.0'),
    max_daily_loss: Decimal = Decimal('0.02'),
    risk_per_trade: Decimal = Decimal('0.02'),
    allow_short_selling: bool = True,
    allow_hedging: bool = False,
    fill_on_bar_close: bool = True,
    validate_orders: bool = True
)
```

### BacktestingEngine Methods

```python
engine.submit_order(symbol, side, quantity, order_type, price=None, stop_price=None)
engine.get_equity() -> Decimal
engine.get_position(symbol) -> Optional[Position]
engine.get_position_quantity(symbol) -> Decimal
engine.run_backtest(data, strategy_func, symbol) -> Dict[str, Any]
engine.get_results() -> Dict[str, Any]
engine.reset()
```

### PerformanceAnalyzer Methods

```python
analyzer.calculate_metrics(results) -> PerformanceMetrics
analyzer.print_report(metrics)
```

### WalkForwardAnalyzer Methods

```python
wf_analyzer.run_walk_forward(data, strategy_func, param_grid, symbol) -> WalkForwardResults
wf_analyzer.split_periods(data) -> List[Tuple[pd.DataFrame, pd.DataFrame]]
wf_analyzer.optimize_parameters(data, strategy_func, param_grid, symbol) -> Tuple[Dict, float]
```

### RegimeDetector Methods

```python
detector.detect_market_regime(data) -> pd.Series
detector.analyze_strategy_by_regime(data, trades, equity_curve) -> RegimeAnalysis
detector.detect_regime_change(regime_series, window) -> Tuple[bool, float]
detector.print_regime_report(analysis)
```

---

## 🧪 Running Tests

```bash
# Run all backtesting tests
cd /home/user/EA_55QtaX/ForexTradingSystem
pytest tests/test_backtesting_engine.py -v

# Run with coverage
pytest tests/test_backtesting_engine.py --cov=modules --cov-report=html

# Run specific test
pytest tests/test_backtesting_engine.py::TestBacktestingEngine::test_market_order_execution -v
```

---

## 🎓 Learning Resources

### Understanding Key Concepts

**Sharpe Ratio**: Risk-adjusted return. Higher is better.
- < 1.0: Poor
- 1.0-2.0: Good
- \> 2.0: Excellent

**Max Drawdown**: Largest peak-to-trough decline.
- < -10%: Good
- -10% to -25%: Acceptable
- \> -25%: Risky

**Profit Factor**: Gross profit / Gross loss.
- < 1.0: Losing strategy
- 1.0-1.5: Marginal
- 1.5-2.0: Good
- \> 2.0: Excellent

**Win Rate**: Percentage of winning trades.
- 40-60%: Typical
- \> 60%: Very good (but check profit factor)

---

## 📞 Support

For issues or questions:
- GitHub Issues: https://github.com/anthropics/claude-code/issues
- Documentation: This file

---

## 📄 License

Copyright 2024. See LICENSE file for details.

---

**Remember**: A strategy that looks too good in backtesting is probably overfit.
Always validate with walk-forward analysis and test on out-of-sample data!

Good luck with your trading strategies! 🚀
