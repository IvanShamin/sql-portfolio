-- 05_backtest_imputation.sql
-- How good is the imputation? Hide each known quantity in turn, re-estimate it with the
-- same-material / market / region unit price computed WITHOUT that line (leave-one-out),
-- and compare with the true value.
--
-- Techniques: leave-one-out mean with window functions ((SUM OVER - own) / (COUNT OVER - 1)),
-- percentile_cont for the median, FILTER for threshold shares.

CREATE OR REPLACE VIEW v_imputation_backtest AS
WITH known AS (
    SELECT po.line_id, m.category, po.material_id, po.sourcing_market, po.buyer_region,
           po.net_amount_eur, po.rebate, po.quantity_kg,
           po.net_amount_eur / (1 - po.rebate) / po.quantity_kg AS list_price
    FROM   purchase_orders AS po
    JOIN   raw_materials   AS m USING (material_id)
    WHERE  po.quantity_kg > 0
),
loo AS (
    SELECT k.*,
           (SUM(list_price) OVER w - list_price) / NULLIF(COUNT(*) OVER w - 1, 0) AS loo_price
    FROM   known AS k
    WINDOW w AS (PARTITION BY material_id, sourcing_market, buyer_region)
),
estimated AS (
    SELECT category, quantity_kg,
           ROUND(net_amount_eur / (1 - rebate) / loo_price / 25) * 25 AS estimated_kg
    FROM   loo
    WHERE  loo_price IS NOT NULL
)
SELECT category,
       COUNT(*)                                                                         AS lines_tested,
       ROUND((100 * AVG(ABS(estimated_kg - quantity_kg) / quantity_kg))::numeric, 1)    AS mean_abs_pct_error,
       ROUND((100 * percentile_cont(0.5) WITHIN GROUP
              (ORDER BY ABS(estimated_kg - quantity_kg) / quantity_kg))::numeric, 1)    AS median_abs_pct_error,
       ROUND(100.0 * COUNT(*) FILTER (WHERE ABS(estimated_kg - quantity_kg) / quantity_kg <= 0.10) / COUNT(*), 1)
                                                                                        AS pct_within_10pct
FROM   estimated
GROUP  BY ROLLUP (category)
ORDER  BY category NULLS LAST;

SELECT * FROM v_imputation_backtest;
