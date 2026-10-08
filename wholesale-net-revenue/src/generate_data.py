"""Generate synthetic order data for a ceramic-materials supplier selling from three warehouses.

All values are invented (fixed seed). Orders are placed by wholesale customers (tile producers,
large distributors) and retail customers (small studios, hobby potters) and are paid by credit
card, bank transfer or cash; every payment method carries a different fee in percent of the
order total.

Usage:
    python src/generate_data.py          # writes data/sales.csv
"""
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 21
ROOT = Path(__file__).resolve().parent.parent
N_ORDERS = 2100

PRODUCT_LINES = {                     # price per pack in EUR
    "Frits": 31.0,
    "Ready-to-use glazes": 48.0,
    "Engobes": 26.0,
    "Ceramic pigments": 118.0,
    "Digital inks": 215.0,
}
WAREHOUSE_MIX = {                     # share of orders per product line, per warehouse
    "North":   [0.34, 0.26, 0.18, 0.12, 0.10],
    "Central": [0.22, 0.30, 0.16, 0.14, 0.18],
    "West":    [0.18, 0.22, 0.14, 0.20, 0.26],
}
WAREHOUSE_P = [0.38, 0.34, 0.28]
PAYMENT_FEE_PCT = {"Credit card": 2.8, "Transfer": 0.5, "Cash": 1.0}
MONTH_DEMAND = {6: 1.00, 7: 0.95, 8: 0.78}       # August holiday dip


def build() -> pd.DataFrame:
    rng = np.random.default_rng(SEED)
    days = pd.date_range("2026-06-01", "2026-08-31")
    day_p = np.array([MONTH_DEMAND[d.month] * (0.35 if d.dayofweek >= 5 else 1.0) for d in days])
    dates = rng.choice(days, size=N_ORDERS, p=day_p / day_p.sum())

    warehouse = rng.choice(list(WAREHOUSE_MIX), size=N_ORDERS, p=WAREHOUSE_P)
    client = rng.choice(["Wholesale", "Retail"], size=N_ORDERS, p=[0.62, 0.38])
    line = np.array([rng.choice(list(PRODUCT_LINES), p=WAREHOUSE_MIX[w]) for w in warehouse])

    qty = np.where(client == "Wholesale",
                   np.round(rng.lognormal(3.7, 0.7, N_ORDERS)),       # median about 40 packs
                   np.round(rng.lognormal(1.8, 0.6, N_ORDERS)))       # median about 6 packs
    qty = np.maximum(qty, 1).astype(int)
    base = np.array([PRODUCT_LINES[l] for l in line])
    discount = np.where(client == "Wholesale", rng.uniform(0.88, 0.97, N_ORDERS), 1.0)    # volume pricing
    unit_price = np.round(base * discount * rng.normal(1.0, 0.03, N_ORDERS), 2)

    pay_wholesale = rng.choice(["Transfer", "Credit card"], size=N_ORDERS, p=[0.80, 0.20])
    pay_retail = rng.choice(["Credit card", "Cash", "Transfer"], size=N_ORDERS, p=[0.55, 0.30, 0.15])
    payment = np.where(client == "Wholesale", pay_wholesale, pay_retail)

    df = pd.DataFrame({
        "order_date": pd.to_datetime(dates),
        "warehouse": warehouse,
        "client_type": client,
        "product_line": line,
        "quantity": qty,
        "unit_price_eur": unit_price,
        "total_eur": np.round(qty * unit_price, 2),
        "payment": payment,
        "payment_fee_pct": [PAYMENT_FEE_PCT[p] for p in payment],
    }).sort_values("order_date", kind="stable").reset_index(drop=True)
    df.insert(0, "order_number", [f"S-2026-{i:06d}" for i in range(1, len(df) + 1)])
    df["order_date"] = df["order_date"].dt.strftime("%Y-%m-%d")
    return df


if __name__ == "__main__":
    out = build()
    (ROOT / "data").mkdir(exist_ok=True)
    out.to_csv(ROOT / "data" / "sales.csv", index=False)
    print(len(out), "orders;", (out["client_type"] == "Wholesale").sum(), "wholesale")
