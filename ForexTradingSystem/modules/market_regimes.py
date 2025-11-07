"""
Market Regime Detection and Strategy Decay Prevention

This module identifies market regimes and detects when strategies stop working
due to changing market conditions - a major cause of trading system failure.

Key Features:
- Trend vs. range detection
- Volatility regime classification
- Correlation regime analysis
- Strategy performance by regime
- Regime change detection and alerts
- Adaptive parameter recommendations

Author: Claude Code
Version: 1.0.0
"""

import logging
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
import pandas as pd
import numpy as np
from scipy import stats
from collections import defaultdict

logger = logging.getLogger(__name__)


class TrendRegime(Enum):
    """Market trend regimes"""
    STRONG_UPTREND = "strong_uptrend"
    WEAK_UPTREND = "weak_uptrend"
    RANGING = "ranging"
    WEAK_DOWNTREND = "weak_downtrend"
    STRONG_DOWNTREND = "strong_downtrend"


class VolatilityRegime(Enum):
    """Volatility regimes"""
    VERY_LOW = "very_low"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    VERY_HIGH = "very_high"


class MarketRegime(Enum):
    """Combined market regimes"""
    TRENDING_HIGH_VOL = "trending_high_vol"  # Strong directional moves
    TRENDING_LOW_VOL = "trending_low_vol"   # Steady trends
    RANGING_HIGH_VOL = "ranging_high_vol"   # Choppy markets
    RANGING_LOW_VOL = "ranging_low_vol"     # Quiet markets


@dataclass
class RegimeMetrics:
    """Metrics for a specific regime"""
    regime: MarketRegime
    total_bars: int
    total_trades: int
    win_rate: float
    avg_return: float
    sharpe_ratio: float
    max_drawdown: float
    profit_factor: float


@dataclass
class RegimeAnalysis:
    """Complete regime analysis results"""
    regime_history: pd.DataFrame  # Timestamp, regime classification
    current_regime: MarketRegime
    regime_metrics: Dict[MarketRegime, RegimeMetrics]
    regime_stability: float  # How often regime changes (0-1)
    best_regime: MarketRegime
    worst_regime: MarketRegime
    recommendations: List[str]


