-- 02_top5_materials_per_category.sql
-- Which five raw materials carry the most spend in each category, and how did we do against standard cost?
--
-- Techniques: anti-join (NOT EXISTS), nested CTEs, RANK() and SUM() OVER (PARTITION BY ...).
-- Rejected deliveries are excluded: they were not accepted into stock, so they are not real spend.
-- price_variance_eur > 0 means the material was bought below standard cost.

CREATE OR REPLACE VIEW v_top5_materials_per_category AS
WITH accepted_lines AS (
    SELECT po.*
    FROM   purchase_orders AS po
    WHERE  NOT EXISTS (SELECT 1
                       FROM   rejected_deliveries AS r
                       WHERE  r.po_number = po.po_number
                         AND  r.sourcing_market = po.sourcing_market)
),
spend_by_material AS (
    SELECT m.category,
           m.material_name,
           SUM(a.net_amount_eur)      AS total_spend_eur,
           SUM(a.price_variance_eur)  AS total_price_variance_eur
    FROM   accepted_lines AS a
    JOIN   raw_materials  AS m USING (material_id)
    GROUP  BY m.category, m.material_name
),
ranked AS (
    SELECT s.*,
           RANK() OVER (PARTITION BY category ORDER BY total_spend_eur DESC)      AS spend_rank,
           100 * total_spend_eur / SUM(total_spend_eur) OVER (PARTITION BY category) AS pct_of_category_spend
    FROM   spend_by_material AS s
)
SELECT category,
       spend_rank,
       material_name,
       ROUND(total_spend_eur::numeric, 0)           AS total_spend_eur,
       ROUND(total_price_variance_eur::numeric, 0)  AS total_price_variance_eur,
       ROUND(pct_of_category_spend::numeric, 1)     AS pct_of_category_spend
FROM   ranked
WHERE  spend_rank <= 5
ORDER  BY category, spend_rank;

SELECT * FROM v_top5_materials_per_category;
