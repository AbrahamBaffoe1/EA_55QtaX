import React, { useState, useEffect } from 'react';
import { fetchBotConfigurations, updateBotConfiguration } from '../services/apiService';
import BotConfigForm from '../components/BotConfigForm';
import styles from '../styles/botConfig.module.css';

const BotConfigPage = () => {
  const [bots, setBots] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const loadBots = async () => {
      try {
        const data = await fetchBotConfigurations();
        setBots(data);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };
    
    loadBots();
  }, []);

  const handleUpdateConfig = async (botId, config) => {
    try {
      const updatedBot = await updateBotConfiguration(botId, config);
      setBots(prev => prev.map(b => 
        b.id === botId ? updatedBot : b
      ));
    } catch (err) {
      setError(err.message);
    }
  };

  if (loading) return <div>Loading bot configurations...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div className={styles.container}>
      <h1>Bot Configuration</h1>
      
      <div className={styles.botsGrid}>
        {bots.map(bot => (
          <div key={bot.id} className={styles.botCard}>
            <h3>{bot.name}</h3>
            <BotConfigForm 
              bot={bot}
              onUpdate={handleUpdateConfig}
            />
          </div>
        ))}
      </div>
    </div>
  );
};

export default BotConfigPage;
