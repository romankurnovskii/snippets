import requests
import json
import time
import os

POOL_ADDRESS = "BGm1tav58oGcsQJehL9WXBFXF7D27vZsKefj4xJKD5Y"
BASE_URL = f"https://api.defi.services.i2b9e.com/v1/solana/pools/{POOL_ADDRESS}/ohlcv"
OUTPUT_FILE = "ohlcv_12m_5m.json"

def load_existing_candles():
    """Load existing candles from file into a dict keyed by timestamp."""
    if os.path.exists(OUTPUT_FILE):
        with open(OUTPUT_FILE, "r") as f:
            candles = json.load(f)
        result = {c["timestamp"]: c for c in candles}
        print(f"Loaded {len(result)} existing candles from {OUTPUT_FILE}", flush=True)
        return result
    return {}

def save_candles(candles_dict):
    """Deduplicate, sort, and save candles dict to file."""
    sorted_candles = [candles_dict[ts] for ts in sorted(candles_dict.keys())]
    with open(OUTPUT_FILE, "w") as f:
        json.dump(sorted_candles, f, indent=2)
    print(f"Saved {len(sorted_candles)} candles to {OUTPUT_FILE}", flush=True)
    return sorted_candles

def probe_and_fetch():
    print("Fetching default/latest candles...", flush=True)
    try:
        r = requests.get(f"{BASE_URL}?timeframe=5m", timeout=10)
    except Exception as e:
        print(f"Connection failed: {e}", flush=True)
        return
        
    if r.status_code != 200:
        print(f"Error fetching latest candles: {r.status_code} - {r.text}", flush=True)
        return
    
    latest_candles = r.json()
    if not latest_candles:
        print("No candles returned.", flush=True)
        return
    
    # Load any existing data (for incremental resume / crash recovery)
    all_candles = load_existing_candles()
    
    latest_ts = max(c["timestamp"] for c in latest_candles)
    print(f"Latest timestamp in API: {latest_ts} ({time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(latest_ts))} UTC)", flush=True)
    
    # Merge the latest batch into our dict
    for c in latest_candles:
        all_candles[c["timestamp"]] = c
    
    # Target: 12 months of 5m candles = 365 days.
    target_start_ts = latest_ts - (365 * 24 * 3600)
    print(f"Target start timestamp: {target_start_ts} ({time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(target_start_ts))} UTC)", flush=True)
    
    # Determine earliest timestamp we already have
    existing_min_ts = min(all_candles.keys()) if all_candles else latest_ts
    print(f"Earliest candle already on file: {existing_min_ts} ({time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(existing_min_ts))} UTC)", flush=True)
    
    # Save initial data (latest batch)
    save_candles(all_candles)
    
    # Fetch backward in chunks of 8 hours (28,800 seconds)
    chunk_size = 8 * 3600
    current_end = existing_min_ts  # start from what we already have
    consecutive_errors = 0
    
    while current_end > target_start_ts:
        # Don't overlap: stop 5min before current_end to avoid boundary duplicates
        chunk_end = current_end - 300
        chunk_start = chunk_end - chunk_size
        if chunk_start < target_start_ts:
            chunk_start = target_start_ts
        
        print(f"Fetching range: {chunk_start} to {chunk_end}...", end="", flush=True)
        
        params = {
            "timeframe": "5m",
            "start_time": chunk_start,
            "end_time": chunk_end
        }
        try:
            res = requests.get(BASE_URL, params=params, timeout=10)
            if res.status_code == 200:
                candles = res.json()
                if isinstance(candles, list):
                    if len(candles) == 0:
                        print(" Empty response. Reached inception of data.", flush=True)
                        break
                    # Merge into dict (deduplicates by timestamp automatically)
                    for c in candles:
                        all_candles[c["timestamp"]] = c
                    print(f" Success! Got {len(candles)} candles.", flush=True)
                    # Save after every batch
                    save_candles(all_candles)
                    consecutive_errors = 0
                else:
                    print(f" Unexpected response format: {candles}", flush=True)
                    consecutive_errors += 1
            elif res.status_code == 500:
                print(" 500 Error. Likely reached inception of data / no further history.", flush=True)
                break
            else:
                print(f" Error {res.status_code}: {res.text.strip()}", flush=True)
                consecutive_errors += 1
        except Exception as e:
            print(f" Exception: {e}", flush=True)
            consecutive_errors += 1
            
        if consecutive_errors >= 5:
            print("Too many consecutive errors. Stopping fetch.", flush=True)
            break
            
        current_end = chunk_start  # move window further back
        time.sleep(0.2)
    
    # Final save and summary
    sorted_candles = save_candles(all_candles)
    print(f"\nFetched {len(sorted_candles)} unique candles in total.", flush=True)
    if sorted_candles:
        first_ts = sorted_candles[0]["timestamp"]
        last_ts = sorted_candles[-1]["timestamp"]
        print(f"First timestamp: {first_ts} ({time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(first_ts))} UTC)", flush=True)
        print(f"Last timestamp: {last_ts} ({time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(last_ts))} UTC)", flush=True)
        print(f"Span: {(last_ts - first_ts) / 86400:.1f} days", flush=True)

if __name__ == "__main__":
    probe_and_fetch()
