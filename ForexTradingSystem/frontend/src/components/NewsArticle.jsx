import React from 'react';
import PropTypes from 'prop-types';
import styles from '../styles/newsArticle.module.css';

const NewsArticle = ({ title, description, source, publishedAt, url }) => {
  const formattedDate = new Date(publishedAt).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });

  return (
    <article className={styles.newsArticle}>
      <div className={styles.articleContent}>
        <h3 className={styles.articleTitle}>
          <a href={url} target="_blank" rel="noopener noreferrer">
            {title}
          </a>
        </h3>
        <p className={styles.articleDescription}>{description}</p>
        <div className={styles.articleMeta}>
          <span className={styles.articleSource}>{source}</span>
          <span className={styles.articleDate}>{formattedDate}</span>
        </div>
      </div>
    </article>
  );
};

NewsArticle.propTypes = {
  title: PropTypes.string.isRequired,
  description: PropTypes.string.isRequired,
  source: PropTypes.string.isRequired,
  publishedAt: PropTypes.string.isRequired,
  url: PropTypes.string.isRequired,
};

export default NewsArticle;
