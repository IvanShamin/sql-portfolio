"""Generate a synthetic raw-material purchasing database (4 tables) for the SQL exercises.

All values are invented (fixed seed). The structure mimics an ERP extract with the usual
problems: dates stored as text in two formats, numbers as double precision, missing
quantities, a table of rejected deliveries that must be excluded from spend figures.

Tables (CSV in data/):
    raw_materials.csv        material master data (category, sub-category, name)
    purchase_orders.csv      one row per purchase-order line
    rejected_deliveries.csv  purchase orders whose delivery was rejected at goods receipt
    buyers.csv               buyer and the plant region they cover

Usage:
    python src/generate_data.py
"""
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 42
ROOT = Path(__file__).resolve().parent.parent
N_LINES = 8000

# category -> sub-category -> typical standard price in EUR/kg
CATALOGUE = {
    "Silicates & Quartz": {"Quartz sand": 0.08, "Zircon silicate": 1.35, "Wollastonite": 0.24, "Talc": 0.25},
    "Feldspars & Clays": {"Sodium feldspar": 0.14, "Potassium feldspar": 0.17, "Kaolin": 0.24, "Ball clay": 0.12},
    "Fluxes & Borates": {"Borax": 0.75, "Boric acid": 0.95, "Soda ash": 0.31, "Lithium carbonate": 9.50},
    "Oxides & Colorants": {"Zinc oxide": 2.40, "Alumina": 0.85, "Titanium dioxide": 3.00, "Iron oxide": 1.40},
    "Carbonates": {"Calcium carbonate": 0.09, "Dolomite": 0.10, "Barium carbonate": 0.65, "Strontium carbonate": 1.10},
}
CATEGORY_PREFIX = {"Silicates & Quartz": "SIL", "Feldspars & Clays": "FEC", "Fluxes & Borates": "FLB",
                   "Oxides & Colorants": "OXC", "Carbonates": "CAR"}
MARKETS = ["EU", "Non-EU Europe", "Asia", "Americas", "Africa"]
MARKET_P = [0.46, 0.22, 0.17, 0.10, 0.05]
REGIONS = ["Plant CZ-North", "Plant CZ-South", "Plant SK", "Plant PL"]
REGION_P = [0.34, 0.30, 0.20, 0.16]
BUYERS = {"Buyer-01": "Plant CZ-North", "Buyer-02": "Plant CZ-North", "Buyer-03": "Plant CZ-South",
          "Buyer-04": "Plant CZ-South", "Buyer-05": "Plant SK", "Buyer-06": "Plant PL"}
PACK_KG = 25
# how often a sub-category is bought relative to the bulk minerals (exotic / special materials are bought rarely)
BUY_WEIGHT = {"Lithium carbonate": 0.15, "Strontium carbonate": 0.2, "Barium carbonate": 0.3, "Zircon silicate": 0.6,
              "Titanium dioxide": 0.6, "Wollastonite": 0.5, "Talc": 0.5}


def build_materials(rng):
    rows, n = [], 10000100
    for category, subs in CATALOGUE.items():
        prefix = CATEGORY_PREFIX[category]
        for sub, std_price in subs.items():
            sub_code = "".join(w[:2] for w in sub.split()[:2]).upper()
            for grade in ("A", "B", "C", "D"):
                n += int(rng.integers(100, 9000))
                rows.append(dict(
                    material_id=f"{prefix}-{sub_code}-{n}",
                    category=category,
                    sub_category=sub,
                    material_name=f"{sub} grade {grade}",
                    std_price=round(std_price * rng.uniform(0.9, 1.15), 3),
                    market=str(rng.choice(MARKETS, p=MARKET_P)),         # main sourcing market of the contract
                    contract_rebate=float(rng.choice([0.0, 0.02, 0.05], p=[0.5, 0.3, 0.2])),
                    popularity=float((rng.pareto(2.5) + 0.5) * BUY_WEIGHT.get(sub, 1.0)),
                    drift=float(rng.uniform(-0.003, 0.004)),                  # monthly price trend of the material
                ))
    return pd.DataFrame(rows)


