-- 03_formula_check.sql
-- How wrong would "SUM(total) - SUM(fee)" be if the fee column holds percentages?
-- Compares the correct net revenue with the unit-mixing shortcut for each product line.

CREATE OR REPLACE VIEW v_formula_check AS
SELECT product_line,
       ROUND(SUM(total_eur), 2)                                        AS gross_revenue_eur,
       ROUND(SUM(total_eur * (1 - payment_fee_pct / 100.0)), 2)        AS net_revenue_correct_eur,
       ROUND(SUM(total_eur) - SUM(payment_fee_pct), 2)                 AS net_revenue_unit_mixing_eur,
       ROUND(SUM(total_eur * payment_fee_pct / 100.0), 2)              AS fees_paid_eur,
       ROUND(SUM(total_eur) - SUM(payment_fee_pct)
             - SUM(total_eur * (1 - payment_fee_pct / 100.0)), 2)      AS overstatement_eur
FROM   sales
WHERE  client_type = 'Wholesale'
GROUP  BY product_line
ORDER  BY product_line;

SELECT * FROM v_formula_check;

-- Which payment methods cost the most in fees (wholesale)?
SELECT payment,
       COUNT(*)                                                    AS orders,
       ROUND(SUM(total_eur), 0)                                    AS gross_revenue_eur,
       ROUND(SUM(total_eur * payment_fee_pct / 100.0), 0)          AS fees_paid_eur,
       ROUND(100 * SUM(total_eur * payment_fee_pct / 100.0) / SUM(SUM(total_eur * payment_fee_pct / 100.0)) OVER (), 1)
                                                                   AS pct_of_all_fees
FROM   sales
WHERE  client_type = 'Wholesale'
GROUP  BY payment
ORDER  BY fees_paid_eur DESC;
