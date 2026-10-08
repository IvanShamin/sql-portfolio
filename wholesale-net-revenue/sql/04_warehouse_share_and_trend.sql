-- 04_warehouse_share_and_trend.sql
-- Builds on the net revenue view: each warehouse's share of its product line in a month,
-- the month-over-month change, and its rank among the warehouses.
--
-- Techniques: SUM() OVER (PARTITION BY ...), LAG() over a different partition, RANK().

CREATE OR REPLACE VIEW v_warehouse_share_and_trend AS
SELECT product_line,
       month,
       warehouse,
       net_revenue_eur,
       ROUND(100 * net_revenue_eur / SUM(net_revenue_eur) OVER (PARTITION BY product_line, month), 1)
                                                                          AS pct_of_line_in_month,
       ROUND(100 * (net_revenue_eur / LAG(net_revenue_eur) OVER (PARTITION BY product_line, warehouse ORDER BY month) - 1), 1)
                                                                          AS mom_change_pct,
       RANK() OVER (PARTITION BY product_line, month ORDER BY net_revenue_eur DESC)
                                                                          AS warehouse_rank
FROM   v_net_revenue_wholesale
ORDER  BY product_line, month, warehouse_rank;

-- Largest month-over-month movements
SELECT *
FROM   v_warehouse_share_and_trend
WHERE  mom_change_pct IS NOT NULL
ORDER  BY ABS(mom_change_pct) DESC
LIMIT  8;
