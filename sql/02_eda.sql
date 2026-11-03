-- =============================================================================
-- 02_eda.sql — exploratory analysis of the sales table
-- Each query is read-only; results are summarized in the README.
-- =============================================================================

-- Date range of the data (recency is measured from the last order date)
SELECT MIN(orderdate) AS first_order, MAX(orderdate) AS last_order FROM sales;

-- Shape of the data: 6 statuses, 3 years, 7 product lines, 19 countries, 3 deal sizes, 4 territories
SELECT
    COUNT(*)                     AS order_lines,
    COUNT(DISTINCT ordernumber)  AS orders,
    COUNT(DISTINCT customername) AS customers,
    COUNT(DISTINCT status)       AS statuses,
    COUNT(DISTINCT year_id)      AS years,
    COUNT(DISTINCT productline)  AS product_lines,
    COUNT(DISTINCT country)      AS countries,
    COUNT(DISTINCT dealsize)     AS deal_sizes,
    COUNT(DISTINCT territory)    AS territories
FROM sales;

-- Revenue by product line
SELECT productline,
       SUM(sales)                                          AS total_sales,
       ROUND(100 * SUM(sales) / SUM(SUM(sales)) OVER (), 1) AS pct_of_total
FROM sales
GROUP BY productline
ORDER BY total_sales DESC;

-- Revenue by year, with how many months each year covers (2005 stops in May)
SELECT year_id,
       SUM(sales)               AS total_sales,
       COUNT(DISTINCT month_id) AS months_with_sales
FROM sales
GROUP BY year_id
ORDER BY year_id;

-- Year-over-year growth for the two complete years
SELECT y.year_id,
       y.total_sales,
       ROUND(100 * (y.total_sales / LAG(y.total_sales) OVER (ORDER BY y.year_id) - 1), 1) AS yoy_growth_pct
FROM (SELECT year_id, SUM(sales) AS total_sales FROM sales WHERE year_id < 2005 GROUP BY year_id) y;

-- Seasonality: best months across the two complete years
SELECT month_id, SUM(sales) AS total_sales
FROM sales
WHERE year_id < 2005
GROUP BY month_id
ORDER BY total_sales DESC;

-- Revenue by deal size
SELECT dealsize,
       SUM(sales)                                          AS total_sales,
       ROUND(100 * SUM(sales) / SUM(SUM(sales)) OVER (), 1) AS pct_of_total
FROM sales
GROUP BY dealsize
ORDER BY total_sales DESC;

-- Territory performance ('NA' = North America)
SELECT territory,
       SUM(sales)  AS total_sales,
       AVG(sales)  AS avg_order_line_value,
       COUNT(*)    AS order_lines
FROM sales
GROUP BY territory
ORDER BY total_sales DESC;

-- Top countries
SELECT country, SUM(sales) AS total_sales
FROM sales
GROUP BY country
ORDER BY total_sales DESC
LIMIT 5;
