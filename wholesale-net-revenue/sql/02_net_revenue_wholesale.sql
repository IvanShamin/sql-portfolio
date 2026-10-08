-- 02_net_revenue_wholesale.sql
-- Net revenue of WHOLESALE orders by product line, month and warehouse.
--
-- Net revenue = order total minus the payment fee. The fee is stored as a PERCENTAGE of the total,
-- so it has to be converted to an amount first:  total * (1 - fee_pct / 100).
-- (Subtracting the percentage value directly from the total would mix units; see 03_formula_check.sql.)
--
-- The month is kept as a DATE (first day of month), not as text: sorting the text 'Month' name
-- puts August before July before June.

CREATE OR REPLACE VIEW v_net_revenue_wholesale AS
SELECT product_line,
       date_trunc('month', order_date)::date                  AS month,
       warehouse,
       ROUND(SUM(total_eur * (1 - payment_fee_pct / 100.0)), 2) AS net_revenue_eur
FROM   sales
WHERE  client_type = 'Wholesale'
GROUP  BY product_line, date_trunc('month', order_date), warehouse
ORDER  BY product_line, month, net_revenue_eur DESC;

SELECT * FROM v_net_revenue_wholesale;
