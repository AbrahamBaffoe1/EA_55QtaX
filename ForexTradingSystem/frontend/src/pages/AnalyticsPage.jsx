import React, { useEffect, useState } from 'react';
import { fetchAnalytics } from '../services/apiService';
import AnalyticsChart from '../components/AnalyticsChart';
import styles from '../styles/analytics.module.css';

const AnalyticsPage = () => {
  const [analyticsData, setAnalyticsData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const loadAnalytics = async () => {
      try {
        const data = await fetchAnalytics();
        setAnalyticsData(data);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };
    
    loadAnalytics();
  }, []);

  if (loading) return <div>Loading analytics...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div className={styles.analyticsContainer}>
      <h1>Trading Analytics</h1>
      
      <div className={styles.chartsGrid}>
        <AnalyticsChart 
          title="Profit/Loss Over Time"
          data={analyticsData.profitLoss}
          type="line"
        />
        <AnalyticsChart 
          title="Trade Volume"
          data={analyticsData.tradeVolume}
          type="bar"
        />
        <AnalyticsChart 
          title="Win Rate"
          data={analyticsData.winRate}
          type="pie"
        />
      </div>
    </div>
  );
};

export default AnalyticsPage;
