# 📊 Sales Data & RFM Customer Segmentation Analysis

A comprehensive SQL-based exploratory data analysis (EDA) and **RFM (Recency, Frequency, Monetary)** customer segmentation project built on historical sales performance data.

---

## 📌 Project Overview

The primary objective of this project is to analyze historical sales data to understand key revenue drivers (product lines, territories, deal sizes, seasonality) and execute an **RFM Analysis** to segment the customer base.

By categorizing customers into actionable segments (**Regular**, **Target**, and **Inactive**), this project provides actionable insights for marketing strategies—specifically aiming to re-engage high-value inactive customers and optimize promotional campaigns prior to peak sales months (e.g., November).

**Skills:** MySQL · data cleaning (`STR_TO_DATE`) · aggregation & EDA · CTEs · window functions (`NTILE`) · temporary tables · `CASE`-based segmentation · translating results into marketing actions

---

## 🔑 Key Findings

*2,823 order lines · 307 orders · 92 customers · Jan 2003 – May 2005 · $10.03M total sales*

| Question | Answer |
|---|---|
| Top product line | **Classic Cars** — $3.92M (39% of revenue), followed by Vintage Cars ($1.90M) |
| Best territory | **EMEA** — $4.98M, ahead of North America ($3.85M); USA is the top single country ($3.63M) |
| Deal size | **Medium** deals bring in $6.09M (61%) — more than Small and Large combined |
| Seasonality | **November** is the peak month: $2.12M across 2003–04, nearly double October ($1.12M) |
| Year over year | 2004 sales ($4.72M) grew **34%** over 2003 ($3.52M); 2005 covers only Jan–May |

These findings drive the segmentation below: the November peak sets the campaign timing, and the RFM segments decide who to target.

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

[`sql/01_load.sql`](sql/01_load.sql) loads the CSV into a text staging table, then builds a typed `sales` table:

* **Dates** — `'2/24/03'` is parsed once into a real `DATE` column (the original text is kept), instead of overwriting the column in place, so the script can be re-run safely.
* **Types & keys** — money as `DECIMAL`, counts as integers, primary key on order number + line number, indexes on customer and date.
* **Clean-up** — the CSV uses Windows line endings, which left a hidden `\r` on the last column and split "Medium" deals into two groups; it's stripped on load.

```sql
INSERT INTO sales
SELECT ..., STR_TO_DATE(ORDERDATE, '%m/%d/%y') AS orderdate, ORDERDATE AS order_date_raw, ...,
       TRIM(REPLACE(DEALSIZE, '\r', '')) AS dealsize
FROM sales_raw;
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

[`sql/03_rfm.sql`](sql/03_rfm.sql) builds two views so results always reflect the current data.

### 1. RFM scores (`customer_rfm` view)

* **Recency** — days between the customer's last order and the last order in the data
* **Frequency** — number of distinct orders (not order lines)
* **Monetary** — total sales

```sql
CREATE OR REPLACE VIEW customer_rfm AS
WITH rfm AS (
    SELECT customername,
           DATEDIFF((SELECT MAX(orderdate) FROM sales), MAX(orderdate)) AS recency,
           COUNT(DISTINCT ordernumber)                                  AS frequency,
           SUM(sales)                                                   AS monetary
    FROM sales
    GROUP BY customername
),
scored AS (
    SELECT rfm.*,
           NTILE(4) OVER (ORDER BY recency DESC, customername) AS r_score,
           NTILE(4) OVER (ORDER BY frequency,    customername) AS f_score,
           NTILE(4) OVER (ORDER BY monetary,     customername) AS m_score
    FROM rfm
)
SELECT scored.*, CONCAT(r_score, f_score, m_score) AS rfm_cell
FROM scored;
```

The customer-name tie-breaker in each `NTILE` makes scores reproducible: without it, customers with equal values can land in different quartiles from one run (or server) to the next.

### 2. Segments (`rfm_segment_map` + `customer_segments` view)

Customers are rated from **1 to 4** on each dimension (4 = best). Instead of long `CASE ... IN (...)` lists, every one of the 64 possible combinations lives in a lookup table, so no customer can end up without a segment.

| Segment | Customers | Sales | Strategy | RFM combinations |
| :--- | ---: | ---: | :--- | :--- |
| **Regular** | 40 | $6.03M | Most active, recent and high-spending. Keep them loyal with rewards and early access. | `444` `443` `442` `441` `434` `433` `432` `344` `343` `342` `341` `334` `333` `332` `331` `244` `243` `242` `241` |
| **Target** | 23 | $2.03M | Moderate activity. Main audience for pre-November campaigns; includes `113`/`114`, big past buyers who stopped returning. | `431` `424` `423` `422` `421` `414` `413` `412` `411` `324` `323` `322` `321` `314` `313` `312` `311` `234` `233` `232` `231` `224` `223` `114` `113` |
| **Inactive** | 29 | $1.97M | Lapsed buyers. Win-back incentives. | `144` `143` `142` `141` `134` `133` `132` `131` `124` `123` `122` `121` `112` `111` `214` `213` `212` `211` `222` `221` |

### 3. Data-quality checks

[`sql/04_checks.sql`](sql/04_checks.sql) runs 14 checks — every row loaded, dates parsed and consistent with the year/month columns, clean category values, all 64 cells mapped, every customer scored and segmented, balanced quartiles, and score ordering. The pipeline fails if any check is non-zero.

---

## 🚀 Strategic Recommendations

1. **Pre-November Target Marketing**: Prioritize the **"Target"** segment with tailored promotional campaigns prior to November (historically the highest-performing sales month).
2. **Win-Back Campaigns**: Analyze churning patterns among **"Inactive"** customers (specifically high monetary score cells like `144`, `143`, `134`) who made significant past purchases but have stopped returning.
3. **VIP Loyalty Programs**: Offer special perks and early product access to **"Regular"** customers (`444`, `443`, etc.) to maximize Customer Lifetime Value (CLV).

---

## 🛠️ How to Run

Requires MySQL 8+ or MariaDB 10.6+ with `local_infile` enabled.

```bash
./run.sh                                          # database "rfm" on localhost
MYSQL_OPTS="-h 127.0.0.1 -u root -p" ./run.sh     # other host or user
```

`run.sh` loads the data, runs the EDA and RFM scripts in order, then the checks. Each script can also be run on its own:

| File | What it does |
|---|---|
| `sql/01_load.sql` | Load the CSV into a typed `sales` table |
| `sql/02_eda.sql` | Exploratory queries behind the Key Findings |
| `sql/03_rfm.sql` | RFM views, segment lookup and result queries |
| `sql/04_checks.sql` | Data-quality and logic checks (all must be 0) |

GitHub Actions runs the whole pipeline against MySQL 8.4 on every push and pull request.
