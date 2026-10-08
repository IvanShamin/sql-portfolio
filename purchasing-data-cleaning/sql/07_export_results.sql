-- 07_export_results.sql
-- Writes the result views to output/.

\copy (SELECT * FROM v_top5_materials_per_category)   TO 'output/top5_materials_per_category.csv'  WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_missing_values_audit)          TO 'output/missing_values_audit.csv'         WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_imputation_backtest)           TO 'output/imputation_backtest.csv'          WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_monthly_spend)                 TO 'output/monthly_spend.csv'                WITH (FORMAT csv, HEADER true)
\copy (SELECT line_id, material_id, sourcing_market, buyer_region, net_amount_eur, quantity_kg AS imputed_quantity_kg, quantity_source FROM purchase_orders_clean WHERE quantity_source <> 'reported' ORDER BY line_id) TO 'output/imputed_quantities.csv' WITH (FORMAT csv, HEADER true)
