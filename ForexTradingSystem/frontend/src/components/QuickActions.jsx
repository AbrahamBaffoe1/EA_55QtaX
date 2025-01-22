import React from 'react';
import styles from '../styles/quickActions.module.css';

const QuickActions = ({ navigate }) => {
  return (
    <div className={styles.quickActions}>
      <h2>Quick Actions</h2>
      <div className={styles.actionsGrid}>
        <button 
          className={styles.actionButton}
          onClick={() => navigate('/portfolio/trades/new')}
        >
          New Trade
        </button>
        <button 
          className={styles.actionButton}
          onClick={() => navigate('/bots')}
        >
          Manage Bots
        </button>
        <button 
          className={styles.actionButton}
          onClick={() => navigate('/research')}
        >
          Market Research
        </button>
        <button 
          className={styles.actionButton}
          onClick={() => navigate('/analytics')}
        >
          View Analytics
        </button>
      </div>
    </div>
  );
};

export default QuickActions;
