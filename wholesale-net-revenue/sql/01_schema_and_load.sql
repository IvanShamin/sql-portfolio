-- 01_schema_and_load.sql
-- Sales table of a ceramic-materials supplier (synthetic). Run from the project folder.

SET client_min_messages = warning;

DROP VIEW  IF EXISTS v_warehouse_share_and_trend, v_formula_check, v_net_revenue_wholesale;
DROP TABLE IF EXISTS sales;

CREATE TABLE sales (
    order_number     text PRIMARY KEY,
    order_date       date          NOT NULL,           -- June to August 2026
    warehouse        text          NOT NULL,           -- North, Central or West
    client_type      text          NOT NULL,           -- Wholesale or Retail
    product_line     text          NOT NULL,
    quantity         integer       NOT NULL,           -- packs
    unit_price_eur   numeric(10, 2) NOT NULL,
    total_eur        numeric(12, 2) NOT NULL,          -- quantity * unit price
    payment          text          NOT NULL,           -- Credit card, Transfer or Cash
    payment_fee_pct  numeric(4, 2) NOT NULL            -- fee in PERCENT of the order total
);

\copy sales FROM 'data/sales.csv' WITH (FORMAT csv, HEADER true)

SELECT client_type,
       COUNT(*)                       AS orders,
       ROUND(SUM(total_eur), 0)       AS gross_revenue_eur,
       MIN(order_date)                AS first_day,
       MAX(order_date)                AS last_day
FROM   sales
GROUP  BY client_type
ORDER  BY client_type;
