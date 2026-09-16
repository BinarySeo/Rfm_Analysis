# 📊 Sales Data & RFM Customer Segmentation Analysis

A comprehensive SQL-based exploratory data analysis (EDA) and **RFM (Recency, Frequency, Monetary)** customer segmentation project built on historical sales performance data.

---

## 📌 Project Overview

The primary objective of this project is to analyze historical sales data to understand key revenue drivers (product lines, territories, deal sizes, seasonality) and execute an **RFM Analysis** to segment the customer base.

By categorizing customers into actionable segments (**Regular**, **Target**, and **Inactive**), this project provides actionable insights for marketing strategies—specifically aiming to re-engage high-value inactive customers and optimize promotional campaigns prior to peak sales months (e.g., November).

---

## 🎯 Key Objectives

1. **Data Cleaning & Formatting**: Standardize dates and prepare data for time-series and cohort analysis.
2. **Exploratory Data Analysis (EDA)**:
   - Identify top-performing product lines, territories, and deal sizes.
   - Evaluate yearly and monthly revenue trends (identifying operational constraints vs. peak seasons).
3. **RFM Customer Segmentation**:
   - Calculate **Recency** (days since last purchase), **Frequency** (total orders), and **Monetary** value (total spend) per customer.
   - Assign quartile scores (1–4) using SQL window functions (`NTILE(4)`).
   - Classify customers into strategic segments for targeted marketing campaigns.

---

## 🗄️ Database & Schema Overview

The dataset revolves around the `sales` table, which includes details on orders, product categories, geographic locations, and customer identifiers.

### Key Dimensions Explored:
* **Product Lines**: 7 distinct product lines.
* **Geographic Coverage**: 19 countries across 4 major territories.
* **Deal Sizes**: 3 categories (`Small`, `Medium`, `Large`).
* **Time Span**: Data spanning 2003, 2004, and partial 2005 (through May).
* **Order Statuses**: 6 unique fulfillment statuses.

---

## 🛠️ Data Preparation & Cleaning

```sql
-- Disable safe updates for data modification
SET sql_safe_updates = 0;

-- Standardize orderdate column from string format ('%m/%d/%y %H:%i:%s') to DATETIME
UPDATE sales
SET orderdate = STR_TO_DATE(orderdate, "%m/%d/%y %H:%i:%s");

-- Verify maximum order date for recency benchmarks
SELECT MAX(orderdate) FROM sales;
```

---

## 🔍 Exploratory Data Analysis (EDA)

### 1. High-Level Summary
```sql
SELECT DISTINCT status FROM sales;           -- 6 fulfillment statuses
SELECT DISTINCT year_id FROM sales;          -- Years: 2003, 2004, 2005
SELECT DISTINCT productline FROM sales;      -- 7 distinct product lines
SELECT COUNT(DISTINCT country) FROM sales;   -- 19 countries
SELECT DISTINCT dealsize FROM sales;         -- 3 deal sizes
SELECT DISTINCT territory FROM sales;       -- 4 territories
```

### 2. Revenue & Performance Insights
* **Product Line Breakdown**: Groups overall revenue by product categories to highlight top revenue drivers.
  ```sql
  SELECT productline, SUM(sales) AS total_sales 
  FROM sales 
  GROUP BY productline 
  ORDER BY 2 DESC;
  ```
* **Yearly Trends & Seasonality**: Evaluates total sales per year and checks operational month counts. (Note: 2003 and 2004 have full 12-month data, whereas 2005 includes data up to May).
  ```sql
  SELECT year_id, SUM(sales) AS total_sales 
  FROM sales 
  GROUP BY year_id 
  ORDER BY 2 DESC;

  SELECT year_id, COUNT(DISTINCT month_id) AS operational_months 
  FROM sales 
  GROUP BY year_id 
  ORDER BY 1 DESC;
  ```
* **Territory & Deal Size Metrics**:
  ```sql
  -- Revenue by deal size
  SELECT dealsize, SUM(sales) AS total_sales 
  FROM sales 
  GROUP BY dealsize 
  ORDER BY 2 DESC;

  -- Performance by territory
  SELECT 
      territory, 
      AVG(sales) AS avg_sales, 
      COUNT(orderdate) AS total_order_quantity 
  FROM sales 
  GROUP BY territory 
  ORDER BY 3 DESC;
  ```

---

## 📈 RFM Analysis & Customer Segmentation

### 1. Constructing the RFM Temporary Table
We utilize Common Table Expressions (CTEs) alongside window functions (`NTILE(4)`) to compute RFM metrics for each customer relative to the latest transaction date in the dataset.

