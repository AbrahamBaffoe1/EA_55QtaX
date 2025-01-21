import React, { useEffect, useState } from 'react';
import { fetchNews } from '../services/apiService';
import NewsArticle from '../components/NewsArticle';
import styles from '../styles/newsFeed.module.css';

const NewsFeedPage = () => {
  const [news, setNews] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const loadNews = async () => {
      try {
        const newsData = await fetchNews();
        setNews(newsData);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };
    
    loadNews();
  }, []);

  if (loading) return <div>Loading news...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div className={styles.newsFeedContainer}>
      <h1>Market News</h1>
      
      <div className={styles.newsGrid}>
        {news.map(article => (
          <NewsArticle 
            key={article.id}
            title={article.title}
            description={article.description}
            source={article.source}
            publishedAt={article.publishedAt}
            url={article.url}
          />
        ))}
      </div>
    </div>
  );
};

export default NewsFeedPage;
