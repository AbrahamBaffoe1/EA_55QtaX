import axios from 'axios';

const API_BASE_URL = 'http://localhost:5000/api';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Dashboard
export const fetchDashboardData = async () => {
  try {
    const response = await apiClient.get('/dashboard');
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch dashboard data');
  }
};

// News Feed
export const fetchNewsFeed = async (page = 1, limit = 10) => {
  try {
    const response = await apiClient.get('/news', {
      params: { page, limit }
    });
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch news feed');
  }
};

// Analytics
export const fetchAnalytics = async () => {
  try {
    const response = await apiClient.get('/analytics');
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch analytics');
  }
};

export const fetchAnalyticsData = async (timeframe = '1d') => {
  try {
    const response = await apiClient.get('/analytics', {
      params: { timeframe }
    });
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch analytics data');
  }
};

// Bot Configuration
export const fetchBotConfigurations = async () => {
  try {
    const response = await apiClient.get('/bots');
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch bot configurations');
  }
};

export const updateBotConfiguration = async (botId, config) => {
  try {
    const response = await apiClient.put(`/bots/${botId}`, config);
    return response.data;
  } catch (error) {
    throw new Error('Failed to update bot configuration');
  }
};

// Portfolio
export const fetchPortfolioData = async () => {
  try {
    const response = await apiClient.get('/portfolio');
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch portfolio data');
  }
};

export const executeTrade = async (tradeData) => {
  try {
    const response = await apiClient.post('/portfolio/trades', tradeData);
    return response.data;
  } catch (error) {
    throw new Error('Failed to execute trade');
  }
};

// Research
export const fetchMarketResearch = async (symbol, timeframe) => {
  try {
    const response = await apiClient.get('/research', {
      params: { symbol, timeframe }
    });
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch market research');
  }
};

// WebSocket connection
export const connectWebSocket = (onMessage) => {
  const ws = new WebSocket('ws://localhost:5000/ws');
  
  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    onMessage(data);
  };

  return ws;
};
