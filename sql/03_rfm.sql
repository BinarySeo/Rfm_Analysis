-- =============================================================================
-- 03_rfm.sql — RFM scoring and customer segments
--
-- Builds:
--   rfm_segment_map    lookup of all 64 R-F-M score combinations → segment
--   customer_rfm       view: one row per customer with R, F, M values and 1–4 scores
--   customer_segments  view: customer_rfm joined to its segment
-- Views always reflect the current `sales` table; safe to re-run.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Segment lookup table
-- Replaces the long CASE ... IN (...) lists. Every one of the 4×4×4 = 64 score
-- combinations has exactly one row (enforced by the primary key and checked in
-- 04_checks.sql), so no customer can fall through with a NULL segment.
--   Regular  — recent, frequent, high-spending: keep loyal (rewards, early access)
--   Target   — mid recency/activity: pre-November campaign audience
--   Inactive — lapsed buyers: win-back offers
-- 113, 114 → Target: big past purchases but not returning (see original notes).
-- 231      → Target, consistent with 232 / 233 / 234.
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS rfm_segment_map;
CREATE TABLE rfm_segment_map (
    rfm_cell  CHAR(3)     NOT NULL PRIMARY KEY,
    segment   VARCHAR(10) NOT NULL
);

INSERT INTO rfm_segment_map (rfm_cell, segment) VALUES
    -- Regular
    ('444','Regular'),('443','Regular'),('442','Regular'),('441','Regular'),
    ('434','Regular'),('433','Regular'),('432','Regular'),
    ('344','Regular'),('343','Regular'),('342','Regular'),('341','Regular'),
    ('334','Regular'),('333','Regular'),('332','Regular'),('331','Regular'),
    ('244','Regular'),('243','Regular'),('242','Regular'),('241','Regular'),
    -- Target
    ('431','Target'),('424','Target'),('423','Target'),('422','Target'),('421','Target'),
    ('414','Target'),('413','Target'),('412','Target'),('411','Target'),
    ('324','Target'),('323','Target'),('322','Target'),('321','Target'),
    ('314','Target'),('313','Target'),('312','Target'),('311','Target'),
    ('234','Target'),('233','Target'),('232','Target'),('231','Target'),
    ('224','Target'),('223','Target'),
    ('114','Target'),('113','Target'),
    -- Inactive
    ('144','Inactive'),('143','Inactive'),('142','Inactive'),('141','Inactive'),
    ('134','Inactive'),('133','Inactive'),('132','Inactive'),('131','Inactive'),
    ('124','Inactive'),('123','Inactive'),('122','Inactive'),('121','Inactive'),
    ('112','Inactive'),('111','Inactive'),
    ('214','Inactive'),('213','Inactive'),('212','Inactive'),('211','Inactive'),
    ('222','Inactive'),('221','Inactive');

-- -----------------------------------------------------------------------------
-- RFM values and quartile scores (4 = best)
--   recency   = days between the customer's last order and the last order in the data
--   frequency = number of distinct orders (not order lines)
--   monetary  = total sales
-- NTILE ties are broken by customer name so scores are identical on every run and
-- every server; without it, customers with equal values could swap quartiles.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW customer_rfm AS
WITH rfm AS (
    SELECT
        customername,
        DATEDIFF((SELECT MAX(orderdate) FROM sales), MAX(orderdate)) AS recency,
        COUNT(DISTINCT ordernumber)                                  AS frequency,
        SUM(sales)                                                   AS monetary,
        SUM(sales) / COUNT(DISTINCT ordernumber)                     AS avg_order_value,
        MAX(orderdate)                                               AS last_order_date
    FROM sales
    GROUP BY customername
),
scored AS (
    SELECT
        rfm.*,
        NTILE(4) OVER (ORDER BY recency DESC, customername) AS r_score,  -- most recent → 4
        NTILE(4) OVER (ORDER BY frequency,    customername) AS f_score,  -- most orders → 4
        NTILE(4) OVER (ORDER BY monetary,     customername) AS m_score   -- highest spend → 4
    FROM rfm
)
SELECT
    scored.*,
    r_score + f_score + m_score            AS rfm_total,
    CONCAT(r_score, f_score, m_score)      AS rfm_cell
FROM scored;

CREATE OR REPLACE VIEW customer_segments AS
SELECT c.*, m.segment
FROM customer_rfm c
JOIN rfm_segment_map m ON m.rfm_cell = c.rfm_cell;

-- -----------------------------------------------------------------------------
-- Results
-- -----------------------------------------------------------------------------
-- Segment sizes and value
SELECT segment,
       COUNT(*)                 AS customers,
       ROUND(SUM(monetary), 2)  AS total_sales,
       ROUND(AVG(recency))      AS avg_days_since_last_order,
       ROUND(AVG(frequency), 1) AS avg_orders
FROM customer_segments
GROUP BY segment
ORDER BY total_sales DESC;

-- Win-back list: inactive customers who spent the most
SELECT customername, rfm_cell, recency, frequency, ROUND(monetary, 2) AS monetary
FROM customer_segments
WHERE segment = 'Inactive'
ORDER BY monetary DESC
LIMIT 10;

-- Full customer list
SELECT customername, recency, frequency, ROUND(monetary, 2) AS monetary,
       r_score, f_score, m_score, rfm_cell, segment
FROM customer_segments
ORDER BY segment, rfm_total DESC, customername;
