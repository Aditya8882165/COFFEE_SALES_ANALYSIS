-- Using the SQL project database
USE sql_project;

-- Q1. Coffee Consumers Count
-- How many people in each city are estimated to consume coffee, given that 25% of the population does?
SELECT 
    city_name,
    CONCAT(ROUND((population * 0.25) / 1000000, 2), ' M') AS coffee_consumer
FROM
    city
ORDER BY 2 DESC;

-- Q2. Total Revenue from Coffee Sales
-- What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?
SELECT 
    city_name, SUM(total) AS total_revenue
FROM
    city c
    JOIN customers cu ON c.city_id = cu.city_id
    JOIN sales s ON cu.customer_id = s.customer_id
WHERE
    YEAR(sale_date) = 2023 AND QUARTER(sale_date) = 4
GROUP BY 1
ORDER BY 2 DESC;

-- Q3. Sales Count for Each Product
-- How many units of each coffee product have been sold?
SELECT 
    p.product_name, COUNT(*) AS qty_sold
FROM
    products p
    LEFT JOIN sales s ON p.product_id = s.product_id
GROUP BY 1
ORDER BY 2 DESC;

-- Q4. Average Sales Amount per City
-- What is the average sales amount per customer in each city?
SELECT 
    c.city_name,
    COUNT(DISTINCT cu.customer_id) AS total_customers,
    ROUND(SUM(total) / COUNT(DISTINCT cu.customer_id), 2) AS average_sales_amount
FROM
    city c
    JOIN customers cu ON c.city_id = cu.city_id
    JOIN sales s ON cu.customer_id = s.customer_id
GROUP BY 1
ORDER BY 3 DESC, 2 DESC;

-- Q5. City Population and Coffee Consumers (25%)
-- Provide a list of cities along with their populations and estimated coffee consumers.
SELECT 
    c.city_name,
    CONCAT(ROUND(c.population / 1000000, 2), " M") AS population,
    CONCAT(ROUND((population * 0.25) / 1000000, 2), ' M') AS coffee_consumer,
    COUNT(DISTINCT cu.customer_id) AS current_population
FROM
    city c
    JOIN customers cu ON c.city_id = cu.city_id
GROUP BY 1, 2, 3;

-- Q6. Top Selling Products by City
-- What are the top 3 selling products in each city based on sales volume?
WITH cte1 AS (
    SELECT c.city_id, c.city_name FROM city c
),
cte2 AS (
    SELECT cu.city_id, cu.customer_id FROM customers cu
),
cte3 AS (
    SELECT s.product_id, s.customer_id, s.total FROM sales s
),
cte4 AS (
    SELECT p.product_id, p.product_name FROM products p
),
cte5 AS (
    SELECT city_name, product_name, SUM(total) AS total_sales,
        DENSE_RANK() OVER (PARTITION BY city_name ORDER BY SUM(total) DESC) AS rnk
    FROM cte1
    JOIN cte2 ON cte1.city_id = cte2.city_id
    JOIN cte3 ON cte2.customer_id = cte3.customer_id
    JOIN cte4 ON cte3.product_id = cte4.product_id
    GROUP BY 1, 2
)
SELECT 
    city_name, product_name, total_sales
FROM
    cte5
WHERE
    rnk < 4;

-- Q7. Customer Segmentation by City
-- How many unique customers are there in each city who have purchased coffee products?
SELECT 
    city_name,
    COUNT(DISTINCT cu.customer_id) AS unique_customers
FROM
    city c
    JOIN customers cu ON c.city_id = cu.city_id
    JOIN sales s ON s.customer_id = cu.customer_id
GROUP BY 1
ORDER BY 2 DESC;

