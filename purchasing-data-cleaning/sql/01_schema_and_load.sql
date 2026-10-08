-- 01_schema_and_load.sql
-- Raw-material purchasing database (synthetic). Column types follow the ERP extract on purpose:
-- order_date arrives as TEXT, amounts and quantities as DOUBLE PRECISION.
-- Run from the project folder (CSV paths are relative to it).

SET client_min_messages = warning;       -- silence "does not exist, skipping" notices on a fresh database

DROP VIEW  IF EXISTS v_monthly_spend, v_imputation_backtest, v_top5_materials_per_category,
                     v_missing_values_audit, purchase_orders_clean;
DROP TABLE IF EXISTS purchase_orders, rejected_deliveries, buyers, raw_materials;

CREATE TABLE raw_materials (
    material_id    text PRIMARY KEY,
    category       text NOT NULL,
    sub_category   text NOT NULL,
    material_name  text NOT NULL
);

CREATE TABLE buyers (
    buyer          text PRIMARY KEY,
    buyer_region   text NOT NULL
);

CREATE TABLE purchase_orders (
    line_id             integer PRIMARY KEY,
    po_number           text NOT NULL,                 -- connects to rejected_deliveries.po_number
    order_date          text,                          -- TEXT: 'DD.MM.YYYY', a few rows 'YYYY-MM-DD'
    sourcing_market     text,
    buyer_region        text,                          -- connects to buyers.buyer_region
    material_id         text REFERENCES raw_materials (material_id),
    net_amount_eur      double precision,              -- after rebate
    quantity_kg         double precision,              -- NULL for some lines
    rebate              double precision,              -- 0.05 = 5 % rebate on the list price
    price_variance_eur  double precision               -- standard cost minus actual cost, positive = cheaper than standard
);

CREATE TABLE rejected_deliveries (
    rejected         text,                             -- 'Yes'
    po_number        text,
    sourcing_market  text
);

\copy raw_materials       FROM 'data/raw_materials.csv'       WITH (FORMAT csv, HEADER true)
\copy buyers              FROM 'data/buyers.csv'              WITH (FORMAT csv, HEADER true)
\copy purchase_orders     FROM 'data/purchase_orders.csv'     WITH (FORMAT csv, HEADER true)
\copy rejected_deliveries FROM 'data/rejected_deliveries.csv' WITH (FORMAT csv, HEADER true)

SELECT 'raw_materials' AS table_name, COUNT(*) AS row_count FROM raw_materials
UNION ALL SELECT 'buyers',              COUNT(*) FROM buyers
UNION ALL SELECT 'purchase_orders',     COUNT(*) FROM purchase_orders
UNION ALL SELECT 'rejected_deliveries', COUNT(*) FROM rejected_deliveries;
