import json
import os

with open("lp_strategy_simulation.ipynb", "r") as f:
    nb = json.load(f)

for cell in nb["cells"]:
    if cell["cell_type"] == "code":
        source = cell["source"]
        for i, line in enumerate(source):
            if "DEFAULT_POOL = 'HWLBosvSDNECGCEaYMLZGURpApHLQ7mhFbS9s9cfKhLj'" in line:
                source[i] = "DEFAULT_POOL = 'BGm1tav58oGcsQJehL9WXBFXF7D27vZsKefj4xJKD5Y'\n"
            if "steps_per_day: int = 24" in line:
                source[i] = "    steps_per_day: int = 288         # 5m timeframe (24 * 12)\n"
            if "live_data = fetch_pool_ohlcv(DEFAULT_POOL, timeframe='1h'," in line:
                source[i] = "live_data = fetch_pool_ohlcv(DEFAULT_POOL, timeframe='5m',\n"
            if "freq = f'{24 // steps_per_day}h'" in line:
                source[i] = "    freq = f'{24 * 60 // steps_per_day}T'\n"

# Add logic to read from json file in the Live API section
for cell in nb["cells"]:
    if cell["cell_type"] == "code":
        source = "".join(cell["source"])
        if "# ── Attempt live API fetch ──" in source:
            new_source = source.replace(
                "live_data = fetch_pool_ohlcv(DEFAULT_POOL, timeframe='5m',",
                """
import os
import json as _json

live_data = None
# Check for local JSON first
if os.path.exists('ohlcv_12m_5m.json'):
    with open('ohlcv_12m_5m.json', 'r') as f:
        live_data = _json.load(f)
        print('✅ Loaded OHLCV data from local ohlcv_12m_5m.json')

if not live_data:
    live_data = fetch_pool_ohlcv(DEFAULT_POOL, timeframe='5m',"""
            )
            
            # also fix the data source label
            new_source = new_source.replace(
                "DATA_SOURCE = 'Live API'",
                "DATA_SOURCE = 'Local JSON Data' if os.path.exists('ohlcv_12m_5m.json') else 'Live API'"
            )
            
            # fix missing closing parenthesis for fetch_pool_ohlcv inside the replace block
            # Actually, let's just do a simpler replacement

            cell["source"] = [line + "\n" for line in new_source.split("\n")]
            # remove extra trailing newlines added by the split/join
            if cell["source"][-1] == "\n":
                cell["source"] = cell["source"][:-1]

with open("lp_strategy_simulation.ipynb", "w") as f:
    json.dump(nb, f, indent=1)

print("Notebook updated successfully.")