```sql
DROP TABLE IF EXISTS rfm_temp;

CREATE TEMPORARY TABLE rfm_temp (
    Customername VARCHAR(50),
    Monetary DOUBLE,
    Average_Monetary DOUBLE,
    Frequency INT,
    last_order_date DATE,
    last_date DATE,
    recency INT,
    rfm_recency INT,
    rfm_frequency INT,
    rfm_Monetary INT,
    Rfm_Cell INT,
    rfm_cell_string VARCHAR(10)
);

-- Calculate raw RFM metrics and NTILE score rankings
INSERT INTO rfm_temp
WITH rfm AS (
    SELECT 
        customername,
        SUM(sales) AS Monetary,
        AVG(sales) AS Average_Monetary,
        COUNT(orderdate) AS Frequency,
        MAX(orderdate) AS last_order_date,
        (SELECT MAX(orderdate) FROM sales) AS last_date,
        DATEDIFF((SELECT MAX(orderdate) FROM sales), MAX(orderdate)) AS recency
    FROM sales 
    GROUP BY customername
),
rfm_calc AS (
    SELECT 
        r.*,
        NTILE(4) OVER (ORDER BY recency DESC) AS rfm_recency,
        NTILE(4) OVER (ORDER BY Frequency ASC) AS rfm_frequency,
        NTILE(4) OVER (ORDER BY Monetary ASC) AS rfm_Monetary
    FROM rfm r
)
SELECT 
    c.*, 
    (rfm_recency + rfm_frequency + rfm_Monetary) AS Rfm_Cell,
    CONCAT(rfm_recency, rfm_frequency, rfm_Monetary) AS rfm_cell_string
FROM rfm_calc c;
```

---

### 2. Segment Classification Rules

Customers are rated from **1 to 4** across Recency, Frequency, and Monetary parameters (4 being the highest/best rating).

| Customer Category | Description & Business Strategy | RFM Combinations |
| :--- | :--- | :--- |
| **Regular** | Most active, recent, and high-spending customers. Maintain loyalty through rewards and exclusive offers. | `444`, `443`, `442`, `441`, `434`, `433`, `432`, `344`, `334`, `343`, `342`, `341`, `333`, `332`, `331`, `244`, `243`, `242`, `241` |
| **Target** | Moderate activity/recency. Key focus group for pre-peak season campaigns to re-engage before November. | `431`, `424`, `423`, `422`, `421`, `414`, `413`, `412`, `411`, `324`, `323`, `322`, `321`, `314`, `313`, `312`, `311`, `224`, `223`, `232`, `233`, `234` |
| **Inactive** | Lapsed buyers or one-time high spenders who haven't returned recently. Requires win-back incentives. | `144`, `143`, `142`, `141`, `134`, `133`, `132`, `131`, `124`, `123`, `122`, `121`, `112`, `111`, `211`, `212`, `213`, `214`, `222`, `221` |

```sql
SELECT 
    customername, 
    rfm_recency, 
    rfm_frequency, 
    rfm_Monetary,
    CASE
        WHEN rfm_cell_string IN ('144','143','142','141','134','133','132','131','124','123','122','121','112','111','211','212','213','214','222','221') THEN 'Inactive'
        WHEN rfm_cell_string IN ('431','424','423','422','421','414','413','412','411','324','323','322','321','314','313','312','311','224','223','232','233','234') THEN 'Target'
        WHEN rfm_cell_string IN ('444','443','442','441','434','433','432','344','334','343','342','341','333','332','331','244','243','242','241') THEN 'Regular'
    END AS customer_type
FROM rfm_temp;
```

---

## 🚀 Strategic Recommendations

1. **Pre-November Target Marketing**: Prioritize the **"Target"** segment with tailored promotional campaigns prior to November (historically the highest-performing sales month).
2. **Win-Back Campaigns**: Analyze churning patterns among **"Inactive"** customers (specifically high monetary score cells like `144`, `143`, `134`) who made significant past purchases but have stopped returning.
3. **VIP Loyalty Programs**: Offer special perks and early product access to **"Regular"** customers (`444`, `443`, etc.) to maximize Customer Lifetime Value (CLV).

---

## 🛠️ How to Run
1. Load your sales dataset into MySQL.
2. Execute the data preparation and date conversion queries.
3. Run the EDA scripts to review general sales metrics.
4. Execute the RFM temporary table creation script followed by the final classification query to output customer segments.
