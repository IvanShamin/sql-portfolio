-- 06_export_results.sql
-- Writes the result views to output/.

\copy (SELECT * FROM v_net_revenue_wholesale)    TO 'output/net_revenue_wholesale.csv'    WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_formula_check)            TO 'output/formula_check.csv'            WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_warehouse_share_and_trend) TO 'output/warehouse_share_and_trend.csv' WITH (FORMAT csv, HEADER true)
