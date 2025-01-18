import React, { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchDashboardData } from '../services/apiService';
import MetricCard from '../components/MetricCard';
import QuickActions from '../components/QuickActions';
import NewsPreview from '../components/NewsPreview';
import styles from '../styles/dashboard.module.css';
import wsService from '../utils/websocketService';

const DashboardPage = () => {
  const [dashboardData, setDashboardData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const navigate = useNavigate();

  const handleUpdate = useCallback((update) => {
    setDashboardData(prev => ({
      ...prev,
      portfolio: {
        ...prev.portfolio,
        balance: update.balance,
        positions: update.positions
      },
      analytics: {
        ...prev.analytics,
        performance: {
          ...prev.analytics.performance,
          dailyPnL: update.dailyPnL
        }
      }
    }));
  }, []);

  useEffect(() => {
    const loadData = async () => {
      try {
        const data = await fetchDashboardData();
        setDashboardData(data);
        
        // Connect to WebSocket for real-time updates
        wsService.connect();
        wsService.subscribe('metricsUpdate', handleUpdate);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };
    
    loadData();

    return () => {
      wsService.unsubscribe('metricsUpdate');
      wsService.disconnect();
    };
  }, [handleUpdate]);

  if (loading) return <div>Loading dashboard...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div className={styles.dashboardContainer}>
      <h1>PUR EA Dashboard</h1>
      
      <div className={styles.metricsGrid}>
        <MetricCard 
          title="Portfolio Value" 
          value={`$${dashboardData.portfolio.balance}`}
          trend="up"
        />
        <MetricCard 
          title="Active Positions" 
          value={dashboardData.portfolio.positions.length}
        />
        <MetricCard 
          title="Today's P/L" 
          value={`$${dashboardData.analytics.performance.dailyPnL}`}
          trend={dashboardData.analytics.performance.dailyPnL >= 0 ? 'up' : 'down'}
        />
      </div>

      <QuickActions navigate={navigate} />
      
      <div className={styles.newsSection}>
        <h2>Latest Market News</h2>
        <NewsPreview news={dashboardData.news.slice(0, 3)} />
      </div>
    </div>
  );
};

export default DashboardPage;
