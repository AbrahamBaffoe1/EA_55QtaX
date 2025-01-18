import React from 'react';
import PropTypes from 'prop-types';
import { CircularProgress } from '@mui/material';
import ErrorIcon from '@mui/icons-material/Error';
import TrendingUpIcon from '@mui/icons-material/TrendingUp';
import TrendingDownIcon from '@mui/icons-material/TrendingDown';

const MetricCard = ({ title, value, trend, loading, error }) => {
  const getTrendIcon = () => {
    if (trend === 'up') {
      return <TrendingUpIcon className="trend-icon up" />;
    }
    if (trend === 'down') {
      return <TrendingDownIcon className="trend-icon down" />;
    }
    return null;
  };

  return (
    <div className="metric-card">
      <div className="metric-header">
        <h3>{title}</h3>
        {getTrendIcon()}
      </div>
      
      {loading ? (
        <div className="metric-loading">
          <CircularProgress size={24} />
        </div>
      ) : error ? (
        <div className="metric-error">
          <ErrorIcon />
          <span>Error loading data</span>
        </div>
      ) : (
        <div className="metric-value">
          {value}
        </div>
      )}
    </div>
  );
};

MetricCard.propTypes = {
  title: PropTypes.string.isRequired,
  value: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
  trend: PropTypes.oneOf(['up', 'down', null]),
  loading: PropTypes.bool,
  error: PropTypes.bool,
};

MetricCard.defaultProps = {
  value: '--',
  trend: null,
  loading: false,
  error: false,
};

export default MetricCard;
