-- 03_missing_values_audit.sql
-- Where is data missing, and in which shape does the date column arrive?
--
-- Techniques: generic NULL audit of every column with to_jsonb / jsonb_each_text (no column list to maintain),
-- FILTER aggregates, regular-expression format detection.

CREATE OR REPLACE VIEW v_missing_values_audit AS
SELECT j.key                                                            AS column_name,
       COUNT(*)                                                         AS n_rows,
       COUNT(*) FILTER (WHERE j.value IS NULL)                          AS n_missing,
       ROUND(100.0 * COUNT(*) FILTER (WHERE j.value IS NULL) / COUNT(*), 2) AS pct_missing
FROM   purchase_orders AS po,
       LATERAL jsonb_each_text(to_jsonb(po)) AS j(key, value)
GROUP  BY j.key
ORDER  BY n_missing DESC, column_name;

SELECT * FROM v_missing_values_audit;

-- Are the missing quantities concentrated somewhere?
SELECT sourcing_market,
       COUNT(*)                                       AS lines,
       COUNT(*) FILTER (WHERE quantity_kg IS NULL)    AS missing_quantity,
       ROUND(100.0 * COUNT(*) FILTER (WHERE quantity_kg IS NULL) / COUNT(*), 2) AS pct_missing
FROM   purchase_orders
GROUP  BY sourcing_market
ORDER  BY pct_missing DESC;

-- order_date is TEXT: which formats are in use?
SELECT CASE WHEN order_date ~ '^\d{2}\.\d{2}\.\d{4}$' THEN 'DD.MM.YYYY'
            WHEN order_date ~ '^\d{4}-\d{2}-\d{2}$'   THEN 'YYYY-MM-DD'
            WHEN order_date IS NULL                   THEN 'missing'
            ELSE 'unrecognised' END AS date_format,
       COUNT(*) AS lines
FROM   purchase_orders
GROUP  BY 1
ORDER  BY lines DESC;
