import json

with open("lp_strategy_simulation.ipynb", "r") as f:
    nb = json.load(f)

for cell in nb["cells"]:
    if cell["cell_type"] == "code":
        source = cell["source"]
        for i, line in enumerate(source):
            if "assert len(df) == STEPS, f\"Length mismatch" in line:
                source[i] = '    assert len(df) == len(prices), f"Length mismatch for {name}"\n'
            if "sim_days: int = 30" in line:
                source[i] = "    sim_days: int = 7\n"

with open("lp_strategy_simulation.ipynb", "w") as f:
    json.dump(nb, f, indent=1)

print("Notebook fixed.")
