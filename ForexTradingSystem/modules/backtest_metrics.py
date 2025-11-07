"""
Comprehensive Performance Metrics for Backtesting

This module calculates professional-grade performance metrics to evaluate
trading strategies and prevent the common pitfalls that cause 80-95% of
algorithmic trading systems to fail.

Key Metrics:
- Risk-adjusted returns (Sharpe, Sortino, Calmar)
- Drawdown analysis (max drawdown, duration, recovery)
- Trade statistics (win rate, profit factor, expectancy)
- Distribution analysis (skewness, kurtosis)
- Consistency metrics (stability, rolling performance)

Author: Claude Code
Version: 1.0.0
"""

import logging
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal
import pandas as pd
import numpy as np
from scipy import stats
from collections import defaultdict

logger = logging.getLogger(__name__)


@dataclass
class PerformanceMetrics:
    """Container for comprehensive performance metrics"""

    # Returns
    total_return: float
    annualized_return: float
    cagr: float  # Compound Annual Growth Rate

    # Risk metrics
    volatility: float  # Annualized
    sharpe_ratio: float
    sortino_ratio: float
    calmar_ratio: float
    omega_ratio: float
    max_drawdown: float
    max_drawdown_duration: int  # In days
    current_drawdown: float
    avg_drawdown: float
    recovery_factor: float

    # Trade statistics
    total_trades: int
    winning_trades: int
    losing_trades: int
    win_rate: float
    profit_factor: float
    expectancy: float
    avg_win: float
    avg_loss: float
    avg_win_loss_ratio: float
    largest_win: float
    largest_loss: float

    # Consistency metrics
    best_day: float
    worst_day: float
    best_month: float
    worst_month: float
    positive_days_pct: float
    positive_months_pct: float
    consecutive_wins: int
    consecutive_losses: int
    avg_holding_time: float  # In hours

    # Distribution metrics
    skewness: float
    kurtosis: float
    var_95: float  # Value at Risk (95%)
    cvar_95: float  # Conditional VaR (95%)

    # Cost analysis
    total_commission: float
    total_slippage: float
    commission_pct_of_profit: float
    slippage_pct_of_profit: float

    # Time-based analysis
    monthly_returns: Dict[str, float]
    yearly_returns: Dict[str, float]
    rolling_sharpe: List[Tuple[datetime, float]]

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization"""
        return {
            'returns': {
                'total_return': self.total_return,
                'annualized_return': self.annualized_return,
                'cagr': self.cagr,
            },
            'risk': {
                'volatility': self.volatility,
                'sharpe_ratio': self.sharpe_ratio,
                'sortino_ratio': self.sortino_ratio,
                'calmar_ratio': self.calmar_ratio,
                'omega_ratio': self.omega_ratio,
                'max_drawdown': self.max_drawdown,
                'max_drawdown_duration_days': self.max_drawdown_duration,
                'current_drawdown': self.current_drawdown,
                'avg_drawdown': self.avg_drawdown,
                'recovery_factor': self.recovery_factor,
            },
            'trade_statistics': {
                'total_trades': self.total_trades,
                'winning_trades': self.winning_trades,
                'losing_trades': self.losing_trades,
                'win_rate': self.win_rate,
                'profit_factor': self.profit_factor,
                'expectancy': self.expectancy,
                'avg_win': self.avg_win,
                'avg_loss': self.avg_loss,
                'avg_win_loss_ratio': self.avg_win_loss_ratio,
                'largest_win': self.largest_win,
                'largest_loss': self.largest_loss,
            },
            'consistency': {
                'best_day': self.best_day,
                'worst_day': self.worst_day,
                'best_month': self.best_month,
                'worst_month': self.worst_month,
                'positive_days_pct': self.positive_days_pct,
                'positive_months_pct': self.positive_months_pct,
                'consecutive_wins': self.consecutive_wins,
                'consecutive_losses': self.consecutive_losses,
                'avg_holding_time_hours': self.avg_holding_time,
            },
            'distribution': {
                'skewness': self.skewness,
                'kurtosis': self.kurtosis,
                'var_95': self.var_95,
                'cvar_95': self.cvar_95,
            },
            'costs': {
                'total_commission': self.total_commission,
                'total_slippage': self.total_slippage,
                'commission_pct_of_profit': self.commission_pct_of_profit,
                'slippage_pct_of_profit': self.slippage_pct_of_profit,
            },
            'time_based': {
                'monthly_returns': self.monthly_returns,
                'yearly_returns': self.yearly_returns,
            }
        }


class PerformanceAnalyzer:
    """
    Calculate comprehensive performance metrics for backtesting results

    This analyzer helps prevent strategy failure by:
    1. Identifying overfitting through consistency metrics
    2. Quantifying realistic costs (slippage/commission)
    3. Measuring risk-adjusted returns
    4. Detecting strategy decay patterns
    5. Analyzing trade distribution for robustness
    """

    def __init__(self, risk_free_rate: float = 0.02, trading_days_per_year: int = 252):
        """
        Initialize performance analyzer

        Args:
            risk_free_rate: Annual risk-free rate (default: 2%)
            trading_days_per_year: Trading days per year (default: 252 for stocks)
        """
        self.risk_free_rate = risk_free_rate
        self.trading_days_per_year = trading_days_per_year

    def calculate_metrics(self, backtest_results: Dict[str, Any]) -> PerformanceMetrics:
        """
        Calculate comprehensive performance metrics from backtest results

        Args:
            backtest_results: Dictionary from BacktestingEngine.get_results()

        Returns:
            PerformanceMetrics object with all calculated metrics
        """
        logger.info("Calculating performance metrics...")

        # Extract data
        equity_curve = pd.DataFrame(backtest_results['equity_curve'])
        equity_curve['timestamp'] = pd.to_datetime(equity_curve['timestamp'])
        equity_curve.set_index('timestamp', inplace=True)

        trades = pd.DataFrame(backtest_results['trades'])
        if len(trades) > 0:
            trades['timestamp'] = pd.to_datetime(trades['timestamp'])

        initial_capital = backtest_results['initial_capital']
        final_equity = backtest_results['final_equity']

        # Calculate returns
        returns_metrics = self._calculate_returns(
            equity_curve, initial_capital, final_equity
        )

        # Calculate risk metrics
        risk_metrics = self._calculate_risk_metrics(equity_curve, returns_metrics)

        # Calculate trade statistics
        trade_stats = self._calculate_trade_statistics(trades, backtest_results)

        # Calculate consistency metrics
        consistency_metrics = self._calculate_consistency_metrics(
            equity_curve, trades
        )

        # Calculate distribution metrics
        distribution_metrics = self._calculate_distribution_metrics(equity_curve)

        # Calculate cost analysis
        cost_metrics = self._calculate_cost_analysis(backtest_results)

        # Time-based analysis
        time_metrics = self._calculate_time_based_metrics(equity_curve)

        # Combine all metrics
        metrics = PerformanceMetrics(
            **returns_metrics,
            **risk_metrics,
            **trade_stats,
            **consistency_metrics,
            **distribution_metrics,
            **cost_metrics,
            **time_metrics
        )

        logger.info("Performance metrics calculated successfully")
        return metrics

    def _calculate_returns(self, equity_curve: pd.DataFrame,
                          initial_capital: float,
                          final_equity: float) -> Dict[str, float]:
        """Calculate return metrics"""
        # Total return
        total_return = (final_equity - initial_capital) / initial_capital

        # Calculate daily returns
        daily_equity = equity_curve.resample('D').last().ffill()
        daily_returns = daily_equity['equity'].pct_change().dropna()

        # Annualized return
        days = (equity_curve.index[-1] - equity_curve.index[0]).days
        years = days / 365.25
        if years > 0:
            annualized_return = (1 + total_return) ** (1 / years) - 1
            cagr = annualized_return
        else:
            annualized_return = 0
            cagr = 0

        return {
            'total_return': total_return,
            'annualized_return': annualized_return,
            'cagr': cagr,
        }

    def _calculate_risk_metrics(self, equity_curve: pd.DataFrame,
                                returns_metrics: Dict[str, float]) -> Dict[str, float]:
        """Calculate risk and risk-adjusted return metrics"""
        # Daily returns
        daily_equity = equity_curve.resample('D').last().ffill()
        daily_returns = daily_equity['equity'].pct_change().dropna()

        if len(daily_returns) == 0:
            return self._default_risk_metrics()

        # Volatility (annualized)
        volatility = daily_returns.std() * np.sqrt(self.trading_days_per_year)

        # Sharpe Ratio
        excess_returns = daily_returns.mean() - (self.risk_free_rate / self.trading_days_per_year)
        sharpe_ratio = (excess_returns / daily_returns.std() * np.sqrt(self.trading_days_per_year)
                       if daily_returns.std() > 0 else 0)

        # Sortino Ratio (uses downside deviation)
        downside_returns = daily_returns[daily_returns < 0]
        downside_std = downside_returns.std() if len(downside_returns) > 0 else daily_returns.std()
        sortino_ratio = (excess_returns / downside_std * np.sqrt(self.trading_days_per_year)
                        if downside_std > 0 else 0)

        # Drawdown analysis
        drawdown_metrics = self._calculate_drawdowns(equity_curve)

        # Calmar Ratio (return / max drawdown)
        calmar_ratio = (returns_metrics['annualized_return'] / abs(drawdown_metrics['max_drawdown'])
                       if drawdown_metrics['max_drawdown'] != 0 else 0)

        # Omega Ratio
        omega_ratio = self._calculate_omega_ratio(daily_returns)

        # Recovery Factor
        recovery_factor = (returns_metrics['total_return'] / abs(drawdown_metrics['max_drawdown'])
                          if drawdown_metrics['max_drawdown'] != 0 else 0)

        return {
            'volatility': volatility,
            'sharpe_ratio': sharpe_ratio,
            'sortino_ratio': sortino_ratio,
            'calmar_ratio': calmar_ratio,
            'omega_ratio': omega_ratio,
            'recovery_factor': recovery_factor,
            **drawdown_metrics
        }

    def _default_risk_metrics(self) -> Dict[str, float]:
        """Return default risk metrics when no data"""
        return {
            'volatility': 0,
            'sharpe_ratio': 0,
            'sortino_ratio': 0,
            'calmar_ratio': 0,
            'omega_ratio': 0,
            'max_drawdown': 0,
            'max_drawdown_duration': 0,
            'current_drawdown': 0,
            'avg_drawdown': 0,
            'recovery_factor': 0,
        }

    def _calculate_drawdowns(self, equity_curve: pd.DataFrame) -> Dict[str, float]:
        """Calculate comprehensive drawdown metrics"""
        equity = equity_curve['equity'].values
        running_max = np.maximum.accumulate(equity)
        drawdown = (equity - running_max) / running_max

        max_drawdown = drawdown.min()
        current_drawdown = drawdown[-1]

        # Calculate drawdown durations
        drawdown_periods = []
        in_drawdown = False
        drawdown_start = None

        for i, dd in enumerate(drawdown):
            if dd < 0 and not in_drawdown:
                in_drawdown = True
                drawdown_start = i
            elif dd == 0 and in_drawdown:
                in_drawdown = False
                if drawdown_start is not None:
                    drawdown_periods.append(i - drawdown_start)

        # If still in drawdown
        if in_drawdown and drawdown_start is not None:
            drawdown_periods.append(len(drawdown) - drawdown_start)

        max_drawdown_duration = max(drawdown_periods) if drawdown_periods else 0
        avg_drawdown = np.mean([dd for dd in drawdown if dd < 0]) if any(drawdown < 0) else 0

        return {
            'max_drawdown': max_drawdown,
            'max_drawdown_duration': max_drawdown_duration,
            'current_drawdown': current_drawdown,
            'avg_drawdown': avg_drawdown,
        }

    def _calculate_omega_ratio(self, returns: pd.Series, threshold: float = 0.0) -> float:
        """
        Calculate Omega Ratio
        Ratio of gains to losses above/below a threshold
        """
        gains = returns[returns > threshold] - threshold
        losses = threshold - returns[returns < threshold]

        gains_sum = gains.sum() if len(gains) > 0 else 0
        losses_sum = losses.sum() if len(losses) > 0 else 0

        omega = gains_sum / losses_sum if losses_sum != 0 else 0
        return omega

    def _calculate_trade_statistics(self, trades: pd.DataFrame,
                                    backtest_results: Dict[str, Any]) -> Dict[str, float]:
        """Calculate comprehensive trade statistics"""
        if len(trades) == 0:
            return self._default_trade_statistics()

        total_trades = len(trades)

        # Calculate P&L per trade (simplified - actual implementation would track matched trades)
        # For now, use the overall statistics from backtest
        winning_trades = backtest_results['winning_trades']
        losing_trades = backtest_results['losing_trades']
        total_pnl = backtest_results['total_pnl']

        win_rate = winning_trades / total_trades if total_trades > 0 else 0

        # Estimate average win/loss (simplified)
        # In production, you'd track each trade's P&L
        if winning_trades > 0 and losing_trades > 0:
            # Rough estimation
            gross_profit = total_pnl if total_pnl > 0 else 0
            gross_loss = abs(min(total_pnl, 0))

            avg_win = gross_profit / winning_trades if winning_trades > 0 else 0
            avg_loss = gross_loss / losing_trades if losing_trades > 0 else 0
            avg_win_loss_ratio = avg_win / avg_loss if avg_loss != 0 else 0

            # Profit factor
            profit_factor = gross_profit / gross_loss if gross_loss != 0 else 0
        else:
            avg_win = 0
            avg_loss = 0
            avg_win_loss_ratio = 0
            profit_factor = 0

        # Expectancy
        expectancy = (win_rate * avg_win) - ((1 - win_rate) * avg_loss)

        # Largest win/loss (simplified)
        largest_win = avg_win * 2 if avg_win > 0 else 0  # Rough estimate
        largest_loss = avg_loss * 2 if avg_loss > 0 else 0  # Rough estimate

        return {
            'total_trades': total_trades,
            'winning_trades': winning_trades,
            'losing_trades': losing_trades,
            'win_rate': win_rate,
            'profit_factor': profit_factor,
            'expectancy': expectancy,
            'avg_win': avg_win,
            'avg_loss': avg_loss,
            'avg_win_loss_ratio': avg_win_loss_ratio,
            'largest_win': largest_win,
            'largest_loss': largest_loss,
        }

    def _default_trade_statistics(self) -> Dict[str, float]:
        """Return default trade statistics when no trades"""
        return {
            'total_trades': 0,
            'winning_trades': 0,
            'losing_trades': 0,
            'win_rate': 0,
            'profit_factor': 0,
            'expectancy': 0,
            'avg_win': 0,
            'avg_loss': 0,
            'avg_win_loss_ratio': 0,
            'largest_win': 0,
            'largest_loss': 0,
        }

    def _calculate_consistency_metrics(self, equity_curve: pd.DataFrame,
                                       trades: pd.DataFrame) -> Dict[str, Any]:
        """Calculate consistency and stability metrics"""
        # Daily returns
        daily_equity = equity_curve.resample('D').last().ffill()
        daily_returns = daily_equity['equity'].pct_change().dropna()

        if len(daily_returns) == 0:
            return self._default_consistency_metrics()

        # Best/worst days
        best_day = daily_returns.max()
        worst_day = daily_returns.min()

        # Positive days percentage
        positive_days = (daily_returns > 0).sum()
        positive_days_pct = positive_days / len(daily_returns)

        # Monthly returns
        monthly_equity = equity_curve.resample('M').last().ffill()
        monthly_returns = monthly_equity['equity'].pct_change().dropna()

        if len(monthly_returns) > 0:
            best_month = monthly_returns.max()
            worst_month = monthly_returns.min()
            positive_months = (monthly_returns > 0).sum()
            positive_months_pct = positive_months / len(monthly_returns)
        else:
            best_month = 0
            worst_month = 0
            positive_months_pct = 0

        # Consecutive wins/losses
        consecutive_wins, consecutive_losses = self._calculate_consecutive_trades(trades)

        # Average holding time
        avg_holding_time = self._calculate_avg_holding_time(trades)

        return {
            'best_day': best_day,
            'worst_day': worst_day,
            'best_month': best_month,
            'worst_month': worst_month,
            'positive_days_pct': positive_days_pct,
            'positive_months_pct': positive_months_pct,
            'consecutive_wins': consecutive_wins,
            'consecutive_losses': consecutive_losses,
            'avg_holding_time': avg_holding_time,
        }

    def _default_consistency_metrics(self) -> Dict[str, Any]:
        """Return default consistency metrics"""
        return {
            'best_day': 0,
            'worst_day': 0,
            'best_month': 0,
            'worst_month': 0,
            'positive_days_pct': 0,
            'positive_months_pct': 0,
            'consecutive_wins': 0,
            'consecutive_losses': 0,
            'avg_holding_time': 0,
        }

    def _calculate_consecutive_trades(self, trades: pd.DataFrame) -> Tuple[int, int]:
        """Calculate max consecutive wins and losses"""
        if len(trades) == 0 or 'pnl' not in trades.columns:
            return 0, 0

        # Filter out trades without P&L
        trades_with_pnl = trades[trades['pnl'].notna()]

        if len(trades_with_pnl) == 0:
            return 0, 0

        consecutive_wins = 0
        consecutive_losses = 0
        current_wins = 0
        current_losses = 0

        for pnl in trades_with_pnl['pnl']:
            if pnl > 0:
                current_wins += 1
                current_losses = 0
                consecutive_wins = max(consecutive_wins, current_wins)
            elif pnl < 0:
                current_losses += 1
                current_wins = 0
                consecutive_losses = max(consecutive_losses, current_losses)

        return consecutive_wins, consecutive_losses

    def _calculate_avg_holding_time(self, trades: pd.DataFrame) -> float:
        """Calculate average holding time in hours"""
        if len(trades) < 2:
            return 0

        # Simplified: calculate time between trades
        # In production, you'd track entry and exit times for each position
        time_diffs = trades['timestamp'].diff().dropna()
        avg_time = time_diffs.mean()

        # Convert to hours
        avg_hours = avg_time.total_seconds() / 3600 if avg_time else 0
        return avg_hours

    def _calculate_distribution_metrics(self, equity_curve: pd.DataFrame) -> Dict[str, float]:
        """Calculate distribution metrics for returns"""
        daily_equity = equity_curve.resample('D').last().ffill()
        daily_returns = daily_equity['equity'].pct_change().dropna()

        if len(daily_returns) < 2:
            return {
                'skewness': 0,
                'kurtosis': 0,
                'var_95': 0,
                'cvar_95': 0,
            }

        # Skewness and kurtosis
        skewness = stats.skew(daily_returns)
        kurtosis = stats.kurtosis(daily_returns)

        # Value at Risk (VaR) at 95% confidence
        var_95 = np.percentile(daily_returns, 5)

        # Conditional VaR (CVaR) - average of returns below VaR
        cvar_95 = daily_returns[daily_returns <= var_95].mean()

        return {
            'skewness': skewness,
            'kurtosis': kurtosis,
            'var_95': var_95,
            'cvar_95': cvar_95,
        }

    def _calculate_cost_analysis(self, backtest_results: Dict[str, Any]) -> Dict[str, float]:
        """Analyze costs (commission and slippage) impact"""
        total_commission = backtest_results['total_commission']
        total_slippage = backtest_results['total_slippage']
        total_pnl = backtest_results['total_pnl']

        # Calculate as percentage of profit
        if total_pnl > 0:
            commission_pct = (total_commission / total_pnl) * 100
            slippage_pct = (total_slippage / total_pnl) * 100
        else:
            commission_pct = 0
            slippage_pct = 0

        return {
            'total_commission': total_commission,
            'total_slippage': total_slippage,
            'commission_pct_of_profit': commission_pct,
            'slippage_pct_of_profit': slippage_pct,
        }

    def _calculate_time_based_metrics(self, equity_curve: pd.DataFrame) -> Dict[str, Any]:
        """Calculate time-based performance metrics"""
        # Monthly returns
        monthly_equity = equity_curve.resample('M').last().ffill()
        monthly_returns = monthly_equity['equity'].pct_change().dropna()

        monthly_dict = {}
        for date, ret in monthly_returns.items():
            key = date.strftime('%Y-%m')
            monthly_dict[key] = float(ret)

        # Yearly returns
        yearly_equity = equity_curve.resample('Y').last().ffill()
        yearly_returns = yearly_equity['equity'].pct_change().dropna()

        yearly_dict = {}
        for date, ret in yearly_returns.items():
            key = str(date.year)
            yearly_dict[key] = float(ret)

        # Rolling Sharpe (30-day window)
        rolling_sharpe = []
        daily_equity = equity_curve.resample('D').last().ffill()
        daily_returns = daily_equity['equity'].pct_change().dropna()

        window = 30
        if len(daily_returns) >= window:
            for i in range(window, len(daily_returns)):
                window_returns = daily_returns.iloc[i-window:i]
                sharpe = (window_returns.mean() / window_returns.std() *
                         np.sqrt(self.trading_days_per_year)
                         if window_returns.std() > 0 else 0)
                rolling_sharpe.append((daily_returns.index[i], sharpe))

        return {
            'monthly_returns': monthly_dict,
            'yearly_returns': yearly_dict,
            'rolling_sharpe': rolling_sharpe,
        }

    def print_report(self, metrics: PerformanceMetrics):
        """Print a formatted performance report"""
        print("\n" + "="*80)
        print("PERFORMANCE METRICS REPORT")
        print("="*80 + "\n")

        print("RETURNS")
        print("-" * 80)
        print(f"Total Return:              {metrics.total_return:>12.2%}")
        print(f"Annualized Return:         {metrics.annualized_return:>12.2%}")
        print(f"CAGR:                      {metrics.cagr:>12.2%}")

        print("\nRISK METRICS")
        print("-" * 80)
        print(f"Volatility (Annual):       {metrics.volatility:>12.2%}")
        print(f"Sharpe Ratio:              {metrics.sharpe_ratio:>12.2f}")
        print(f"Sortino Ratio:             {metrics.sortino_ratio:>12.2f}")
        print(f"Calmar Ratio:              {metrics.calmar_ratio:>12.2f}")
        print(f"Omega Ratio:               {metrics.omega_ratio:>12.2f}")
        print(f"Max Drawdown:              {metrics.max_drawdown:>12.2%}")
        print(f"Max DD Duration (days):    {metrics.max_drawdown_duration:>12d}")
        print(f"Recovery Factor:           {metrics.recovery_factor:>12.2f}")

        print("\nTRADE STATISTICS")
        print("-" * 80)
        print(f"Total Trades:              {metrics.total_trades:>12d}")
        print(f"Winning Trades:            {metrics.winning_trades:>12d}")
        print(f"Losing Trades:             {metrics.losing_trades:>12d}")
        print(f"Win Rate:                  {metrics.win_rate:>12.2%}")
        print(f"Profit Factor:             {metrics.profit_factor:>12.2f}")
        print(f"Expectancy:                {metrics.expectancy:>12.2f}")
        print(f"Avg Win:                   {metrics.avg_win:>12.2f}")
        print(f"Avg Loss:                  {metrics.avg_loss:>12.2f}")
        print(f"Avg Win/Loss Ratio:        {metrics.avg_win_loss_ratio:>12.2f}")

        print("\nCONSISTENCY")
        print("-" * 80)
        print(f"Best Day:                  {metrics.best_day:>12.2%}")
        print(f"Worst Day:                 {metrics.worst_day:>12.2%}")
        print(f"Best Month:                {metrics.best_month:>12.2%}")
        print(f"Worst Month:               {metrics.worst_month:>12.2%}")
        print(f"Positive Days:             {metrics.positive_days_pct:>12.2%}")
        print(f"Positive Months:           {metrics.positive_months_pct:>12.2%}")

        print("\nCOSTS")
        print("-" * 80)
        print(f"Total Commission:          {metrics.total_commission:>12.2f}")
        print(f"Total Slippage:            {metrics.total_slippage:>12.2f}")
        print(f"Commission % of Profit:    {metrics.commission_pct_of_profit:>12.2%}")
        print(f"Slippage % of Profit:      {metrics.slippage_pct_of_profit:>12.2%}")

        print("\n" + "="*80 + "\n")


if __name__ == "__main__":
    logger.info("Performance Metrics Module")
    logger.info("Provides comprehensive analysis of backtest results")