class RegimeDetector:
    """
    Detect market regimes and analyze strategy performance by regime

    This helps prevent strategy failure by:
    1. Identifying when market conditions have changed
    2. Alerting when strategy is in unfavorable regime
    3. Providing regime-specific performance metrics
    4. Suggesting when to adapt or pause trading
    """

    def __init__(self,
                 trend_lookback: int = 20,
                 volatility_lookback: int = 20,
                 regime_change_threshold: float = 0.3):
        """
        Initialize regime detector

        Args:
            trend_lookback: Periods for trend calculation
            volatility_lookback: Periods for volatility calculation
            regime_change_threshold: Sensitivity for regime changes (0-1)
        """
        self.trend_lookback = trend_lookback
        self.volatility_lookback = volatility_lookback
        self.regime_change_threshold = regime_change_threshold

        logger.info("Market regime detector initialized")

    def detect_trend_regime(self, data: pd.DataFrame) -> pd.Series:
        """
        Detect trend regime for each bar

        Uses multiple indicators:
        - ADX (Average Directional Index) for trend strength
        - Linear regression slope for trend direction
        - Price position vs. moving average

        Args:
            data: OHLC data

        Returns:
            Series of TrendRegime values
        """
        close = data['close']

        # Calculate trend indicators
        # 1. Linear regression slope
        def calc_slope(window):
            x = np.arange(len(window))
            slope, _, _, _, _ = stats.linregress(x, window)
            return slope

        slopes = close.rolling(window=self.trend_lookback).apply(calc_slope, raw=True)
        slope_std = slopes.std()

        # 2. Moving average position
        sma = close.rolling(window=self.trend_lookback).mean()
        position_above_ma = (close - sma) / sma

        # 3. ADX-like trend strength (simplified)
        high = data['high']
        low = data['low']
        tr = pd.concat([
            high - low,
            abs(high - close.shift(1)),
            abs(low - close.shift(1))
        ], axis=1).max(axis=1)

        atr = tr.rolling(window=14).mean()
        trend_strength = abs(slopes) / (atr / close)

        # Classify trend regime
        regimes = []
        for i in range(len(data)):
            if pd.isna(slopes.iloc[i]) or pd.isna(trend_strength.iloc[i]):
                regimes.append(TrendRegime.RANGING)
                continue

            slope = slopes.iloc[i]
            strength = trend_strength.iloc[i]
            pos_ma = position_above_ma.iloc[i]

            # Classify based on slope and strength
            if strength > 0.5:  # Strong trend
                if slope > 0.5 * slope_std:
                    regimes.append(TrendRegime.STRONG_UPTREND)
                elif slope < -0.5 * slope_std:
                    regimes.append(TrendRegime.STRONG_DOWNTREND)
                else:
                    regimes.append(TrendRegime.RANGING)
            elif strength > 0.2:  # Weak trend
                if slope > 0.2 * slope_std and pos_ma > 0:
                    regimes.append(TrendRegime.WEAK_UPTREND)
                elif slope < -0.2 * slope_std and pos_ma < 0:
                    regimes.append(TrendRegime.WEAK_DOWNTREND)
                else:
                    regimes.append(TrendRegime.RANGING)
            else:  # Ranging
                regimes.append(TrendRegime.RANGING)

        return pd.Series(regimes, index=data.index)

    def detect_volatility_regime(self, data: pd.DataFrame) -> pd.Series:
        """
        Detect volatility regime for each bar

        Uses:
        - Historical volatility (std of returns)
        - ATR (Average True Range)
        - Percentile ranking

        Args:
            data: OHLC data

        Returns:
            Series of VolatilityRegime values
        """
        close = data['close']
        returns = close.pct_change()

        # Calculate volatility indicators
        # 1. Rolling standard deviation (annualized)
        volatility = returns.rolling(window=self.volatility_lookback).std() * np.sqrt(252)

        # 2. ATR
        high = data['high']
        low = data['low']
        tr = pd.concat([
            high - low,
            abs(high - close.shift(1)),
            abs(low - close.shift(1))
        ], axis=1).max(axis=1)

        atr = tr.rolling(window=14).mean()
        atr_pct = atr / close  # Normalize by price

        # Combine metrics
        combined_vol = (volatility + atr_pct) / 2

        # Calculate percentile rankings (rolling)
        percentiles = combined_vol.rolling(window=100).apply(
            lambda x: stats.percentileofscore(x, x.iloc[-1]) if len(x) > 1 else 50
        )

        # Classify volatility regime
        regimes = []
        for percentile in percentiles:
            if pd.isna(percentile):
                regimes.append(VolatilityRegime.MEDIUM)
            elif percentile <= 20:
                regimes.append(VolatilityRegime.VERY_LOW)
            elif percentile <= 40:
                regimes.append(VolatilityRegime.LOW)
            elif percentile <= 60:
                regimes.append(VolatilityRegime.MEDIUM)
            elif percentile <= 80:
                regimes.append(VolatilityRegime.HIGH)
            else:
                regimes.append(VolatilityRegime.VERY_HIGH)

        return pd.Series(regimes, index=data.index)

    def detect_market_regime(self, data: pd.DataFrame) -> pd.Series:
        """
        Detect combined market regime (trend + volatility)

        Args:
            data: OHLC data

        Returns:
            Series of MarketRegime values
        """
        trend_regimes = self.detect_trend_regime(data)
        vol_regimes = self.detect_volatility_regime(data)

        regimes = []
        for trend, vol in zip(trend_regimes, vol_regimes):
            # Determine if trending or ranging
            is_trending = trend in [
                TrendRegime.STRONG_UPTREND,
                TrendRegime.STRONG_DOWNTREND,
                TrendRegime.WEAK_UPTREND,
                TrendRegime.WEAK_DOWNTREND
            ]

            # Determine volatility level
            is_high_vol = vol in [VolatilityRegime.HIGH, VolatilityRegime.VERY_HIGH]

            # Combine
            if is_trending and is_high_vol:
                regimes.append(MarketRegime.TRENDING_HIGH_VOL)
            elif is_trending and not is_high_vol:
                regimes.append(MarketRegime.TRENDING_LOW_VOL)
            elif not is_trending and is_high_vol:
                regimes.append(MarketRegime.RANGING_HIGH_VOL)
            else:
                regimes.append(MarketRegime.RANGING_LOW_VOL)

        return pd.Series(regimes, index=data.index)

    def analyze_strategy_by_regime(self,
                                   data: pd.DataFrame,
                                   trades: pd.DataFrame,
                                   equity_curve: pd.DataFrame) -> RegimeAnalysis:
        """
        Analyze strategy performance across different market regimes

        Args:
            data: OHLC data
            trades: Trade history
            equity_curve: Equity curve with timestamp and equity

        Returns:
            RegimeAnalysis with comprehensive regime-based metrics
        """
        logger.info("Analyzing strategy performance by market regime...")

        # Detect regimes
        regime_series = self.detect_market_regime(data)

        # Create regime history DataFrame
        regime_history = pd.DataFrame({
            'regime': regime_series
        })

        current_regime = regime_series.iloc[-1] if len(regime_series) > 0 else MarketRegime.RANGING_LOW_VOL

        # Calculate regime metrics
        regime_metrics = {}

        for regime in MarketRegime:
            # Get periods in this regime
            regime_mask = regime_series == regime
            regime_bars = regime_mask.sum()

            if regime_bars == 0:
                continue

            # Get equity curve for this regime
            # Match equity curve timestamps with regime timestamps
            equity_df = equity_curve.copy()
            equity_df['regime'] = regime_series.reindex(equity_df.index, method='ffill')

            regime_equity = equity_df[equity_df['regime'] == regime]

            if len(regime_equity) < 2:
                continue

            # Calculate returns for this regime
            regime_returns = regime_equity['equity'].pct_change().dropna()

            # Calculate metrics
            total_trades = len(trades) if len(trades) > 0 else 0

            if len(regime_returns) > 0:
                avg_return = regime_returns.mean()
                volatility = regime_returns.std()
                sharpe = (avg_return / volatility * np.sqrt(252)
                         if volatility > 0 else 0)

                # Calculate drawdown
                equity_values = regime_equity['equity'].values
                running_max = np.maximum.accumulate(equity_values)
                drawdown = (equity_values - running_max) / running_max
                max_drawdown = drawdown.min()

                # Estimate win rate and profit factor (simplified)
                positive_returns = regime_returns[regime_returns > 0]
                negative_returns = regime_returns[regime_returns < 0]

                win_rate = len(positive_returns) / len(regime_returns) if len(regime_returns) > 0 else 0
                profit_factor = (abs(positive_returns.sum()) / abs(negative_returns.sum())
                               if len(negative_returns) > 0 and negative_returns.sum() != 0 else 0)
            else:
                avg_return = 0
                sharpe = 0
                max_drawdown = 0
                win_rate = 0
                profit_factor = 0

            regime_metrics[regime] = RegimeMetrics(
                regime=regime,
                total_bars=regime_bars,
                total_trades=total_trades,
                win_rate=win_rate,
                avg_return=avg_return,
                sharpe_ratio=sharpe,
                max_drawdown=max_drawdown,
                profit_factor=profit_factor
            )

        # Calculate regime stability (how often regime changes)
        regime_changes = (regime_series != regime_series.shift(1)).sum()
        regime_stability = 1 - (regime_changes / len(regime_series))

        # Find best and worst regimes
        if regime_metrics:
            best_regime = max(regime_metrics.items(),
                            key=lambda x: x[1].sharpe_ratio)[0]
            worst_regime = min(regime_metrics.items(),
                             key=lambda x: x[1].sharpe_ratio)[0]
        else:
            best_regime = MarketRegime.TRENDING_LOW_VOL
            worst_regime = MarketRegime.RANGING_HIGH_VOL

        # Generate recommendations
        recommendations = self._generate_regime_recommendations(
            current_regime,
            regime_metrics,
            regime_stability,
            best_regime,
            worst_regime
        )

        analysis = RegimeAnalysis(
            regime_history=regime_history,
            current_regime=current_regime,
            regime_metrics=regime_metrics,
            regime_stability=regime_stability,
            best_regime=best_regime,
            worst_regime=worst_regime,
            recommendations=recommendations
        )

        logger.info("Regime analysis complete")
        return analysis

    def _generate_regime_recommendations(self,
                                        current_regime: MarketRegime,
                                        regime_metrics: Dict[MarketRegime, RegimeMetrics],
                                        regime_stability: float,
                                        best_regime: MarketRegime,
                                        worst_regime: MarketRegime) -> List[str]:
        """Generate actionable recommendations based on regime analysis"""
        recommendations = []

        # Current regime assessment
        if current_regime in regime_metrics:
            current_metrics = regime_metrics[current_regime]

            recommendations.append(
                f"📊 Current regime: {current_regime.value.replace('_', ' ').title()}"
            )

            if current_metrics.sharpe_ratio > 1.0:
                recommendations.append(
                    f"✅ FAVORABLE CONDITIONS: Strategy performs well in current regime "
                    f"(Sharpe: {current_metrics.sharpe_ratio:.2f})"
                )
            elif current_metrics.sharpe_ratio < 0.5:
                recommendations.append(
                    f"⚠️ UNFAVORABLE CONDITIONS: Strategy underperforms in current regime "
                    f"(Sharpe: {current_metrics.sharpe_ratio:.2f}). Consider pausing or reducing position sizes."
                )

        # Best/worst regime comparison
        if best_regime != worst_regime and best_regime in regime_metrics and worst_regime in regime_metrics:
            best_sharpe = regime_metrics[best_regime].sharpe_ratio
            worst_sharpe = regime_metrics[worst_regime].sharpe_ratio

            recommendations.append(
                f"📈 Best regime: {best_regime.value.replace('_', ' ').title()} "
                f"(Sharpe: {best_sharpe:.2f})"
            )
            recommendations.append(
                f"📉 Worst regime: {worst_regime.value.replace('_', ' ').title()} "
                f"(Sharpe: {worst_sharpe:.2f})"
            )

            # Check if performance varies significantly
            if best_sharpe > 0 and worst_sharpe < 0:
                recommendations.append(
                    "⚠️ REGIME-DEPENDENT STRATEGY: Performance varies significantly across regimes. "
                    "Consider implementing regime filters or adaptive parameters."
                )

        # Regime stability assessment
        if regime_stability < 0.7:
            recommendations.append(
                f"⚠️ UNSTABLE MARKET CONDITIONS: Regime changes frequently "
                f"(stability: {regime_stability:.2f}). Be cautious with trend-following strategies."
            )
        elif regime_stability > 0.9:
            recommendations.append(
                f"✅ STABLE MARKET CONDITIONS: Current regime is persistent "
                f"(stability: {regime_stability:.2f}). Good for regime-specific strategies."
            )

        # Strategy decay warning
        if current_regime == worst_regime:
            recommendations.append(
                "🚨 STRATEGY DECAY WARNING: Currently in worst-performing regime. "
                "Monitor performance closely and consider pausing trading."
            )

        # Specific regime advice
        if current_regime == MarketRegime.RANGING_HIGH_VOL:
            recommendations.append(
                "💡 TIP: Ranging high-volatility markets favor mean-reversion strategies. "
                "Trend-following may generate false signals."
            )
        elif current_regime == MarketRegime.TRENDING_LOW_VOL:
            recommendations.append(
                "💡 TIP: Trending low-volatility markets favor trend-following strategies. "
                "Good conditions for riding trends."
            )

        return recommendations

    def detect_regime_change(self,
                           historical_regimes: pd.Series,
                           window: int = 20) -> Tuple[bool, float]:
        """
        Detect if market regime has recently changed

        Args:
            historical_regimes: Series of historical regime classifications
            window: Lookback window for change detection

        Returns:
            (has_changed, confidence) tuple
        """
        if len(historical_regimes) < window:
            return False, 0.0

        recent = historical_regimes.iloc[-window:]
        older = historical_regimes.iloc[-2*window:-window]

        # Calculate regime distribution
        recent_dist = recent.value_counts(normalize=True)
        older_dist = older.value_counts(normalize=True)

        # Calculate distributional change
        all_regimes = set(list(recent_dist.index) + list(older_dist.index))
        distance = 0

        for regime in all_regimes:
            recent_pct = recent_dist.get(regime, 0)
            older_pct = older_dist.get(regime, 0)
            distance += abs(recent_pct - older_pct)

        # Normalize distance (0-1)
        distance = distance / 2

        has_changed = distance > self.regime_change_threshold
        confidence = distance

        return has_changed, confidence

    def print_regime_report(self, analysis: RegimeAnalysis):
        """Print formatted regime analysis report"""
        print("\n" + "="*80)
        print("MARKET REGIME ANALYSIS")
        print("="*80 + "\n")

        print(f"Current Regime: {analysis.current_regime.value.replace('_', ' ').title()}")
        print(f"Regime Stability: {analysis.regime_stability:.2%}")
        print(f"Best Regime: {analysis.best_regime.value.replace('_', ' ').title()}")
        print(f"Worst Regime: {analysis.worst_regime.value.replace('_', ' ').title()}")

        print("\nPERFORMANCE BY REGIME:")
        print("-" * 80)
        print(f"{'Regime':<25} {'Bars':<10} {'Sharpe':<10} {'Win Rate':<12} {'Max DD':<10}")
        print("-" * 80)

        for regime, metrics in sorted(analysis.regime_metrics.items(),
                                     key=lambda x: x[1].sharpe_ratio,
                                     reverse=True):
            regime_name = regime.value.replace('_', ' ').title()
            print(f"{regime_name:<25} {metrics.total_bars:<10} "
                  f"{metrics.sharpe_ratio:<10.2f} {metrics.win_rate:<12.2%} "
                  f"{metrics.max_drawdown:<10.2%}")

        print("\nRECOMMENDATIONS:")
        print("-" * 80)
        for rec in analysis.recommendations:
            print(rec)

        print("\n" + "="*80 + "\n")


if __name__ == "__main__":
    logger.info("Market Regime Detection Module")
    logger.info("Identifies market conditions and prevents strategy decay")