def build_orders(materials, rng):
    p = materials["popularity"] / materials["popularity"].sum()
    mat = materials.iloc[rng.choice(len(materials), size=N_LINES, p=p)].reset_index(drop=True)
    dates = pd.Timestamp("2024-01-01") + pd.to_timedelta(rng.integers(0, 912, N_LINES), unit="D")
    months_from_start = (dates - pd.Timestamp("2024-01-01")).days / 30.4
    price = mat["std_price"] * (1 + mat["drift"] * months_from_start) * rng.normal(1.0, 0.035, N_LINES)   # price trend + noise
    qty = np.maximum(PACK_KG, np.round(rng.lognormal(7.2, 0.9, N_LINES) / PACK_KG) * PACK_KG)
    spot = rng.random(N_LINES) < 0.08                                   # spot buys without contract rebate
    rebate = np.where(spot, 0.0, mat["contract_rebate"])
    market = np.where(rng.random(N_LINES) < 0.88, mat["market"], rng.choice(MARKETS, N_LINES))
    net_amount = qty * price * (1 - rebate)
    ppv = qty * (mat["std_price"] * (1 - rebate) - price * (1 - rebate))   # standard cost minus actual cost

    df = pd.DataFrame({
        "line_id": np.arange(1, N_LINES + 1),
        "po_number": [f"PO-{d.year}-{int(i):06d}" for d, i in zip(dates, (np.arange(N_LINES) // 2.2) + 1)],
        "order_date": dates,
        "sourcing_market": market,
        "buyer_region": rng.choice(REGIONS, N_LINES, p=REGION_P),
        "material_id": mat["material_id"],
        "net_amount_eur": net_amount.round(2),
        "quantity_kg": qty,
        "rebate": rebate,
        "price_variance_eur": ppv.round(2),
    })
    df = df.sort_values(["order_date", "sourcing_market", "buyer_region", "line_id"]).reset_index(drop=True)
    key = df["order_date"].dt.strftime("%Y%m%d") + "|" + df["sourcing_market"] + "|" + df["buyer_region"]
    po_group = key + "|" + (df.groupby(key).cumcount() // 3).astype(str)          # up to 3 lines per purchase order
    po_index = pd.factorize(po_group)[0] + 1
    df["po_number"] = [f"PO-{d.year}-{i:06d}" for d, i in zip(df["order_date"], po_index)]
    df["line_id"] = np.arange(1, len(df) + 1)
    df = df.sort_values(["order_date", "po_number", "line_id"]).reset_index(drop=True)
    df["line_id"] = np.arange(1, len(df) + 1)

    # --- data problems --------------------------------------------------------------------
    df["order_date"] = df["order_date"].dt.strftime("%d.%m.%Y")
    iso = rng.random(len(df)) < 0.007                                  # a few rows come in ISO format
    df.loc[iso, "order_date"] = pd.to_datetime(df.loc[iso, "order_date"], format="%d.%m.%Y").dt.strftime("%Y-%m-%d")
    df["quantity_kg"] = df["quantity_kg"].astype(float)
    df.loc[rng.random(len(df)) < 0.018, "quantity_kg"] = np.nan        # missing quantities
    return df


def build_rejected(orders, rng):
    pos = orders.drop_duplicates("po_number")[["po_number", "sourcing_market"]]
    picked = pos.sample(frac=0.03, random_state=SEED)
    return picked.assign(rejected="Yes")[["rejected", "po_number", "sourcing_market"]]


if __name__ == "__main__":
    rng = np.random.default_rng(SEED)
    materials = build_materials(rng)
    orders = build_orders(materials, rng)
    (ROOT / "data").mkdir(exist_ok=True)
    materials[["material_id", "category", "sub_category", "material_name"]].to_csv(ROOT / "data" / "raw_materials.csv", index=False)
    orders.to_csv(ROOT / "data" / "purchase_orders.csv", index=False)
    build_rejected(orders, rng).to_csv(ROOT / "data" / "rejected_deliveries.csv", index=False)
    pd.DataFrame({"buyer": list(BUYERS), "buyer_region": list(BUYERS.values())}).to_csv(ROOT / "data" / "buyers.csv", index=False)
    print(len(materials), "materials,", len(orders), "order lines,", orders["quantity_kg"].isna().sum(), "missing quantities")
