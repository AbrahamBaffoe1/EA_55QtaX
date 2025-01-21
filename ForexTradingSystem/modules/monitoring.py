import os
import dash
from dash import dcc, html
import plotly.express as px
import pandas as pd
import logging
from datetime import datetime

class Monitoring:
    def __init__(self):
        self.logger = self._setup_logger()
        self.app = dash.Dash(__name__)
        self.trade_history = pd.DataFrame(columns=[
            'timestamp', 'pair', 'side', 'price', 'quantity', 'pnl'
        ])
        
        # Set initial empty layout
        self.app.layout = html.Div([
            html.H1('Trading System Dashboard - Loading...'),
            dcc.Interval(
                id='interval-component',
                interval=60*1000,  # in milliseconds
                n_intervals=0
            )
        ])
        
    def _setup_logger(self):
        """Configure monitoring logger"""
        logger = logging.getLogger('monitoring')
        logger.setLevel(logging.INFO)
        handler = logging.FileHandler('monitoring.log')
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        return logger
        
    def add_trade(self, trade_data: dict):
        """Add trade to history and update dashboard"""
        try:
            new_trade = pd.DataFrame([trade_data])
            self.trade_history = pd.concat([self.trade_history, new_trade], ignore_index=True)
            self._update_dashboard()
        except Exception as e:
            self.logger.error(f"Error adding trade: {e}")
            
    def _update_dashboard(self):
        """Update dashboard visualizations"""
        try:
            # Create profit/loss chart
            self.trade_history['cumulative_pnl'] = self.trade_history['pnl'].cumsum()
            
            self.app.layout = html.Div([
                html.H1('Trading System Dashboard'),
                
                dcc.Graph(
                    id='pnl-chart',
                    figure=px.line(
                        self.trade_history,
                        x='timestamp',
                        y='cumulative_pnl',
                        title='Cumulative Profit/Loss'
                    )
                ),
                
                dcc.Graph(
                    id='trade-volume',
                    figure=px.bar(
                        self.trade_history,
                        x='timestamp',
                        y='quantity',
                        color='side',
                        title='Trade Volume by Side'
                    )
                ),
                
                html.Div(id='live-updates'),
                dcc.Interval(
                    id='interval-component',
                    interval=60*1000,  # in milliseconds
                    n_intervals=0
                )
            ])
            
        except Exception as e:
            self.logger.error(f"Error updating dashboard: {e}")
            
    def run(self):
        """Run the monitoring dashboard"""
        try:
            self.app.run_server(host='0.0.0.0', port=int(os.getenv('API_PORT', 8051)))
        except Exception as e:
            self.logger.error(f"Error running monitoring dashboard: {e}")
