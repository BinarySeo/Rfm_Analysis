-- =============================================================================
-- 04_checks.sql — data quality and logic checks
-- Returns one row per check with the number of failures; every value must be 0.
-- run.sh (and CI) fails the build if any check is non-zero.
-- =============================================================================

SELECT check_name, failures FROM (

    -- Load: every CSV row arrived and every date parsed into the expected years
    SELECT 'rows_loaded_match_csv'            AS check_name,
           ABS((SELECT COUNT(*) FROM sales) - (SELECT COUNT(*) FROM sales_raw)) AS failures
    UNION ALL
    SELECT 'orderdate_parsed_in_2003_2005',
           (SELECT COUNT(*) FROM sales WHERE YEAR(orderdate) NOT BETWEEN 2003 AND 2005)
    UNION ALL
    SELECT 'orderdate_matches_year_month_cols',
           (SELECT COUNT(*) FROM sales WHERE YEAR(orderdate) <> year_id OR MONTH(orderdate) <> month_id)
    UNION ALL
    SELECT 'dealsize_values_clean',
           (SELECT COUNT(*) FROM sales WHERE dealsize NOT IN ('Small', 'Medium', 'Large'))
    UNION ALL
    SELECT 'text_fields_have_no_stray_whitespace',
           (SELECT COUNT(*) FROM sales
             WHERE customername <> TRIM(customername) OR productline <> TRIM(productline)
                OR status <> TRIM(status) OR country <> TRIM(country) OR territory <> TRIM(territory))
    UNION ALL
    SELECT 'no_negative_or_zero_sales',
           (SELECT COUNT(*) FROM sales WHERE sales <= 0 OR quantityordered <= 0)

    -- Segment map: all 64 combinations, each mapped once, to a known segment
    UNION ALL
    SELECT 'segment_map_has_64_cells',
           ABS(64 - (SELECT COUNT(*) FROM rfm_segment_map))
    UNION ALL
    SELECT 'segment_map_cells_valid',
           (SELECT COUNT(*) FROM rfm_segment_map WHERE rfm_cell NOT REGEXP '^[1-4]{3}$')
    UNION ALL
    SELECT 'segment_names_valid',
           (SELECT COUNT(*) FROM rfm_segment_map WHERE segment NOT IN ('Regular', 'Target', 'Inactive'))

    -- RFM: every customer scored and segmented
    UNION ALL
    SELECT 'every_customer_scored',
           ABS((SELECT COUNT(DISTINCT customername) FROM sales) - (SELECT COUNT(*) FROM customer_rfm))
    UNION ALL
    SELECT 'every_customer_has_segment',
           ABS((SELECT COUNT(*) FROM customer_rfm) - (SELECT COUNT(*) FROM customer_segments))
    UNION ALL
    SELECT 'scores_between_1_and_4',
           (SELECT COUNT(*) FROM customer_rfm
             WHERE r_score NOT BETWEEN 1 AND 4 OR f_score NOT BETWEEN 1 AND 4 OR m_score NOT BETWEEN 1 AND 4)
    UNION ALL
    -- Quartiles are balanced (NTILE gives group sizes that differ by at most 1)
    SELECT 'recency_quartiles_balanced',
           (SELECT CASE WHEN MAX(n) - MIN(n) > 1 THEN 1 ELSE 0 END
              FROM (SELECT r_score, COUNT(*) AS n FROM customer_rfm GROUP BY r_score) q)
    UNION ALL
    -- Higher recency score must never mean an older last order
    SELECT 'recency_score_ordering',
           (SELECT COUNT(*) FROM customer_rfm a JOIN customer_rfm b
              ON a.r_score > b.r_score AND a.recency > b.recency)
) checks;
