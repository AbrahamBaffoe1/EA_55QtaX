import React from 'react';
import { NavLink } from 'react-router-dom';
import styles from '../styles/navbar.module.css';

function Navbar() {
  return (
    <nav className={styles.navbar}>
      <div className={styles.brand}>
        <NavLink to="/" className={styles.brandLink}>
          Forex Trading System
        </NavLink>
      </div>
      
      <ul className={styles.navList}>
        <li className={styles.navItem}>
          <NavLink 
            to="/" 
            className={({ isActive }) => 
              isActive ? styles.activeLink : styles.navLink
            }
          >
            Dashboard
          </NavLink>
        </li>
        <li className={styles.navItem}>
          <NavLink 
            to="/news" 
            className={({ isActive }) => 
              isActive ? styles.activeLink : styles.navLink
            }
          >
            News Feed
          </NavLink>
        </li>
        <li className={styles.navItem}>
          <NavLink 
            to="/analytics" 
            className={({ isActive }) => 
              isActive ? styles.activeLink : styles.navLink
            }
          >
            Analytics
          </NavLink>
        </li>
        <li className={styles.navItem}>
          <NavLink 
            to="/bots" 
            className={({ isActive }) => 
              isActive ? styles.activeLink : styles.navLink
            }
          >
            Bot Config
          </NavLink>
        </li>
        <li className={styles.navItem}>
          <NavLink 
            to="/portfolio" 
            className={({ isActive }) => 
              isActive ? styles.activeLink : styles.navLink
            }
          >
            Portfolio
          </NavLink>
        </li>
        <li className={styles.navItem}>
          <NavLink 
            to="/research" 
            className={({ isActive }) => 
              isActive ? styles.activeLink : styles.navLink
            }
          >
            Research
          </NavLink>
        </li>
      </ul>
    </nav>
  );
}

export default Navbar;
