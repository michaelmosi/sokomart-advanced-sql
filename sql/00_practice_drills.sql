SET search_path TO sokomart;


-- =============================================================
-- D1. Products priced above the average unit_price   (scalar subquery)
-- Result: 10 rows (top 10) + 1 number (count above average)
-- =============================================================
SELECT product_id,
       product_name,
       category,
       unit_price,
       (SELECT ROUND(AVG(unit_price), 2) FROM sokomart.products) AS overall_avg_price
FROM sokomart.products
WHERE unit_price > (SELECT AVG(unit_price) FROM sokomart.products)
ORDER BY unit_price DESC
LIMIT 10;

SELECT COUNT(*) AS products_above_avg_price
FROM sokomart.products
WHERE unit_price > (SELECT AVG(unit_price) FROM sokomart.products);


-- =============================================================
-- D2. Mombasa residents with an order (any status) in December 2025   (IN subquery)
-- =============================================================
SELECT customer_id, first_name, last_name, email
FROM sokomart.customers
WHERE county = 'Mombasa'
  AND customer_id IN (SELECT customer_id
                      FROM sokomart.orders
                      WHERE order_date >= '2025-12-01'
                        AND order_date <  '2026-01-01')
ORDER BY customer_id;

SELECT COUNT(*) AS mombasa_customers_dec_2025
FROM sokomart.customers
WHERE county = 'Mombasa'
  AND customer_id IN (SELECT customer_id
                      FROM sokomart.orders
                      WHERE order_date >= '2025-12-01'
                        AND order_date <  '2026-01-01');


-- =============================================================
-- D3. Kisumu customers with at least one failed payment   (EXISTS, correlated)
-- =============================================================
SELECT COUNT(*) AS kisumu_customers_with_failed_payment
FROM sokomart.customers c
WHERE c.county = 'Kisumu'
  AND EXISTS (SELECT 1
              FROM sokomart.orders o
              JOIN sokomart.payments p ON p.order_id = o.order_id
              WHERE o.customer_id = c.customer_id
                AND p.payment_status = 'failed');


-- =============================================================
-- D4. Orders, avg lines and avg units per order by status   (derived table)
-- =============================================================
SELECT o.order_status,
       COUNT(*)                         AS orders,
       ROUND(AVG(per_order.lines), 2)   AS avg_lines_per_order,
       ROUND(AVG(per_order.units), 2)   AS avg_units_per_order
FROM sokomart.orders o
JOIN (SELECT order_id,
             COUNT(*)      AS lines,
             SUM(quantity) AS units
      FROM sokomart.order_items
      GROUP BY order_id) AS per_order
  ON per_order.order_id = o.order_id
GROUP BY o.order_status
ORDER BY orders DESC;


-- =============================================================
-- D5. Top 5 shipping counties by completed orders in 2026   (single CTE)
-- =============================================================
WITH completed_2026 AS (
    SELECT order_id, shipping_county
    FROM sokomart.orders
    WHERE order_status = 'completed'
      AND order_date >= '2026-01-01'
      AND order_date <  '2027-01-01'
)
SELECT shipping_county,
       COUNT(*) AS completed_orders
FROM completed_2026
GROUP BY shipping_county
ORDER BY completed_orders DESC, shipping_county
LIMIT 5;


-- =============================================================
-- D6. 2025 completed orders per month vs the 2025 monthly average   (chained CTEs)
-- Result: 12 rows
-- =============================================================
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_date) AS month_start,
           COUNT(*)                        AS completed_orders
    FROM sokomart.orders
    WHERE order_status = 'completed'
      AND order_date >= '2025-01-01'
      AND order_date <  '2026-01-01'
    GROUP BY 1
),
stats AS (
    SELECT AVG(completed_orders) AS avg_per_month FROM monthly
)
SELECT TO_CHAR(m.month_start, 'YYYY-MM')      AS month,
       m.completed_orders,
       ROUND(s.avg_per_month, 2)              AS avg_per_month,
       CASE WHEN m.completed_orders > s.avg_per_month
            THEN 'above average' ELSE 'at/below average' END AS vs_average
FROM monthly m
CROSS JOIN stats s
ORDER BY m.month_start;


-- =============================================================
-- D7. fn_order_count: number of orders (any status) for a customer   (SQL function)
-- =============================================================
CREATE OR REPLACE FUNCTION sokomart.fn_order_count(p_customer_id INTEGER)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
    SELECT COUNT(*)::INTEGER
    FROM sokomart.orders
    WHERE customer_id = p_customer_id;
$$;

SELECT sokomart.fn_order_count(177) AS orders_customer_177,
       sokomart.fn_order_count(-1)  AS orders_customer_missing;


-- =============================================================
-- D8. sp_set_customer_status with validation   (procedure, RAISE EXCEPTION, CALL)
-- =============================================================
CREATE OR REPLACE PROCEDURE sokomart.sp_set_customer_status(p_customer_id INTEGER,
                                                            p_status      VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_status NOT IN ('active', 'inactive', 'suspended') THEN
        RAISE EXCEPTION 'Invalid customer status "%". Allowed: active, inactive, suspended', p_status;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM sokomart.customers WHERE customer_id = p_customer_id) THEN
        RAISE EXCEPTION 'Customer % does not exist', p_customer_id;
    END IF;

    UPDATE sokomart.customers
    SET customer_status = p_status
    WHERE customer_id = p_customer_id;
END;
$$;

-- Status before, inside the transaction, and after rollback
SELECT customer_id, customer_status AS status_before FROM sokomart.customers WHERE customer_id = 177;

BEGIN;
CALL sokomart.sp_set_customer_status(177, 'suspended');
SELECT customer_id, customer_status AS status_inside_transaction FROM sokomart.customers WHERE customer_id = 177;
ROLLBACK;

SELECT customer_id, customer_status AS status_after_rollback FROM sokomart.customers WHERE customer_id = 177;

-- The exception for an invalid status, caught so the script keeps running
DO $$
BEGIN
    CALL sokomart.sp_set_customer_status(177, 'vip');
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected error: %', SQLERRM;
END;
$$;


-- =============================================================
-- D9. Beauty products with stock below the Beauty average   (CTE + scalar subquery)
-- =============================================================
WITH beauty AS (
    SELECT product_id, product_name, stock_quantity
    FROM sokomart.products
    WHERE category = 'Beauty'
)
SELECT product_id,
       product_name,
       stock_quantity,
       (SELECT ROUND(AVG(stock_quantity), 2) FROM beauty) AS beauty_avg_stock
FROM beauty
WHERE stock_quantity < (SELECT AVG(stock_quantity) FROM beauty)
ORDER BY stock_quantity, product_id;


-- =============================================================
-- D10. sp_county_summary with OUT parameters   (procedure with OUT params)
-- =============================================================
CREATE OR REPLACE PROCEDURE sokomart.sp_county_summary(IN  p_county    VARCHAR,
                                                       OUT p_customers INTEGER,
                                                       OUT p_revenue   NUMERIC)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT COUNT(*)
    INTO p_customers
    FROM sokomart.customers
    WHERE county = p_county;

    SELECT COALESCE(SUM(oi.line_total), 0)
    INTO p_revenue
    FROM sokomart.customers c
    JOIN sokomart.orders o       ON o.customer_id = c.customer_id
    JOIN sokomart.order_items oi ON oi.order_id   = o.order_id
    WHERE c.county = p_county
      AND o.order_status = 'completed';
END;
$$;

CALL sokomart.sp_county_summary('Nakuru', NULL, NULL);
