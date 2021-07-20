import numpy as np
import pandas as pd
import json
import time

def generate_synthetic_prices(p0, sigma, mu, theta, n_steps, dt_year, seed=42):
    rng = np.random.default_rng(seed)
    log_prices = np.zeros(n_steps)
    log_prices[0] = np.log(p0)
    log_mu = np.log(mu)
    sigma_step = sigma * np.sqrt(dt_year)
    for i in range(1, n_steps):
        dW = rng.normal(0, 1)
        log_prices[i] = log_prices[i-1] + theta * (log_mu - log_prices[i-1]) * dt_year + sigma_step * dW
    return np.exp(log_prices)

def build_ohlcv_json():
    # 7 days, 5m candles => 7 * 24 * 12 = 2016 steps
    n_steps = 2016
    dt_year = 1 / (365 * 288) # 288 steps per day
    prices = generate_synthetic_prices(p0=150.0, sigma=0.8, mu=150.0, theta=2.0, n_steps=n_steps, dt_year=dt_year)
    
    end_time = int(time.time())
    start_time = end_time - 7 * 24 * 60 * 60
    timestamps = np.linspace(start_time, end_time, n_steps, dtype=int)
    
    data = []
    for i in range(n_steps):
        close_p = prices[i]
        open_p = prices[i-1] if i > 0 else close_p
        high_p = max(open_p, close_p) * (1 + np.random.uniform(0, 0.002))
        low_p = min(open_p, close_p) * (1 - np.random.uniform(0, 0.002))
        vol = 500_000 * (1 + 10 * abs(close_p - open_p)/open_p) * np.random.uniform(0.5, 1.5)
        
        data.append({
            "timestamp": int(timestamps[i]),
            "open": float(open_p),
            "high": float(high_p),
            "low": float(low_p),
            "close": float(close_p),
            "volume": float(vol),
            "source": "synthetic_7d"
        })
        
    with open('ohlcv_12m_5m.json', 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Generated {n_steps} candles and saved to ohlcv_12m_5m.json")

build_ohlcv_json()
