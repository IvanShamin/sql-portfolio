-- 06_monthly_spend.sql
-- Monthly spend per category on the cleaned data (accepted deliveries only), with month-over-month
-- change and a rolling three-month average.
--
-- Techniques: date_trunc on a parsed text date, LAG() and a rolling-frame AVG() OVER.

CREATE OR REPLACE VIEW v_monthly_spend AS
WITH monthly AS (
    SELECT date_trunc('month', order_date)::date AS month,
           category,
           SUM(net_amount_eur)                   AS spend_eur
    FROM   purchase_orders_clean
    WHERE  NOT is_rejected
      AND  order_date IS NOT NULL
    GROUP  BY 1, 2
)
SELECT month,
       category,
       ROUND(spend_eur::numeric, 0)                                              AS spend_eur,
       ROUND((100 * (spend_eur / LAG(spend_eur) OVER (PARTITION BY category ORDER BY month) - 1))::numeric, 1)
                                                                                 AS mom_change_pct,
       ROUND((AVG(spend_eur) OVER (PARTITION BY category ORDER BY month
                                   ROWS BETWEEN 2 PRECEDING AND CURRENT ROW))::numeric, 0)
                                                                                 AS rolling_3m_avg_eur
FROM   monthly
ORDER  BY category, month;

-- last six months of the series
SELECT * FROM v_monthly_spend
WHERE  month >= (SELECT MAX(month) - INTERVAL '5 months' FROM v_monthly_spend)
ORDER  BY category, month;
