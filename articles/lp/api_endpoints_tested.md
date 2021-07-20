# API Endpoints Tested

During the simulation data gathering phase, I tested several endpoints from the `defi.services` API to fetch pool metadata and historical OHLCV data. 

The health check endpoint is operational, but the detailed pool endpoints return **500 Internal Server Error**.

Here are the exact endpoints tested so you can verify them yourself:

## 1. API Health Check (Working)
This endpoint confirms the API server is online.

**Endpoint:**
```bash
curl -s -i "https://api.defi.services.i2b9e.com/health"
```
**Expected Response:**
`HTTP/2 200 OK` with `{"status":"ok"}`

---

## 2. Pool Details (Failing)
This endpoint is used to fetch pool metadata (e.g., SOL/USDC Meteora DLMM pool). 

**Tested Address:** `HWLBosvSDNECGCEaYMLZGURpApHLQ7mhFbS9s9cfKhLj` (Main SOL/USDC Meteora DLMM pool)

**Endpoint:**
```bash
curl -s -i "https://api.defi.services.i2b9e.com/v1/solana/pools/HWLBosvSDNECGCEaYMLZGURpApHLQ7mhFbS9s9cfKhLj"
```
**Observed Response:**
```
HTTP/2 500 
content-type: application/json; charset=utf-8

{"error":"internal_server_error","message":"An internal server error occurred"}
```

---

## 3. Pool OHLCV Data (Failing)
This endpoint is used to fetch historical price data for backtesting.

**Tested Address:** `HWLBosvSDNECGCEaYMLZGURpApHLQ7mhFbS9s9cfKhLj`

**Endpoint:**
```bash
curl -s -i "https://api.defi.services.i2b9e.com/v1/solana/pools/HWLBosvSDNECGCEaYMLZGURpApHLQ7mhFbS9s9cfKhLj/ohlcv?timeframe=1h&provider=meteora"
```
**Observed Response:**
```
HTTP/2 500 
content-type: application/json; charset=utf-8

{"error":"internal_server_error","message":"An internal server error occurred"}
```

## Summary
Since the endpoints for specific pools are returning `500 Internal Server Error`, the simulation notebook gracefully falls back to generating synthetic price paths (Ornstein-Uhlenbeck process with drift) based on the default SOL volatility parameters.

Once the API issue is resolved on their end, the notebook will automatically fetch live data.