-- Q8. Average Sale vs Rent
-- Find each city and their average sale per customer and avg rent per customer
WITH cte1 AS (
    SELECT 
        c.city_name,
        COUNT(DISTINCT cu.customer_id) AS total_cus,
        ROUND(SUM(total) / COUNT(DISTINCT cu.customer_id), 2) AS average_sales_amount
    FROM
        city c
        JOIN customers cu ON c.city_id = cu.city_id
        JOIN sales s ON cu.customer_id = s.customer_id
    GROUP BY 1
),
cte2 AS (
    SELECT 
        c.city_name,
        ROUND(c.estimated_rent / cte1.total_cus, 2) AS average_rent
    FROM
        city c
        JOIN cte1 ON c.city_name = cte1.city_name
)
SELECT 
    cte1.city_name, average_sales_amount, average_rent
FROM
    cte1
    JOIN cte2 ON cte1.city_name = cte2.city_name;

-- Q9. Monthly Sales Growth
-- Calculate the percentage growth (or decline) in sales over different time periods (monthly) by each city
WITH cte1 AS (
    SELECT 
        c.city_name,
        year(s.sale_date) as sale_year,
        month(s.sale_date) as sale_month,
        SUM(s.total) AS total_sale
    FROM city c
    JOIN customers cu ON c.city_id = cu.city_id
    JOIN sales s ON cu.customer_id = s.customer_id
    GROUP BY 1,2,3
),
cte2 AS (
    SELECT 
        *,
        CONCAT(ROUND(((total_sale - LAG(total_sale) OVER (PARTITION BY city_name ORDER BY sale_year, sale_month)) / 
        LAG(total_sale) OVER (PARTITION BY city_name ORDER BY sale_year, sale_month)) * 100, 2), " %") AS growth_percentage
    FROM cte1
)
SELECT * FROM cte2 WHERE growth_percentage IS NOT NULL;

-- Q10. Market Potential Analysis
-- Identify top 3 cities based on highest sales; return city name, total sale, total rent, total customers
WITH cte AS (
    SELECT 
        city_name,
        estimated_rent,
        SUM(total) AS total_sales,
        COUNT(DISTINCT cu.customer_id) AS total_customers,
        RANK() OVER (ORDER BY SUM(total) DESC) AS rnk
    FROM
        city c
        JOIN customers cu ON c.city_id = cu.city_id
        JOIN sales s ON cu.customer_id = s.customer_id
    GROUP BY 1, 2
)
SELECT city_name, estimated_rent, total_sales, total_customers 
FROM cte 
WHERE rnk < 4;

-- Q11. Percentage contribution of each product to the total revenue
SELECT 
    product_name,
    CONCAT(ROUND((SUM(total) / (SELECT SUM(total) FROM sales)) * 100, 2), ' %') AS contribution
FROM
    products p
    JOIN sales s ON p.product_id = s.product_id
GROUP BY 1;

-- Q12. Customers who have purchased products from more than 3 different cities
SELECT 
    cu.customer_id, cu.customer_name
FROM
    customers cu
    JOIN sales s ON cu.customer_id = s.customer_id
GROUP BY 1, 2
HAVING COUNT(DISTINCT cu.city_id) > 3;
-- Note: Returns empty dataset as no customer has purchased from more than 3 cities

-- Q13. Customers who have never made a purchase
SELECT 
    customer_name
FROM
    customers c
    LEFT JOIN sales s ON c.customer_id = s.customer_id
WHERE
    sale_id IS NULL;
-- Note: Returns empty dataset as all customers have made purchases

-- Q14. Difference in total sales between best and worst-performing products
WITH cte AS (
    SELECT product_name, SUM(total) AS Total
    FROM products p 
    JOIN sales s ON p.product_id = s.product_id
    GROUP BY 1
    ORDER BY 2 DESC
),
cte1 AS (
    SELECT 
        FIRST_VALUE(Total) OVER() - LAST_VALUE(Total) OVER(ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS difference
    FROM cte
)
SELECT difference FROM (
    SELECT *, ROW_NUMBER() OVER() AS number1 FROM cte1
) t 
WHERE number1 = 1;