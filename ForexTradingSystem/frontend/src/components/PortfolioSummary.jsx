import React from 'react';
import styles from '../styles/portfolio.module.css';

const PortfolioSummary = ({ portfolio }) => {
  return (
    <div className={styles.summary}>
      <h2>Portfolio Summary</h2>
      
      <div className={styles.metrics}>
        <div className={styles.metric}>
          <span className={styles.label}>Total Value</span>
          <span className={styles.value}>
            ${portfolio.totalValue.toLocaleString()}
          </span>
        </div>
        
        <div className={styles.metric}>
          <span className={styles.label}>24h Change</span>
          <span className={styles.value}>
            {portfolio.dailyChange > 0 ? '+' : ''}
            {portfolio.dailyChange.toFixed(2)}%
          </span>
        </div>
        
        <div className={styles.metric}>
          <span className={styles.label}>Open Positions</span>
          <span className={styles.value}>
            {portfolio.openPositions}
          </span>
        </div>
      </div>
      
      <div className={styles.allocation}>
        <h3>Asset Allocation</h3>
        <div className={styles.chart}>
          {portfolio.allocations.map((asset, index) => (
            <div 
              key={asset.currency}
              className={styles.chartSegment}
              style={{
                width: `${asset.percentage}%`,
                backgroundColor: `hsl(${index * 60}, 70%, 50%)`
              }}
            />
          ))}
        </div>
        <div className={styles.legend}>
          {portfolio.allocations.map((asset) => (
            <div key={asset.currency} className={styles.legendItem}>
              <span 
                className={styles.colorSwatch}
                style={{ backgroundColor: asset.color }}
              />
              <span className={styles.currency}>{asset.currency}</span>
              <span className={styles.percentage}>
                {asset.percentage.toFixed(1)}%
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default PortfolioSummary;
