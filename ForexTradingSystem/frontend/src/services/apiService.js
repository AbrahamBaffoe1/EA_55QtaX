import axios from 'axios';

const API_BASE_URL = 'http://localhost:5000/api';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

export const fetchDashboardData = async () => {
  try {
    const response = await apiClient.get('/dashboard');
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch dashboard data');
  }
};

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

export const fetchPortfolioData = async () => {
  try {
    const response = await apiClient.get('/portfolio');
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch portfolio data');
  }
};

export const fetchNewsFeed = async () => {
  try {
    const response = await apiClient.get('/news');
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch news feed');
  }
};
