import React, { useState } from 'react';
import styles from '../styles/botConfig.module.css';

const BotConfigForm = ({ bot, onUpdate }) => {
  const [config, setConfig] = useState(bot.config);
  const [isSaving, setIsSaving] = useState(false);

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    setConfig(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSaving(true);
    try {
      await onUpdate(bot.id, config);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className={styles.configForm}>
      <div className={styles.formGroup}>
        <label>Strategy</label>
        <select
          name="strategy"
          value={config.strategy}
          onChange={handleChange}
        >
          <option value="trend_following">Trend Following</option>
          <option value="mean_reversion">Mean Reversion</option>
          <option value="breakout">Breakout</option>
          <option value="scalping">Scalping</option>
        </select>
      </div>

      <div className={styles.formGroup}>
        <label>Risk Percentage</label>
        <input
          type="number"
          name="riskPercentage"
          min="0.1"
          max="5"
          step="0.1"
          value={config.riskPercentage}
          onChange={handleChange}
        />
      </div>

      <div className={styles.formGroup}>
        <label>Max Trades</label>
        <input
          type="number"
          name="maxTrades"
          min="1"
          max="10"
          value={config.maxTrades}
          onChange={handleChange}
        />
      </div>

      <div className={styles.formGroup}>
        <label>
          <input
            type="checkbox"
            name="autoTrade"
            checked={config.autoTrade}
            onChange={handleChange}
          />
          Auto Trade
        </label>
      </div>

      <button 
        type="submit" 
        disabled={isSaving}
        className={styles.saveButton}
      >
        {isSaving ? 'Saving...' : 'Save Configuration'}
      </button>
    </form>
  );
};

export default BotConfigForm;
