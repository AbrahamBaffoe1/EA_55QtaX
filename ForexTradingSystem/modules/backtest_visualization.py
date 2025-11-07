"""
Visualization and Reporting for Backtesting Results

This module creates professional-grade charts and reports to visualize
backtesting performance and identify potential issues.

Key Visualizations:
- Equity curve with drawdown overlay
- Monthly/yearly returns heatmap
- Trade distribution analysis
- Risk metrics dashboard
- Regime-based performance charts

Author: Claude Code
Version: 1.0.0
"""

import logging
from typing import Dict, List, Optional, Any
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import json

logger = logging.getLogger(__name__)


class BacktestVisualizer:
    """
    Create comprehensive visualizations for backtest results

    Helps traders:
    1. Understand strategy performance visually
    2. Identify problematic periods
    3. Spot overfitting patterns
    4. Compare different strategies
    5. Generate professional reports
    """

    def __init__(self, style: str = 'seaborn-v0_8-darkgrid'):
        """
        Initialize visualizer

        Args:
            style: Matplotlib style to use
        """
        try:
            plt.style.use(style)
        except:
            # Fallback to default if style not available
            pass

        self.fig_size = (14, 8)
        self.dpi = 100

        # Set seaborn aesthetics
        sns.set_palette("husl")

        logger.info("Backtest visualizer initialized")

    def plot_equity_curve(self,
                         equity_curve: List[Dict[str, Any]],
                         title: str = "Equity Curve",
                         save_path: Optional[str] = None):
        """
        Plot equity curve with drawdown overlay

        Args:
            equity_curve: List of {'timestamp': str, 'equity': float}
            title: Chart title
            save_path: Optional path to save figure
        """
        # Convert to DataFrame
        df = pd.DataFrame(equity_curve)
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df.set_index('timestamp', inplace=True)

        # Calculate drawdown
        running_max = df['equity'].expanding().max()
        drawdown = (df['equity'] - running_max) / running_max * 100

        # Create figure with subplots
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=self.fig_size,
                                       gridspec_kw={'height_ratios': [3, 1]},
                                       dpi=self.dpi)

        # Equity curve
        ax1.plot(df.index, df['equity'], label='Equity', linewidth=2, color='#2E86AB')
        ax1.fill_between(df.index, df['equity'], alpha=0.3, color='#2E86AB')
        ax1.set_ylabel('Equity ($)', fontsize=12, fontweight='bold')
        ax1.set_title(title, fontsize=14, fontweight='bold')
        ax1.legend(loc='upper left', fontsize=10)
        ax1.grid(True, alpha=0.3)
        ax1.tick_params(axis='x', labelbottom=False)

        # Format y-axis
        ax1.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'${x:,.0f}'))

        # Drawdown
        ax2.fill_between(df.index, drawdown, 0, alpha=0.5, color='#A23B72', label='Drawdown')
        ax2.set_xlabel('Date', fontsize=12, fontweight='bold')
        ax2.set_ylabel('Drawdown (%)', fontsize=12, fontweight='bold')
        ax2.legend(loc='lower left', fontsize=10)
        ax2.grid(True, alpha=0.3)

        plt.tight_layout()

        if save_path:
            plt.savefig(save_path, dpi=self.dpi, bbox_inches='tight')
            logger.info(f"Equity curve saved to {save_path}")

        plt.show()

    def plot_monthly_returns(self,
                            equity_curve: List[Dict[str, Any]],
                            title: str = "Monthly Returns Heatmap",
                            save_path: Optional[str] = None):
        """
        Plot monthly returns as a heatmap

        Args:
            equity_curve: List of {'timestamp': str, 'equity': float}
            title: Chart title
            save_path: Optional path to save figure
        """
        # Convert to DataFrame
        df = pd.DataFrame(equity_curve)
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df.set_index('timestamp', inplace=True)

        # Resample to daily and calculate returns
        daily_equity = df.resample('D').last().ffill()
        daily_returns = daily_equity['equity'].pct_change()

        # Group by month and year
        monthly_returns = daily_returns.groupby([
            daily_returns.index.year,
            daily_returns.index.month
        ]).apply(lambda x: (1 + x).prod() - 1)

        # Create pivot table for heatmap
        monthly_data = []
        for (year, month), ret in monthly_returns.items():
            monthly_data.append({
                'Year': year,
                'Month': month,
                'Return': ret * 100  # Convert to percentage
            })

        if not monthly_data:
            logger.warning("No monthly data available for heatmap")
            return

        monthly_df = pd.DataFrame(monthly_data)
        heatmap_data = monthly_df.pivot(index='Month', columns='Year', values='Return')

        # Create heatmap
        fig, ax = plt.subplots(figsize=(12, 8), dpi=self.dpi)

        sns.heatmap(
            heatmap_data,
            annot=True,
            fmt='.2f',
            cmap='RdYlGn',
            center=0,
            linewidths=1,
            cbar_kws={'label': 'Return (%)'},
            ax=ax
        )

        # Set month labels
        month_labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        ax.set_yticklabels(month_labels, rotation=0)

        ax.set_title(title, fontsize=14, fontweight='bold', pad=20)
        ax.set_xlabel('Year', fontsize=12, fontweight='bold')
        ax.set_ylabel('Month', fontsize=12, fontweight='bold')

        plt.tight_layout()

        if save_path:
            plt.savefig(save_path, dpi=self.dpi, bbox_inches='tight')
            logger.info(f"Monthly returns heatmap saved to {save_path}")

        plt.show()

    def plot_trade_analysis(self,
                           trades: List[Dict[str, Any]],
                           title: str = "Trade Analysis",
                           save_path: Optional[str] = None):
        """
        Plot trade distribution and analysis

        Args:
            trades: List of trade dictionaries
            title: Chart title
            save_path: Optional path to save figure
        """
        if not trades:
            logger.warning("No trades to plot")
            return

        df = pd.DataFrame(trades)
        df['timestamp'] = pd.to_datetime(df['timestamp'])

        # Filter trades with P&L
        trades_with_pnl = df[df['pnl'].notna()]

        if len(trades_with_pnl) == 0:
            logger.warning("No completed trades with P&L")
            return

        # Create figure with subplots
        fig, axes = plt.subplots(2, 2, figsize=(14, 10), dpi=self.dpi)

        # 1. P&L Distribution
        ax1 = axes[0, 0]
        pnl_values = trades_with_pnl['pnl']
        ax1.hist(pnl_values, bins=30, color='#2E86AB', alpha=0.7, edgecolor='black')
        ax1.axvline(x=0, color='red', linestyle='--', linewidth=2, label='Break-even')
        ax1.set_xlabel('P&L ($)', fontsize=10, fontweight='bold')
        ax1.set_ylabel('Frequency', fontsize=10, fontweight='bold')
        ax1.set_title('P&L Distribution', fontsize=11, fontweight='bold')
        ax1.legend()
        ax1.grid(True, alpha=0.3)

        # 2. Cumulative P&L
        ax2 = axes[0, 1]
        cumulative_pnl = trades_with_pnl.sort_values('timestamp')['pnl'].cumsum()
        ax2.plot(range(len(cumulative_pnl)), cumulative_pnl,
                linewidth=2, color='#2E86AB')
        ax2.fill_between(range(len(cumulative_pnl)), cumulative_pnl, alpha=0.3, color='#2E86AB')
        ax2.set_xlabel('Trade Number', fontsize=10, fontweight='bold')
        ax2.set_ylabel('Cumulative P&L ($)', fontsize=10, fontweight='bold')
        ax2.set_title('Cumulative P&L', fontsize=11, fontweight='bold')
        ax2.grid(True, alpha=0.3)
        ax2.axhline(y=0, color='red', linestyle='--', alpha=0.5)

        # 3. Win/Loss Ratio
        ax3 = axes[1, 0]
        wins = (pnl_values > 0).sum()
        losses = (pnl_values < 0).sum()
        breakeven = (pnl_values == 0).sum()

        labels = ['Wins', 'Losses', 'Breakeven']
        sizes = [wins, losses, breakeven]
        colors = ['#28a745', '#dc3545', '#6c757d']
        explode = (0.1, 0.1, 0)

        ax3.pie(sizes, explode=explode, labels=labels, colors=colors,
               autopct='%1.1f%%', startangle=90, textprops={'fontsize': 10})
        ax3.set_title('Win/Loss Ratio', fontsize=11, fontweight='bold')

        # 4. Trade Side Distribution
        ax4 = axes[1, 1]
        side_counts = df['side'].value_counts()
        ax4.bar(side_counts.index, side_counts.values,
               color=['#2E86AB', '#A23B72'], alpha=0.7, edgecolor='black')
        ax4.set_xlabel('Side', fontsize=10, fontweight='bold')
        ax4.set_ylabel('Count', fontsize=10, fontweight='bold')
        ax4.set_title('Trade Side Distribution', fontsize=11, fontweight='bold')
        ax4.grid(True, alpha=0.3, axis='y')

        plt.suptitle(title, fontsize=14, fontweight='bold', y=0.995)
        plt.tight_layout()

        if save_path:
            plt.savefig(save_path, dpi=self.dpi, bbox_inches='tight')
            logger.info(f"Trade analysis saved to {save_path}")

        plt.show()

    def plot_metrics_dashboard(self,
                               metrics: Dict[str, Any],
                               title: str = "Performance Metrics Dashboard",
                               save_path: Optional[str] = None):
        """
        Create a dashboard of key performance metrics

        Args:
            metrics: Dictionary from PerformanceMetrics.to_dict()
            title: Chart title
            save_path: Optional path to save figure
        """
        fig = plt.figure(figsize=(16, 10), dpi=self.dpi)

        # Create grid
        gs = fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)

        # Extract metrics
        returns = metrics.get('returns', {})
        risk = metrics.get('risk', {})
        trade_stats = metrics.get('trade_statistics', {})
        consistency = metrics.get('consistency', {})
        costs = metrics.get('costs', {})

        # 1. Returns Bar Chart
        ax1 = fig.add_subplot(gs[0, 0])
        return_metrics = {
            'Total': returns.get('total_return', 0) * 100,
            'Annual': returns.get('annualized_return', 0) * 100,
            'CAGR': returns.get('cagr', 0) * 100
        }
        colors = ['#28a745' if v > 0 else '#dc3545' for v in return_metrics.values()]
        ax1.bar(return_metrics.keys(), return_metrics.values(), color=colors, alpha=0.7, edgecolor='black')
        ax1.set_ylabel('Return (%)', fontsize=10, fontweight='bold')
        ax1.set_title('Returns', fontsize=11, fontweight='bold')
        ax1.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
        ax1.grid(True, alpha=0.3, axis='y')

        # 2. Risk-Adjusted Returns
        ax2 = fig.add_subplot(gs[0, 1])
        risk_metrics = {
            'Sharpe': risk.get('sharpe_ratio', 0),
            'Sortino': risk.get('sortino_ratio', 0),
            'Calmar': risk.get('calmar_ratio', 0),
            'Omega': risk.get('omega_ratio', 0)
        }
        ax2.barh(list(risk_metrics.keys()), list(risk_metrics.values()),
                color='#2E86AB', alpha=0.7, edgecolor='black')
        ax2.set_xlabel('Ratio', fontsize=10, fontweight='bold')
        ax2.set_title('Risk-Adjusted Returns', fontsize=11, fontweight='bold')
        ax2.axvline(x=0, color='black', linestyle='-', linewidth=0.5)
        ax2.grid(True, alpha=0.3, axis='x')

        # 3. Drawdown
        ax3 = fig.add_subplot(gs[0, 2])
        max_dd = risk.get('max_drawdown', 0) * 100
        avg_dd = risk.get('avg_drawdown', 0) * 100
        current_dd = risk.get('current_drawdown', 0) * 100

        dd_data = {'Max': max_dd, 'Average': avg_dd, 'Current': current_dd}
        ax3.bar(dd_data.keys(), dd_data.values(), color='#dc3545', alpha=0.7, edgecolor='black')
        ax3.set_ylabel('Drawdown (%)', fontsize=10, fontweight='bold')
        ax3.set_title('Drawdown Analysis', fontsize=11, fontweight='bold')
        ax3.grid(True, alpha=0.3, axis='y')

        # 4. Trade Statistics
        ax4 = fig.add_subplot(gs[1, 0])
        win_rate = trade_stats.get('win_rate', 0) * 100
        profit_factor = trade_stats.get('profit_factor', 0)

        ax4.text(0.5, 0.7, f"Win Rate: {win_rate:.1f}%",
                ha='center', va='center', fontsize=14, fontweight='bold',
                transform=ax4.transAxes)
        ax4.text(0.5, 0.3, f"Profit Factor: {profit_factor:.2f}",
                ha='center', va='center', fontsize=14, fontweight='bold',
                transform=ax4.transAxes)
        ax4.set_title('Trade Statistics', fontsize=11, fontweight='bold')
        ax4.axis('off')

        # 5. Consistency
        ax5 = fig.add_subplot(gs[1, 1])
        pos_days = consistency.get('positive_days_pct', 0) * 100
        pos_months = consistency.get('positive_months_pct', 0) * 100

        ax5.text(0.5, 0.7, f"Positive Days: {pos_days:.1f}%",
                ha='center', va='center', fontsize=14, fontweight='bold',
                transform=ax5.transAxes)
        ax5.text(0.5, 0.3, f"Positive Months: {pos_months:.1f}%",
                ha='center', va='center', fontsize=14, fontweight='bold',
                transform=ax5.transAxes)
        ax5.set_title('Consistency', fontsize=11, fontweight='bold')
        ax5.axis('off')

        # 6. Costs Impact
        ax6 = fig.add_subplot(gs[1, 2])
        commission_pct = costs.get('commission_pct_of_profit', 0)
        slippage_pct = costs.get('slippage_pct_of_profit', 0)

        cost_data = {'Commission': commission_pct, 'Slippage': slippage_pct}
        ax6.bar(cost_data.keys(), cost_data.values(),
               color='#FFA500', alpha=0.7, edgecolor='black')
        ax6.set_ylabel('% of Profit', fontsize=10, fontweight='bold')
        ax6.set_title('Trading Costs Impact', fontsize=11, fontweight='bold')
        ax6.grid(True, alpha=0.3, axis='y')

        # 7. Best/Worst Performance
        ax7 = fig.add_subplot(gs[2, :])
        best_day = consistency.get('best_day', 0) * 100
        worst_day = consistency.get('worst_day', 0) * 100
        best_month = consistency.get('best_month', 0) * 100
        worst_month = consistency.get('worst_month', 0) * 100

        categories = ['Best Day', 'Worst Day', 'Best Month', 'Worst Month']
        values = [best_day, worst_day, best_month, worst_month]
        colors_perf = ['#28a745', '#dc3545', '#28a745', '#dc3545']

        ax7.barh(categories, values, color=colors_perf, alpha=0.7, edgecolor='black')
        ax7.set_xlabel('Return (%)', fontsize=10, fontweight='bold')
        ax7.set_title('Best/Worst Performance', fontsize=11, fontweight='bold')
        ax7.axvline(x=0, color='black', linestyle='-', linewidth=0.5)
        ax7.grid(True, alpha=0.3, axis='x')

        plt.suptitle(title, fontsize=16, fontweight='bold', y=0.995)

        if save_path:
            plt.savefig(save_path, dpi=self.dpi, bbox_inches='tight')
            logger.info(f"Metrics dashboard saved to {save_path}")

        plt.show()

    def create_full_report(self,
                          results: Dict[str, Any],
                          metrics: Dict[str, Any],
                          output_dir: str = "./backtest_reports"):
        """
        Create a complete backtest report with all visualizations

        Args:
            results: Backtest results dictionary
            metrics: Performance metrics dictionary
            output_dir: Directory to save reports
        """
        import os
        os.makedirs(output_dir, exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        base_name = f"backtest_report_{timestamp}"

        logger.info(f"Generating complete backtest report...")

        # 1. Equity curve
        equity_path = os.path.join(output_dir, f"{base_name}_equity_curve.png")
        self.plot_equity_curve(results['equity_curve'], save_path=equity_path)

        # 2. Monthly returns
        monthly_path = os.path.join(output_dir, f"{base_name}_monthly_returns.png")
        self.plot_monthly_returns(results['equity_curve'], save_path=monthly_path)

        # 3. Trade analysis
        if results['trades']:
            trade_path = os.path.join(output_dir, f"{base_name}_trade_analysis.png")
            self.plot_trade_analysis(results['trades'], save_path=trade_path)

        # 4. Metrics dashboard
        dashboard_path = os.path.join(output_dir, f"{base_name}_dashboard.png")
        self.plot_metrics_dashboard(metrics, save_path=dashboard_path)

        # 5. Save data as JSON
        json_path = os.path.join(output_dir, f"{base_name}_data.json")
        report_data = {
            'results': {k: v for k, v in results.items() if k not in ['trades', 'equity_curve']},
            'metrics': metrics,
            'timestamp': timestamp
        }

        with open(json_path, 'w') as f:
            json.dump(report_data, f, indent=2, default=str)

        logger.info(f"Complete report saved to {output_dir}")
        logger.info(f"Report ID: {base_name}")

        return base_name


if __name__ == "__main__":
    logger.info("Backtest Visualization Module")
    logger.info("Creates professional charts and reports for backtest results")
