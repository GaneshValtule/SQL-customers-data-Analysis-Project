USE supertails;


-- Q1 --
SELECT c.customer_id,
       COUNT(o.order_id) AS orders_placed,
       IFNULL(SUM(o.total_amount),0) AS total_spend,
       c.is_premium,
       c.pet_type
FROM customers c
LEFT JOIN (SELECT order_id,customer_id,total_amount FROM orders WHERE total_amount > 0 ) o
ON c.customer_id = o.customer_id
GROUP BY c.customer_id;


-- Q2 -- 

WITH product_info AS (
SELECT p.product_id,
	   p.name,
       SUM(oi.quantity) As quantity_sold,
       SUM(oi.quantity*oi.price_per_unit) AS revenue,
       COUNT(DISTINCT o.customer_id) AS unique_customers,
       p.pet_type AS product_for
FROM products p 
JOIN order_items oi ON p.product_id = oi.product_id
JOIN (SELECT order_id,customer_id,total_amount FROM orders WHERE total_amount > 0 ) o ON oi.order_id = o.order_id 
GROUP BY p.product_id
),
product_rank AS(
SELECT product_id,
	   name,
       ROW_NUMBER() OVER (
        ORDER BY quantity_sold DESC, revenue DESC, unique_customers DESC
       ) AS rn,
       product_for
FROM product_info
)
SELECT product_id,
	   name,
       product_for
FROM product_rank
WHERE rn <= 5;

-- Q3 --

SELECT 
    c.city,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    COUNT(o.order_id) AS total_orders,
    SUM(o.total_amount) AS total_revenue,
    ROUND(100.0 * SUM(CASE WHEN c.is_premium = 'True' THEN 1 ELSE 0 END) / COUNT(c.customer_id),2) AS premium_customer_percent
FROM customers c
LEFT JOIN (SELECT order_id,customer_id,total_amount FROM orders WHERE total_amount > 0 ) o ON c.customer_id = o.customer_id
GROUP BY c.city
ORDER BY total_revenue DESC;


-- Q4 --

CREATE TEMPORARY TABLE customer_metrics AS
SELECT 
    e.customer_id,
    SUM(CASE WHEN e.event_type = 'view' THEN 1 ELSE 0 END) AS total_views,
    SUM(CASE WHEN e.event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS total_add_to_cart,
    SUM(CASE WHEN e.event_type = 'purchase' THEN 1 ELSE 0 END) AS total_purchase,
    SUM(CASE WHEN e.event_type = 'purchase' AND e.event_time >= NOW() - INTERVAL 30 DAY THEN 1 ELSE 0 END) AS recent_purchase,
    IFNULL(ROUND((SUM(CASE WHEN e.event_type = 'add_to_cart' THEN 1 ELSE 0 END) * 100.0) / NULLIF(SUM(CASE WHEN e.event_type = 'view' THEN 1 ELSE 0 END), 0), 2), 0) AS view_cart_conversion,
    IFNULL(ROUND((SUM(CASE WHEN e.event_type = 'purchase' THEN 1 ELSE 0 END) * 100.0) / NULLIF(SUM(CASE WHEN e.event_type = 'add_to_cart' THEN 1 ELSE 0 END), 0), 2), 0) AS cart_purchase_conversion
FROM events e
GROUP BY e.customer_id;

SELECT customer_id,total_views,total_add_to_cart,total_purchase,view_cart_conversion,cart_purchase_conversion
FROM customer_metrics;

-- Q5 --

DELIMITER $$
CREATE FUNCTION flag_customer(
    total_views INT,
    total_add_to_cart INT,
    recent_purchase INT
)
RETURNS VARCHAR(3)
DETERMINISTIC
BEGIN
    IF total_views > 5 AND total_add_to_cart > 2 AND recent_purchase >= 1 THEN
        RETURN 'YES'; 
    ELSE
        RETURN 'NO';
    END IF;
END$$
DELIMITER ;

SELECT customer_id
FROM customer_metrics
WHERE flag_customer(total_views, total_add_to_cart, recent_purchase) = 'YES';

	   
