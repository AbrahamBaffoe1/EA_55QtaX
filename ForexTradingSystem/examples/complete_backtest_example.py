"""
Complete Backtesting Workflow Example

This script demonstrates the complete workflow for professional-grade
backtesting that prevents the 80-95% failure rate of algorithmic trading systems.

Workflow:
1. Load and prepare data
2. Configure backtesting engine
3. Define trading strategy
4. Run basic backtest
5. Calculate performance metrics
6. Perform walk-forward analysis
7. Analyze market regimes
8. Generate visualizations and reports

Author: Claude Code
Version: 1.0.0
"""

import sys
sys.path.append('/home/user/EA_55QtaX/ForexTradingSystem/modules')

import pandas as pd
import numpy as np
from decimal import Decimal
from datetime import datetime
from collections import deque

# Import backtesting modules
from backtesting_engine import (
    BacktestingEngine, BacktestConfig, OrderSide, OrderType, SlippageModel
)
from backtest_metrics import PerformanceAnalyzer
from walk_forward import WalkForwardAnalyzer, WalkForwardConfig
from market_regimes import RegimeDetector
from backtest_visualization import BacktestVisualizer


def generate_sample_data(days: int = 365, freq: str = '1H') -> pd.DataFrame:
    """
    Generate realistic sample OHLCV data for backtesting

    Args:
        days: Number of days of data
        freq: Data frequency ('1H', '4H', '1D', etc.)

    Returns:
        DataFrame with OHLCV data
    """
    print("📊 Generating sample market data...")

    # Generate dates
    dates = pd.date_range(
        start='2023-01-01',
        periods=days * 24 if freq == '1H' else days,
        freq=freq
    )

    # Generate realistic price movements
    np.random.seed(42)
    returns = np.random.randn(len(dates)) * 0.02  # 2% volatility
    trend = np.linspace(0, 0.5, len(dates))  # Upward trend
    prices = 100 * np.exp(np.cumsum(returns) + trend)

    # Create OHLCV data
    data = pd.DataFrame(index=dates)
    data['close'] = prices

    # Generate realistic OHLC
    data['open'] = data['close'].shift(1).fillna(data['close'][0])
    data['high'] = data[['open', 'close']].max(axis=1) * (1 + np.random.rand(len(dates)) * 0.01)
    data['low'] = data[['open', 'close']].min(axis=1) * (1 - np.random.rand(len(dates)) * 0.01)
    data['volume'] = np.random.randint(1000000, 10000000, len(dates))

    print(f"✅ Generated {len(data)} bars of data from {data.index[0]} to {data.index[-1]}")

    return data


class ExampleStrategy:
    """
    Example moving average crossover strategy with proper risk management
    """

    def __init__(self, fast_period: int = 10, slow_period: int = 30):
        """
        Initialize strategy

        Args:
            fast_period: Fast moving average period
            slow_period: Slow moving average period
        """
        self.fast_period = fast_period
        self.slow_period = slow_period
        self.price_history = deque(maxlen=slow_period + 1)
        print(f"📈 Strategy initialized: MA({fast_period}/{slow_period})")

    def calculate_signals(self):
        """Calculate moving averages and generate signals"""
        if len(self.price_history) < self.slow_period + 1:
            return None, None, None, None

        prices = list(self.price_history)

        # Current MAs
        fast_ma = np.mean(prices[-self.fast_period:])
        slow_ma = np.mean(prices[-self.slow_period:])

        # Previous MAs
        prev_fast_ma = np.mean(prices[-self.fast_period-1:-1])
        prev_slow_ma = np.mean(prices[-self.slow_period-1:-1])

        return fast_ma, slow_ma, prev_fast_ma, prev_slow_ma

    def __call__(self, engine: BacktestingEngine, bar: pd.Series, symbol: str):
        """
        Strategy logic executed on each bar

        Args:
            engine: Backtesting engine instance
            bar: Current OHLCV bar
            symbol: Trading symbol
        """
        # Track price history
        self.price_history.append(bar['close'])

        # Calculate signals
        fast_ma, slow_ma, prev_fast_ma, prev_slow_ma = self.calculate_signals()

        if fast_ma is None:
            return

        # Detect crossovers
        bullish_cross = prev_fast_ma <= prev_slow_ma and fast_ma > slow_ma
        bearish_cross = prev_fast_ma >= prev_slow_ma and fast_ma < slow_ma

        # Get current position
        current_position = engine.get_position_quantity(symbol)

        # Calculate position size (2% risk per trade)
        equity = engine.get_equity()
        risk_amount = equity * Decimal('0.02')
        position_size = risk_amount / Decimal(str(bar['close']))

        # Trading logic
        if bullish_cross and current_position == 0:
            # Buy signal
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.BUY,
                quantity=position_size,
                order_type=OrderType.MARKET
            )

        elif bearish_cross and current_position > 0:
            # Sell signal
            engine.submit_order(
                symbol=symbol,
                side=OrderSide.SELL,
                quantity=current_position,
                order_type=OrderType.MARKET
            )


