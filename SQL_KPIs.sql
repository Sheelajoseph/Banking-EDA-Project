create database supplychain;

drop tables if exists;

use supplychain;
show tables;

select * from inventory;
select * from products;
select * from purchase_orders;
select * from sales_orders;
select * from vendors;


#TOTAL REVENUE
SELECT 
    SUM(quantity_sold * selling_price) AS total_revenue
FROM sales_orders;

#TOTAL PROFIT
SELECT 
     SUM(quantity_ordered * unit_cost)
   - SUM(quantity_sold * selling_price) AS profit
FROM sales_orders s
JOIN products p ON s.product_id = p.product_id
JOIN purchase_orders po ON p.product_id = po.product_id;

#Top 10 Selling Products (Quantity)
SELECT 
    p.category as product_name,
    SUM(s.quantity_sold) AS total_quantity
FROM sales_orders s
JOIN products p ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY total_quantity DESC
LIMIT 10;


#Revenue by Product
SELECT 
    p.category as product_name,
    SUM(s.quantity_sold * selling_price) AS revenue
FROM sales_orders s
JOIN products p ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue DESC;

#Monthly Sales Revenue
SELECT 
    DATE_FORMAT(date, '%Y-%m') AS month,
    SUM(quantity_sold * selling_price) AS monthly_revenue
FROM sales_orders
GROUP BY month
ORDER BY month;


#INVENTORY KPIs
#Inventory Turnover Ratio
#Inventory Turnover = Total Units Sold / Average Inventory
SELECT 
    SUM(s.quantity_sold) / AVG(i.current_stock) AS inventory_turnover
FROM sales_orders s
CROSS JOIN inventory i;


#Stockout Products
SELECT 
    p.category as product_name,
    COUNT(*) AS stockout_count
FROM inventory i
JOIN products p ON i.product_id = p.product_id
WHERE current_stock > 100
GROUP BY p.category;


#VENDOR PERFORMANCE QUERIES
#Average Lead Time (Days) Per Vendor
SELECT 
    v.product_id,
    AVG(DATEDIFF(po.actual_delivery_date, po.order_date)) AS avg_lead_time
FROM purchase_orders po
JOIN vendors v ON po.order_date = v.product_id
GROUP BY v.product_id
ORDER BY avg_lead_time;

#Vendor On-Time Delivery %
WITH lead_times AS (
    SELECT 
        vendor_id,
        DATEDIFF(expected_delivery_date, order_date) AS lead_time
    FROM purchase_orders
),
median_value AS (
    SELECT 
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lead_time) AS median_lead
    FROM lead_times
),
joined AS (
    SELECT 
        l.vendor_id,
        l.lead_time,
        m.median_lead
    FROM lead_times l
    CROSS JOIN median_value m
)
SELECT 
    v.product_id,
    AVG(CASE WHEN lead_time <= median_lead THEN 1 ELSE 0 END) * 100 AS on_time_delivery_percentage
FROM joined j
JOIN vendors v ON j.vendor_id = v.product_id
GROUP BY v.product_id;


#Vendor Performance Score
WITH lead_time AS (
    SELECT 
        po.vendor_id,
        DATEDIFF(po.expected_delivery_date, po.order_date) AS lead_time
    FROM purchase_orders po
),
median_lead AS (
    SELECT 
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lead_time) AS median_lead
    FROM lead_time
),
on_time AS (
    SELECT 
        l.vendor_id,
        CASE WHEN l.lead_time <= (SELECT median_lead FROM median_lead) THEN 1 ELSE 0 END AS on_time_flag
    FROM lead_time l
),
vendor_summary AS (
    SELECT 
        v.sales_id,
        AVG(o.on_time_flag) * 100 AS on_time_percentage,
        AVG(v.vendor_rating) AS avg_rating
    FROM on_time o
    JOIN vendors v ON o.vendor_id = v.product_id
    GROUP BY v.product_id
)
SELECT 
    v.vendor_name,
    s.on_time_percentage,
    s.avg_rating,
    (s.on_time_percentage * 0.6) + (s.avg_rating * 0.4) AS performance_score
FROM vendor_summary s
JOIN vendors v ON s.vendor_id = v.product_id
ORDER BY performance_score DESC;


#SUPPLY CHAIN EFFICIENCY KPIs
#Order Fulfillment Rate
SELECT 
    (SUM(CASE WHEN quantity_sold > 0 THEN 1 ELSE 0 END) / COUNT(*)) * 100 
    AS order_fulfillment_rate
FROM sales_orders;


#Perfect Order Rate
#Perfect order =correct quantity+on-time ship+no stock issue

SELECT 
    (SUM(
        CASE 
            WHEN quantity_sold > 0 
             AND ship_date = order_date 
            THEN 1 
            ELSE 0 
        END
    ) / COUNT(*)) * 100 AS perfect_order_rate
FROM sales_orders;

