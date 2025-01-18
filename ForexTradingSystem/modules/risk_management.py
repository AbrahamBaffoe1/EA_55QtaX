import os
import logging
from decimal import Decimal
from typing import Dict, Any

class RiskManager:
    def __init__(self):
        self.logger = self._setup_logger()
        self.daily_loss_limit = Decimal(os.getenv('MAX_DAILY_LOSS'))
        self.risk_per_trade = Decimal(os.getenv('RISK_PER_TRADE'))
        self.max_position_size = Decimal(os.getenv('MAX_POSITION_SIZE'))
        self.daily_pnl = Decimal('0')
        
    def _setup_logger(self):
        """Configure risk management logger"""
        logger = logging.getLogger('risk_management')
        logger.setLevel(logging.INFO)
        handler = logging.FileHandler('risk_management.log')
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        return logger
        
    def update_risk_parameters(self):
        """Update risk parameters based on current market conditions"""
        try:
            # Check daily loss limit
            if self.daily_pnl <= -self.daily_loss_limit:
                self.logger.warning("Daily loss limit reached. Stopping trading for today.")
                return False
                
            return True
            
        except Exception as e:
            self.logger.error(f"Error updating risk parameters: {e}")
            return False
            
    def calculate_position_size(self, balance: Decimal, atr: Decimal) -> Decimal:
        """Calculate position size based on volatility and risk parameters"""
        try:
            # Calculate position size based on ATR and risk parameters
            risk_amount = balance * self.risk_per_trade
            position_size = risk_amount / atr
            
            # Apply maximum position size constraint
            max_size = balance * self.max_position_size
            return min(position_size, max_size)
            
        except Exception as e:
            self.logger.error(f"Error calculating position size: {e}")
            return Decimal('0')
            
    def update_pnl(self, pnl_change: Decimal):
        """Update daily PnL tracking"""
        self.daily_pnl += pnl_change
        self.logger.info(f"Updated daily PnL: {self.daily_pnl}")
        
    def get_risk_status(self) -> Dict[str, Any]:
        """Get current risk status"""
        return {
            'daily_pnl': float(self.daily_pnl),
            'daily_loss_limit': float(self.daily_loss_limit),
            'risk_per_trade': float(self.risk_per_trade),
            'max_position_size': float(self.max_position_size)
        }
