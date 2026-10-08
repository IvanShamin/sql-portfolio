-- 05_sanity_checks.sql
-- Assertions on the result of 02_net_revenue_wholesale.sql. The script fails (and run_all stops)
-- if any of them is violated.

DO $$
DECLARE
    expected_rows constant integer := 5 * 3 * 3;      -- product lines x months x warehouses
BEGIN
    ASSERT (SELECT COUNT(*) FROM v_net_revenue_wholesale) = expected_rows,
           'unexpected number of product line / month / warehouse combinations';

    ASSERT (SELECT COUNT(*) FROM v_net_revenue_wholesale WHERE net_revenue_eur IS NULL OR net_revenue_eur <= 0) = 0,
           'net revenue must be positive for every combination';

    ASSERT (SELECT SUM(net_revenue_eur) FROM v_net_revenue_wholesale)
           < (SELECT SUM(total_eur) FROM sales WHERE client_type = 'Wholesale'),
           'net revenue must be lower than gross revenue';

    -- independent recomputation without the view: fee amounts reconcile gross and net
    ASSERT abs((SELECT SUM(total_eur) FROM sales WHERE client_type = 'Wholesale')
             - (SELECT SUM(total_eur * payment_fee_pct / 100.0) FROM sales WHERE client_type = 'Wholesale')
             - (SELECT SUM(net_revenue_eur) FROM v_net_revenue_wholesale)) < 0.5,
           'gross - fees must equal net revenue (rounding tolerance 0.5 EUR)';
END
$$;

SELECT 'all sanity checks passed' AS result;
