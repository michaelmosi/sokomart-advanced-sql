SET search_path TO sokomart;


-- =============================================================
-- Q1. Big spenders of 2025   (CTE + scalar subquery over the CTE)
-- Result: 1,432 rows above average  (screenshot: screenshots/q01_big_spenders_2025.png)
-- =============================================================
WITH spend_2025 AS (
    SELECT o.customer_id,
           SUM(oi.line_total) AS total_spent_2025
    FROM sokomart.orders o
    JOIN sokomart.order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2025-01-01'
      AND o.order_date <  '2026-01-01'
    GROUP BY o.customer_id
)
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name                              AS full_name,
       c.county,
       s.total_spent_2025,
       ROUND((SELECT AVG(total_spent_2025) FROM spend_2025), 2)        AS avg_spent_2025,
       ROUND(s.total_spent_2025
             - (SELECT AVG(total_spent_2025) FROM spend_2025), 2)      AS amount_above_avg
FROM spend_2025 s
JOIN sokomart.customers c ON c.customer_id = s.customer_id
WHERE s.total_spent_2025 > (SELECT AVG(total_spent_2025) FROM spend_2025)
ORDER BY s.total_spent_2025 DESC;

-- Q1 check: buyers in 2025, the average, and the number of rows above
WITH spend_2025 AS (
    SELECT o.customer_id,
           SUM(oi.line_total) AS total_spent_2025
    FROM sokomart.orders o
    JOIN sokomart.order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2025-01-01'
      AND o.order_date <  '2026-01-01'
    GROUP BY o.customer_id
)
SELECT COUNT(*)                                                         AS customers_bought_2025,
       ROUND(AVG(total_spent_2025), 2)                                  AS avg_spent_2025,
       COUNT(*) FILTER (WHERE total_spent_2025 >
                        (SELECT AVG(total_spent_2025) FROM spend_2025)) AS customers_above_avg
FROM spend_2025;


-- =============================================================
-- Q2. Premium-priced products   (correlated subquery in WHERE and SELECT, no window functions)
-- Active products priced above the average of their category (average over all products
-- in the category, any status).
-- Result: 104 rows  (screenshot: screenshots/q02_premium_products.png)
-- =============================================================
SELECT p.product_id,
       p.product_name,
       p.category,
       p.unit_price,
       (SELECT ROUND(AVG(p2.unit_price), 2)
        FROM sokomart.products p2
        WHERE p2.category = p.category)                      AS category_avg_price,
       ROUND(p.unit_price - (SELECT AVG(p2.unit_price)
                             FROM sokomart.products p2
                             WHERE p2.category = p.category), 2) AS price_gap
FROM sokomart.products p
WHERE p.product_status = 'active'
  AND p.unit_price > (SELECT AVG(p2.unit_price)
                      FROM sokomart.products p2
                      WHERE p2.category = p.category)
ORDER BY p.category, price_gap DESC;

-- Q2 check: rows per category
SELECT p.category,
       COUNT(*) AS premium_products
FROM sokomart.products p
WHERE p.product_status = 'active'
  AND p.unit_price > (SELECT AVG(p2.unit_price)
                      FROM sokomart.products p2
                      WHERE p2.category = p.category)
GROUP BY p.category
ORDER BY p.category;


-- =============================================================
-- Q3. 2026 monthly profit and loss, January to October   (three chained CTEs)
-- Result: 10 rows  (screenshot: screenshots/q03_monthly_pnl_2026.png)
-- =============================================================
WITH completed_lines AS (            -- (1) completed order lines with month and line cost
    SELECT DATE_TRUNC('month', o.order_date) AS month_start,
           oi.line_total,
           oi.quantity * p.cost_price        AS line_cost
    FROM sokomart.orders o
    JOIN sokomart.order_items oi ON oi.order_id   = o.order_id
    JOIN sokomart.products p     ON p.product_id  = oi.product_id
    WHERE o.order_status = 'completed'
      AND o.order_date >= '2026-01-01'
      AND o.order_date <  '2026-11-01'
),
monthly AS (                          -- (2) monthly revenue and cost
    SELECT month_start,
           SUM(line_total) AS revenue,
           SUM(line_cost)  AS cost
    FROM completed_lines
    GROUP BY month_start
),
profit AS (                           -- (3) gross profit
    SELECT month_start, revenue, cost,
           revenue - cost AS gross_profit
    FROM monthly
)
SELECT TO_CHAR(month_start, 'YYYY-MM')                     AS month,
       revenue,
       cost,
       gross_profit,
       ROUND(100 * gross_profit / NULLIF(revenue, 0), 2)   AS margin_pct
FROM profit
ORDER BY month_start;


-- =============================================================
-- Q4. Cross-category shoppers in Nakuru   (derived table, COUNT(DISTINCT))
-- Customers living in Nakuru with 3+ distinct categories in their completed orders.
-- Result: 346 rows  (screenshot: screenshots/q04_nakuru_cross_category.png)
-- =============================================================
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS full_name,
       c.county,
       t.category_count,
       t.total_spent
FROM (SELECT o.customer_id,
             COUNT(DISTINCT p.category) AS category_count,
             SUM(oi.line_total)         AS total_spent
      FROM sokomart.orders o
      JOIN sokomart.order_items oi ON oi.order_id  = o.order_id
      JOIN sokomart.products p     ON p.product_id = oi.product_id
      WHERE o.order_status = 'completed'
      GROUP BY o.customer_id) AS t
JOIN sokomart.customers c ON c.customer_id = t.customer_id
WHERE c.county = 'Nakuru'
  AND t.category_count >= 3
ORDER BY t.category_count DESC, t.total_spent DESC;

-- Q4 check: how many qualify, and how many bought from all five categories
SELECT COUNT(*)                                     AS nakuru_customers_3plus_categories,
       COUNT(*) FILTER (WHERE t.category_count = 5) AS bought_all_five_categories
FROM (SELECT o.customer_id,
             COUNT(DISTINCT p.category) AS category_count
      FROM sokomart.orders o
      JOIN sokomart.order_items oi ON oi.order_id  = o.order_id
      JOIN sokomart.products p     ON p.product_id = oi.product_id
      WHERE o.order_status = 'completed'
      GROUP BY o.customer_id) AS t
JOIN sokomart.customers c ON c.customer_id = t.customer_id
WHERE c.county = 'Nakuru'
  AND t.category_count >= 3;


-- =============================================================
-- Q5. Products nobody has ordered   (anti-join with NOT EXISTS; NOT IN not used)
-- Result: 18 rows  (screenshot: screenshots/q05_never_ordered_products.png)
-- =============================================================
SELECT p.product_id,
       p.product_name,
       p.category,
       p.product_status,
       p.stock_quantity,
       p.created_at
FROM sokomart.products p
WHERE NOT EXISTS (SELECT 1
                  FROM sokomart.order_items oi
                  WHERE oi.product_id = p.product_id)
ORDER BY p.category, p.product_name;
