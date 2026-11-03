-- =============================================================================
-- 01_load.sql — load sales_data_sample.csv into a typed `sales` table
--
-- Run from the repository root (LOAD DATA LOCAL reads the CSV relative to the
-- client's working directory). Safe to re-run: every table is rebuilt.
-- Requires local_infile enabled on the server and the client (mysql --local-infile=1).
-- =============================================================================

-- 1. Raw staging table: every column as text, exactly as in the CSV
DROP TABLE IF EXISTS sales_raw;
CREATE TABLE sales_raw (
    ORDERNUMBER       VARCHAR(20),
    QUANTITYORDERED   VARCHAR(20),
    PRICEEACH         VARCHAR(20),
    ORDERLINENUMBER   VARCHAR(20),
    SALES             VARCHAR(20),
    ORDERDATE         VARCHAR(30),
    STATUS            VARCHAR(20),
    QTR_ID            VARCHAR(5),
    MONTH_ID          VARCHAR(5),
    YEAR_ID           VARCHAR(5),
    PRODUCTLINE       VARCHAR(30),
    MSRP              VARCHAR(20),
    PRODUCTCODE       VARCHAR(20),
    CUSTOMERNAME      VARCHAR(60),
    PHONE             VARCHAR(30),
    ADDRESSLINE1      VARCHAR(80),
    ADDRESSLINE2      VARCHAR(80),
    CITY              VARCHAR(40),
    STATE             VARCHAR(40),
    POSTALCODE        VARCHAR(20),
    COUNTRY           VARCHAR(30),
    TERRITORY         VARCHAR(10),
    CONTACTLASTNAME   VARCHAR(40),
    CONTACTFIRSTNAME  VARCHAR(40),
    DEALSIZE          VARCHAR(10)
);

LOAD DATA LOCAL INFILE 'sales_data_sample.csv'
INTO TABLE sales_raw
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'   -- names like "Men 'R' US Retailers, Ltd." contain commas
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- 2. Typed table used by the analysis.
--    The original date text ('2/24/03') is kept as order_date_raw and parsed into a real
--    DATE once here, instead of overwriting the column in place with UPDATE (which
--    breaks if the script is run twice).
DROP TABLE IF EXISTS sales;
CREATE TABLE sales (
    ordernumber      INT            NOT NULL,
    orderlinenumber  INT            NOT NULL,
    quantityordered  INT            NOT NULL,
    priceeach        DECIMAL(10,2)  NOT NULL,
    sales            DECIMAL(12,2)  NOT NULL,
    orderdate        DATE           NOT NULL,
    order_date_raw   VARCHAR(30)    NOT NULL,
    status           VARCHAR(20)    NOT NULL,
    qtr_id           TINYINT        NOT NULL,
    month_id         TINYINT        NOT NULL,
    year_id          SMALLINT       NOT NULL,
    productline      VARCHAR(30)    NOT NULL,
    msrp             INT            NOT NULL,
    productcode      VARCHAR(20)    NOT NULL,
    customername     VARCHAR(60)    NOT NULL,
    country          VARCHAR(30)    NOT NULL,
    territory        VARCHAR(10)    NOT NULL,   -- 'NA' means North America, not missing
    dealsize         VARCHAR(10)    NOT NULL,
    PRIMARY KEY (ordernumber, orderlinenumber),
    KEY idx_customer (customername),
    KEY idx_orderdate (orderdate)
);

INSERT INTO sales
SELECT
    CAST(ORDERNUMBER     AS UNSIGNED),
    CAST(ORDERLINENUMBER AS UNSIGNED),
    CAST(QUANTITYORDERED AS UNSIGNED),
    CAST(PRICEEACH       AS DECIMAL(10,2)),
    CAST(SALES           AS DECIMAL(12,2)),
    STR_TO_DATE(ORDERDATE, '%m/%d/%y'),
    ORDERDATE,
    STATUS,
    CAST(QTR_ID   AS UNSIGNED),
    CAST(MONTH_ID AS UNSIGNED),
    CAST(YEAR_ID  AS UNSIGNED),
    PRODUCTLINE,
    CAST(MSRP AS UNSIGNED),
    PRODUCTCODE,
    TRIM(CUSTOMERNAME),
    COUNTRY,
    TERRITORY,
    TRIM(REPLACE(DEALSIZE, '\r', ''))   -- the CSV uses Windows line endings; without this most
                                        -- rows keep a trailing \r and split into two "Medium" groups
FROM sales_raw;
-- NOT NULL on orderdate makes the load fail loudly if any date can't be parsed.
