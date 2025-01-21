import React, { useState, useEffect } from 'react';
import { fetchPortfolioData, executeTrade } from '../services/apiService';
import PortfolioSummary from '../components/PortfolioSummary';
import TradeHistory from '../components/TradeHistory';
import styles from '../styles/portfolio.module.css';

const PortfolioPage = () => {
  const [portfolio, setPortfolio] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const loadPortfolio = async () => {
      try {
        const data = await fetchPortfolioData();
        setPortfolio(data);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };
    
    loadPortfolio();
  }, []);

  const handleExecuteTrade = async (tradeData) => {
    try {
      const updatedPortfolio = await executeTrade(tradeData);
      setPortfolio(updatedPortfolio);
    } catch (err) {
      setError(err.message);
    }
  };

  if (loading) return <div>Loading portfolio data...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div className={styles.container}>
      <h1>Portfolio Management</h1>
      
      <div className={styles.grid}>
        <div className={styles.summarySection}>
          <PortfolioSummary portfolio={portfolio} />
        </div>
        
        <div className={styles.historySection}>
          <TradeHistory 
            trades={portfolio.trades}
            onExecuteTrade={handleExecuteTrade}
          />
        </div>
      </div>
    </div>
  );
};

export default PortfolioPage;
