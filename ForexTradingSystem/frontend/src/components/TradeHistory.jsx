import React from 'react';
import styles from '../styles/portfolio.module.css';

const TradeHistory = ({ trades }) => {
  return (
    <div className={styles.history}>
      <h2>Trade History</h2>
      
      <div className={styles.tableContainer}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Date</th>
              <th>Pair</th>
              <th>Type</th>
              <th>Size</th>
              <th>Price</th>
              <th>Status</th>
              <th>Profit/Loss</th>
            </tr>
          </thead>
          <tbody>
            {trades.map((trade) => (
              <tr key={trade.id}>
                <td>{new Date(trade.timestamp).toLocaleString()}</td>
                <td>{trade.pair}</td>
                <td>
                  <span className={`${styles.tradeType} ${
                    trade.type === 'buy' ? styles.buy : styles.sell
                  }`}>
                    {trade.type}
                  </span>
                </td>
                <td>{trade.size}</td>
                <td>{trade.price}</td>
                <td>
                  <span className={`${styles.status} ${
                    styles[trade.status.toLowerCase()]
                  }`}>
                    {trade.status}
                  </span>
                </td>
                <td className={trade.profit >= 0 ? styles.profit : styles.loss}>
                  ${trade.profit.toFixed(2)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default TradeHistory;
