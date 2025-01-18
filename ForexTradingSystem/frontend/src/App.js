import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import DashboardPage from './pages/DashboardPage';
import NewsFeedPage from './pages/NewsFeedPage';
import AnalyticsPage from './pages/AnalyticsPage';
import BotConfigPage from './pages/BotConfigPage';
import PortfolioPage from './pages/PortfolioPage';
import ResearchPage from './pages/ResearchPage';
import Navbar from './components/Navbar';

function App() {
  return (
    <Router>
      <Navbar />
      <Routes>
        <Route path="/" element={<DashboardPage />} />
        <Route path="/news" element={<NewsFeedPage />} />
        <Route path="/analytics" element={<AnalyticsPage />} />
        <Route path="/bots" element={<BotConfigPage />} />
        <Route path="/portfolio" element={<PortfolioPage />} />
        <Route path="/research" element={<ResearchPage />} />
      </Routes>
    </Router>
  );
}

export default App;