def main():
    """Run complete backtesting workflow"""

    print("\n" + "="*80)
    print("PRODUCTION-GRADE BACKTESTING ENGINE")
    print("Preventing 80-95% Failure Rate of Algorithmic Trading Systems")
    print("="*80 + "\n")

    # ========================================================================
    # STEP 1: Generate/Load Data
    # ========================================================================
    print("STEP 1: Data Preparation")
    print("-" * 80)

    data = generate_sample_data(days=365, freq='1H')

    print(f"Data shape: {data.shape}")
    print(f"Columns: {list(data.columns)}")
    print()

    # ========================================================================
    # STEP 2: Configure Backtesting Engine
    # ========================================================================
    print("STEP 2: Configure Backtesting Engine")
    print("-" * 80)

    config = BacktestConfig(
        initial_capital=Decimal('100000'),
        commission_type="percentage",
        commission_rate=Decimal('0.001'),  # 0.1%
        slippage_model=SlippageModel.FIXED,
        slippage_rate=Decimal('0.0005'),   # 5 basis points
        max_position_size=Decimal('0.20'),  # 20% max position
        max_daily_loss=Decimal('0.02'),     # 2% daily loss limit
        risk_per_trade=Decimal('0.02'),     # 2% risk per trade
        allow_short_selling=True
    )

    print(f"✅ Initial Capital: ${config.initial_capital:,}")
    print(f"✅ Commission: {config.commission_rate:.2%}")
    print(f"✅ Slippage: {config.slippage_rate:.2%}")
    print(f"✅ Max Position Size: {config.max_position_size:.0%}")
    print()

    # ========================================================================
    # STEP 3: Run Basic Backtest
    # ========================================================================
    print("STEP 3: Run Basic Backtest")
    print("-" * 80)

    engine = BacktestingEngine(config)
    strategy = ExampleStrategy(fast_period=10, slow_period=30)

    results = engine.run_backtest(
        data=data,
        strategy_func=strategy,
        symbol="BTCUSDT"
    )

    print(f"\n✅ Backtest complete!")
    print(f"   Total trades: {results['trade_count']}")
    print(f"   Final equity: ${results['final_equity']:,.2f}")
    print(f"   Total return: {results['total_return']:.2%}")
    print()

    # ========================================================================
    # STEP 4: Calculate Performance Metrics
    # ========================================================================
    print("STEP 4: Calculate Performance Metrics")
    print("-" * 80)

    analyzer = PerformanceAnalyzer()
    metrics = analyzer.calculate_metrics(results)

    print(f"\n📊 Key Metrics:")
    print(f"   Sharpe Ratio: {metrics.sharpe_ratio:.2f}")
    print(f"   Sortino Ratio: {metrics.sortino_ratio:.2f}")
    print(f"   Max Drawdown: {metrics.max_drawdown:.2%}")
    print(f"   Win Rate: {metrics.win_rate:.2%}")
    print(f"   Profit Factor: {metrics.profit_factor:.2f}")
    print()

    # Print full report
    analyzer.print_report(metrics)

    # ========================================================================
    # STEP 5: Walk-Forward Analysis (Prevent Overfitting)
    # ========================================================================
    print("\nSTEP 5: Walk-Forward Analysis")
    print("-" * 80)

    wf_config = WalkForwardConfig(
        in_sample_ratio=0.7,
        anchored=False,
        min_in_sample_days=90,
        min_out_sample_days=30,
        optimization_metric="sharpe_ratio",
        optimization_method="grid",
        verbose=True
    )

    wf_analyzer = WalkForwardAnalyzer(wf_config, config)

    # Define parameter grid for optimization
    param_grid = {
        'fast_period': [5, 10, 15],
        'slow_period': [20, 30, 40]
    }

    # Strategy factory function
    def strategy_factory(engine, bar, symbol, fast_period, slow_period):
        if not hasattr(strategy_factory, 'strategies'):
            strategy_factory.strategies = {}

        key = f"{fast_period}_{slow_period}"
        if key not in strategy_factory.strategies:
            strategy_factory.strategies[key] = ExampleStrategy(fast_period, slow_period)

        return strategy_factory.strategies[key](engine, bar, symbol)

    print("\n⏳ Running walk-forward analysis (this may take a few minutes)...")
    print("   This prevents overfitting by testing on out-of-sample data\n")

    wf_results = wf_analyzer.run_walk_forward(
        data=data,
        strategy_func=strategy_factory,
        param_grid=param_grid,
        symbol="BTCUSDT"
    )

    # Print walk-forward summary
    print(f"\n📊 Walk-Forward Results:")
    print(f"   Periods analyzed: {len(wf_results.periods)}")
    print(f"   Overfitting score: {wf_results.overfitting_score:.2f} (0=none, 1=severe)")
    print(f"   Strategy valid: {'✅ YES' if wf_results.is_strategy_valid else '❌ NO'}")
    print()

    for rec in wf_results.recommendations:
        print(f"   {rec}")

    # ========================================================================
    # STEP 6: Market Regime Analysis (Detect Strategy Decay)
    # ========================================================================
    print("\n\nSTEP 6: Market Regime Analysis")
    print("-" * 80)

    detector = RegimeDetector(
        trend_lookback=20,
        volatility_lookback=20
    )

    # Detect regimes
    regime_series = detector.detect_market_regime(data)

    print(f"\n📊 Regime Distribution:")
    regime_counts = regime_series.value_counts()
    for regime, count in regime_counts.items():
        pct = count / len(regime_series) * 100
        print(f"   {regime.value:20s}: {count:5d} bars ({pct:5.1f}%)")

    # Analyze strategy performance by regime
    regime_analysis = detector.analyze_strategy_by_regime(
        data=data,
        trades=pd.DataFrame(results['trades']),
        equity_curve=pd.DataFrame(results['equity_curve'])
    )

    detector.print_regime_report(regime_analysis)

    # ========================================================================
    # STEP 7: Generate Visualizations
    # ========================================================================
    print("\nSTEP 7: Generate Visualizations")
    print("-" * 80)

    visualizer = BacktestVisualizer()

    print("\n📊 Creating visualizations...")

    # Generate complete report
    report_id = visualizer.create_full_report(
        results=results,
        metrics=metrics.to_dict(),
        output_dir="./backtest_reports"
    )

    print(f"\n✅ Complete report generated: {report_id}")
    print(f"   Location: ./backtest_reports/")
    print(f"   Files created:")
    print(f"      - {report_id}_equity_curve.png")
    print(f"      - {report_id}_monthly_returns.png")
    print(f"      - {report_id}_trade_analysis.png")
    print(f"      - {report_id}_dashboard.png")
    print(f"      - {report_id}_data.json")

    # ========================================================================
    # STEP 8: Final Assessment
    # ========================================================================
    print("\n" + "="*80)
    print("FINAL ASSESSMENT")
    print("="*80 + "\n")

    # Evaluate strategy quality
    issues = []
    strengths = []

    if metrics.sharpe_ratio < 1.0:
        issues.append(f"⚠️  Low Sharpe Ratio ({metrics.sharpe_ratio:.2f})")
    else:
        strengths.append(f"✅ Good Sharpe Ratio ({metrics.sharpe_ratio:.2f})")

    if metrics.max_drawdown < -0.25:
        issues.append(f"⚠️  High Max Drawdown ({metrics.max_drawdown:.2%})")
    else:
        strengths.append(f"✅ Acceptable Drawdown ({metrics.max_drawdown:.2%})")

    if metrics.win_rate < 0.40:
        issues.append(f"⚠️  Low Win Rate ({metrics.win_rate:.2%})")
    else:
        strengths.append(f"✅ Decent Win Rate ({metrics.win_rate:.2%})")

    if metrics.profit_factor < 1.5:
        issues.append(f"⚠️  Low Profit Factor ({metrics.profit_factor:.2f})")
    else:
        strengths.append(f"✅ Good Profit Factor ({metrics.profit_factor:.2f})")

    if wf_results.overfitting_score > 0.5:
        issues.append(f"⚠️  High Overfitting ({wf_results.overfitting_score:.2f})")
    else:
        strengths.append(f"✅ Low Overfitting ({wf_results.overfitting_score:.2f})")

    if not wf_results.is_strategy_valid:
        issues.append("⚠️  Strategy failed walk-forward validation")
    else:
        strengths.append("✅ Strategy passed walk-forward validation")

    # Print assessment
    if strengths:
        print("STRENGTHS:")
        for strength in strengths:
            print(f"  {strength}")
        print()

    if issues:
        print("ISSUES TO ADDRESS:")
        for issue in issues:
            print(f"  {issue}")
        print()

    # Overall verdict
    print("OVERALL VERDICT:")
    if len(issues) == 0:
        print("  🎉 Excellent! Strategy shows strong potential for live trading.")
        print("     Continue with paper trading to validate in real-time conditions.")
    elif len(issues) <= 2:
        print("  👍 Good strategy with some areas for improvement.")
        print("     Address the issues above before live trading.")
    else:
        print("  ⚠️  Strategy needs significant improvements.")
        print("     Do NOT proceed to live trading without addressing critical issues.")

    print("\n" + "="*80)
    print("BACKTEST COMPLETE")
    print("="*80 + "\n")

    print("💡 Next Steps:")
    print("   1. Review the generated reports in ./backtest_reports/")
    print("   2. Address any issues identified above")
    print("   3. Test on different market conditions")
    print("   4. Run paper trading to validate real-time performance")
    print("   5. Implement additional risk controls")
    print()
    print("Remember: Past performance does not guarantee future results!")
    print()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Backtest interrupted by user")
    except Exception as e:
        print(f"\n\n❌ Error occurred: {str(e)}")
        import traceback
        traceback.print_exc()
