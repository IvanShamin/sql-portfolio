-- 04_impute_missing_quantity.sql
-- Builds the cleaned view purchase_orders_clean: parsed dates, rejected-delivery flag and
-- quantities filled in where they are missing.
--
-- Imputation idea: quantity = net amount / unit price. The unit price is taken from lines of the
-- same material where the quantity is known, in three steps of decreasing precision:
--     1. same material, sourcing market and buyer region
--     2. same material and sourcing market
--     3. same material
-- Prices are first normalised to the list price (net / (1 - rebate)) so that rebates do not
-- distort the comparison. The result is rounded to the 25 kg pack size, and the step that was
-- used is stored in quantity_source, so imputed values stay visible and filterable.
--
-- Techniques: CTE cascade, COALESCE fallback chain, CASE with regex-guarded date parsing, EXISTS.

CREATE OR REPLACE VIEW purchase_orders_clean AS
WITH known AS (
    SELECT material_id, sourcing_market, buyer_region,
           net_amount_eur / (1 - rebate) / quantity_kg AS list_price_per_kg
    FROM   purchase_orders
    WHERE  quantity_kg > 0
),
price_group      AS (SELECT material_id, sourcing_market, buyer_region, AVG(list_price_per_kg) AS p
                     FROM known GROUP BY 1, 2, 3),
price_mat_market AS (SELECT material_id, sourcing_market, AVG(list_price_per_kg) AS p
                     FROM known GROUP BY 1, 2),
price_material   AS (SELECT material_id, AVG(list_price_per_kg) AS p
                     FROM known GROUP BY 1)
SELECT po.line_id,
       po.po_number,
       CASE WHEN po.order_date ~ '^\d{2}\.\d{2}\.\d{4}$' THEN to_date(po.order_date, 'DD.MM.YYYY')
            WHEN po.order_date ~ '^\d{4}-\d{2}-\d{2}$'   THEN po.order_date::date
       END                                                              AS order_date,
       po.sourcing_market,
       po.buyer_region,
       po.material_id,
       m.category,
       po.net_amount_eur,
       po.rebate,
       po.price_variance_eur,
       COALESCE(po.quantity_kg,
                ROUND(po.net_amount_eur / (1 - po.rebate)
                      / COALESCE(g.p, mm.p, mt.p) / 25) * 25)          AS quantity_kg,
       CASE WHEN po.quantity_kg IS NOT NULL THEN 'reported'
            WHEN g.p  IS NOT NULL           THEN 'imputed: material + market + region'
            WHEN mm.p IS NOT NULL           THEN 'imputed: material + market'
            WHEN mt.p IS NOT NULL           THEN 'imputed: material'
            ELSE 'unresolved'
       END                                                              AS quantity_source,
       EXISTS (SELECT 1 FROM rejected_deliveries AS r
               WHERE r.po_number = po.po_number
                 AND r.sourcing_market = po.sourcing_market)            AS is_rejected
FROM   purchase_orders AS po
JOIN   raw_materials   AS m  USING (material_id)
LEFT   JOIN price_group      AS g  ON g.material_id  = po.material_id
                                   AND g.sourcing_market = po.sourcing_market
                                   AND g.buyer_region    = po.buyer_region
LEFT   JOIN price_mat_market AS mm ON mm.material_id = po.material_id
                                   AND mm.sourcing_market = po.sourcing_market
LEFT   JOIN price_material   AS mt ON mt.material_id = po.material_id;

-- How was each quantity obtained?
SELECT quantity_source,
       COUNT(*) AS lines
FROM   purchase_orders_clean
GROUP  BY quantity_source
ORDER  BY lines DESC;

-- The imputed lines (first 10)
SELECT line_id, material_id, sourcing_market, buyer_region,
       ROUND(net_amount_eur::numeric, 2) AS net_amount_eur,
       quantity_kg AS imputed_quantity_kg,
       quantity_source
FROM   purchase_orders_clean
WHERE  quantity_source <> 'reported'
ORDER  BY line_id
LIMIT  10;
