-- ============================================================
-- WaitWise Healthcare Analytics — SQL EDA
-- Author  : Gayathri | Data Analyst
-- Dialect : MySQL
-- Dataset : Healthcare Patient Wait List (2018–2021)
-- ============================================================
-- SECTIONS
--   1. Database & Table Setup
--   2. Basic EDA  (row count, nulls, distinct values)
--   3. Wait List KPIs & Aggregations
--   4. Year-over-Year Comparisons
--   5. Specialty & Case Type Analysis
--   6. Time Band & Age Group Analysis
-- ============================================================


-- ============================================================
-- 1. DATABASE & TABLE SETUP
-- ============================================================

CREATE DATABASE IF NOT EXISTS waitwise_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE waitwise_db;

-- ------------------------------------------------------------
-- Main fact table
-- ------------------------------------------------------------
DROP TABLE IF EXISTS patient_waitlist;

CREATE TABLE patient_waitlist (
    id               INT             AUTO_INCREMENT PRIMARY KEY,
    archive_date     DATE            NOT NULL,
    case_type        VARCHAR(50)     NOT NULL,
    specialty_name   VARCHAR(100)    NOT NULL,
    age_profile      VARCHAR(20)     NOT NULL,
    time_bands       VARCHAR(30)     NOT NULL,
    total            INT             NOT NULL DEFAULT 0,
    specialty_group  VARCHAR(100)    DEFAULT 'Unmapped',
    year             SMALLINT        GENERATED ALWAYS AS (YEAR(archive_date)) STORED,
    month            TINYINT         GENERATED ALWAYS AS (MONTH(archive_date)) STORED,
    INDEX idx_date          (archive_date),
    INDEX idx_case_type     (case_type),
    INDEX idx_specialty     (specialty_name),
    INDEX idx_age           (age_profile),
    INDEX idx_time_bands    (time_bands),
    INDEX idx_year          (year)
);

-- ------------------------------------------------------------
-- Load cleaned CSV into the table
-- (update the file path to match your local setup)
-- ------------------------------------------------------------
LOAD DATA INFILE '/path/to/cleaned_healthcare_waitlist.csv'
INTO TABLE patient_waitlist
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(archive_date, case_type, specialty_name, age_profile,
 time_bands, total, specialty_group);


-- ============================================================
-- 2. BASIC EDA
-- ============================================================

-- ------------------------------------------------------------
-- 2.1 Total row count
-- ------------------------------------------------------------
SELECT COUNT(*) AS total_rows
FROM patient_waitlist;

-- ------------------------------------------------------------
-- 2.2 Date range
-- ------------------------------------------------------------
SELECT
    MIN(archive_date)  AS earliest_date,
    MAX(archive_date)  AS latest_date,
    DATEDIFF(MAX(archive_date), MIN(archive_date)) AS date_span_days
FROM patient_waitlist;

-- ------------------------------------------------------------
-- 2.3 Distinct values per categorical column
-- ------------------------------------------------------------
SELECT
    COUNT(DISTINCT case_type)       AS distinct_case_types,
    COUNT(DISTINCT specialty_name)  AS distinct_specialties,
    COUNT(DISTINCT age_profile)     AS distinct_age_profiles,
    COUNT(DISTINCT time_bands)      AS distinct_time_bands,
    COUNT(DISTINCT specialty_group) AS distinct_specialty_groups,
    COUNT(DISTINCT year)            AS distinct_years
FROM patient_waitlist;

-- ------------------------------------------------------------
-- 2.4 NULL / missing value check per column
-- ------------------------------------------------------------
SELECT
    SUM(archive_date    IS NULL) AS null_archive_date,
    SUM(case_type       IS NULL) AS null_case_type,
    SUM(specialty_name  IS NULL) AS null_specialty_name,
    SUM(age_profile     IS NULL) AS null_age_profile,
    SUM(time_bands      IS NULL) AS null_time_bands,
    SUM(total           IS NULL) AS null_total,
    SUM(specialty_group IS NULL) AS null_specialty_group
FROM patient_waitlist;

-- ------------------------------------------------------------
-- 2.5 Row count and patient total per year
-- ------------------------------------------------------------
SELECT
    year,
    COUNT(*)        AS row_count,
    SUM(total)      AS total_patients,
    ROUND(AVG(total), 2) AS avg_per_row
FROM patient_waitlist
GROUP BY year
ORDER BY year;

-- ------------------------------------------------------------
-- 2.6 All distinct case types
-- ------------------------------------------------------------
SELECT DISTINCT case_type
FROM patient_waitlist
ORDER BY case_type;

-- ------------------------------------------------------------
-- 2.7 All distinct time bands with row counts
-- ------------------------------------------------------------
SELECT
    time_bands,
    COUNT(*) AS row_count
FROM patient_waitlist
GROUP BY time_bands
ORDER BY row_count DESC;


-- ============================================================
-- 3. WAIT LIST KPIs & AGGREGATIONS
-- ============================================================

-- ------------------------------------------------------------
-- 3.1 Overall KPIs
-- ------------------------------------------------------------
SELECT
    SUM(total)                          AS grand_total_patients,
    ROUND(AVG(total), 2)                AS avg_per_row,
    ROUND(
        (SUM(total) / COUNT(*)), 2
    )                                   AS mean_wait_list,
    MIN(total)                          AS min_patients,
    MAX(total)                          AS max_patients
FROM patient_waitlist;

-- ------------------------------------------------------------
-- 3.2 Latest month total wait list
-- ------------------------------------------------------------
SELECT
    archive_date                        AS latest_snapshot,
    SUM(total)                          AS latest_total_wait_list
FROM patient_waitlist
WHERE archive_date = (SELECT MAX(archive_date) FROM patient_waitlist)
GROUP BY archive_date;

-- ------------------------------------------------------------
-- 3.3 Total patients by case type (all time)
-- ------------------------------------------------------------
SELECT
    case_type,
    SUM(total)                          AS total_patients,
    ROUND(SUM(total) * 100.0
        / (SELECT SUM(total) FROM patient_waitlist), 2) AS pct_share
FROM patient_waitlist
GROUP BY case_type
ORDER BY total_patients DESC;

-- ------------------------------------------------------------
-- 3.4 Monthly wait list totals
-- ------------------------------------------------------------
SELECT
    archive_date,
    SUM(total)                          AS monthly_total,
    SUM(SUM(total)) OVER (
        ORDER BY archive_date
    )                                   AS running_total
FROM patient_waitlist
GROUP BY archive_date
ORDER BY archive_date;

-- ------------------------------------------------------------
-- 3.5 Average and median wait list by case type
--     (MySQL does not have MEDIAN — using percentile approach)
-- ------------------------------------------------------------
SELECT
    case_type,
    ROUND(AVG(total), 2)                AS avg_wait_list,
    MAX(CASE WHEN pct_rank <= 0.5
             THEN total END)            AS approx_median
FROM (
    SELECT
        case_type,
        total,
        PERCENT_RANK() OVER (
            PARTITION BY case_type ORDER BY total
        ) AS pct_rank
    FROM patient_waitlist
) ranked
GROUP BY case_type
ORDER BY avg_wait_list DESC;


-- ============================================================
-- 4. YEAR-OVER-YEAR COMPARISONS
-- ============================================================

-- ------------------------------------------------------------
-- 4.1 Total wait list per year
-- ------------------------------------------------------------
SELECT
    year,
    SUM(total)                          AS total_wait_list
FROM patient_waitlist
GROUP BY year
ORDER BY year;

-- ------------------------------------------------------------
-- 4.2 YoY change in total wait list
-- ------------------------------------------------------------
SELECT
    year,
    total_wait_list,
    LAG(total_wait_list) OVER (
        ORDER BY year
    )                                   AS prev_year_total,
    total_wait_list
        - LAG(total_wait_list) OVER (ORDER BY year) AS yoy_change,
    ROUND(
        (total_wait_list
            - LAG(total_wait_list) OVER (ORDER BY year))
        * 100.0
        / NULLIF(LAG(total_wait_list) OVER (ORDER BY year), 0),
    2)                                  AS yoy_pct_change
FROM (
    SELECT year, SUM(total) AS total_wait_list
    FROM patient_waitlist
    GROUP BY year
) yearly
ORDER BY year;

-- ------------------------------------------------------------
-- 4.3 Latest month vs same month previous year
-- ------------------------------------------------------------
SELECT
    curr.archive_date                   AS current_month,
    curr.total_wait_list                AS current_total,
    prev.total_wait_list                AS prev_year_total,
    curr.total_wait_list
        - prev.total_wait_list          AS absolute_change,
    ROUND(
        (curr.total_wait_list - prev.total_wait_list)
        * 100.0
        / NULLIF(prev.total_wait_list, 0),
    2)                                  AS pct_change
FROM (
    SELECT archive_date, SUM(total) AS total_wait_list
    FROM patient_waitlist
    WHERE archive_date = (SELECT MAX(archive_date) FROM patient_waitlist)
    GROUP BY archive_date
) curr
LEFT JOIN (
    SELECT archive_date, SUM(total) AS total_wait_list
    FROM patient_waitlist
    WHERE archive_date = DATE_SUB(
        (SELECT MAX(archive_date) FROM patient_waitlist),
        INTERVAL 1 YEAR
    )
    GROUP BY archive_date
) prev ON 1 = 1;

-- ------------------------------------------------------------
-- 4.4 Monthly trend with YoY comparison (same month, all years)
-- ------------------------------------------------------------
SELECT
    month,
    year,
    SUM(total)                          AS monthly_total,
    LAG(SUM(total)) OVER (
        PARTITION BY month ORDER BY year
    )                                   AS same_month_prev_year,
    ROUND(
        (SUM(total)
            - LAG(SUM(total)) OVER (PARTITION BY month ORDER BY year))
        * 100.0
        / NULLIF(
            LAG(SUM(total)) OVER (PARTITION BY month ORDER BY year), 0),
    2)                                  AS yoy_pct_change
FROM patient_waitlist
GROUP BY month, year
ORDER BY month, year;

-- ------------------------------------------------------------
-- 4.5 YoY wait list by case type
-- ------------------------------------------------------------
SELECT
    case_type,
    year,
    SUM(total)                          AS total_wait_list,
    LAG(SUM(total)) OVER (
        PARTITION BY case_type ORDER BY year
    )                                   AS prev_year,
    ROUND(
        (SUM(total)
            - LAG(SUM(total)) OVER (PARTITION BY case_type ORDER BY year))
        * 100.0
        / NULLIF(
            LAG(SUM(total)) OVER (PARTITION BY case_type ORDER BY year), 0),
    2)                                  AS yoy_pct_change
FROM patient_waitlist
GROUP BY case_type, year
ORDER BY case_type, year;


-- ============================================================
-- 5. SPECIALTY & CASE TYPE ANALYSIS
-- ============================================================

-- ------------------------------------------------------------
-- 5.1 Top 10 specialties by total wait list (latest snapshot)
-- ------------------------------------------------------------
SELECT
    specialty_name,
    SUM(total)                          AS total_patients
FROM patient_waitlist
WHERE archive_date = (SELECT MAX(archive_date) FROM patient_waitlist)
GROUP BY specialty_name
ORDER BY total_patients DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 5.2 Top 10 specialties — all time
-- ------------------------------------------------------------
SELECT
    specialty_name,
    SUM(total)                          AS total_patients,
    ROUND(AVG(total), 2)                AS avg_per_snapshot
FROM patient_waitlist
GROUP BY specialty_name
ORDER BY total_patients DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 5.3 Wait list by specialty group
-- ------------------------------------------------------------
SELECT
    specialty_group,
    COUNT(DISTINCT specialty_name)      AS num_specialties,
    SUM(total)                          AS total_patients,
    ROUND(AVG(total), 2)                AS avg_wait_list
FROM patient_waitlist
GROUP BY specialty_group
ORDER BY total_patients DESC;

-- ------------------------------------------------------------
-- 5.4 Case type breakdown per specialty (latest snapshot)
-- ------------------------------------------------------------
SELECT
    specialty_name,
    SUM(CASE WHEN case_type = 'Outpatient' THEN total ELSE 0 END) AS outpatient,
    SUM(CASE WHEN case_type = 'Day Case'   THEN total ELSE 0 END) AS day_case,
    SUM(CASE WHEN case_type = 'Inpatient'  THEN total ELSE 0 END) AS inpatient,
    SUM(total)                                                     AS grand_total
FROM patient_waitlist
WHERE archive_date = (SELECT MAX(archive_date) FROM patient_waitlist)
GROUP BY specialty_name
ORDER BY grand_total DESC
LIMIT 20;

-- ------------------------------------------------------------
-- 5.5 Specialties with highest growth (latest vs prior year)
-- ------------------------------------------------------------
SELECT
    curr.specialty_name,
    curr.total_patients                 AS current_total,
    prev.total_patients                 AS prev_year_total,
    curr.total_patients
        - prev.total_patients           AS absolute_growth,
    ROUND(
        (curr.total_patients - prev.total_patients)
        * 100.0
        / NULLIF(prev.total_patients, 0),
    2)                                  AS pct_growth
FROM (
    SELECT specialty_name, SUM(total) AS total_patients
    FROM patient_waitlist
    WHERE year = (SELECT MAX(year) FROM patient_waitlist)
    GROUP BY specialty_name
) curr
LEFT JOIN (
    SELECT specialty_name, SUM(total) AS total_patients
    FROM patient_waitlist
    WHERE year = (SELECT MAX(year) FROM patient_waitlist) - 1
    GROUP BY specialty_name
) prev USING (specialty_name)
ORDER BY pct_growth DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 5.6 Case type share per year
-- ------------------------------------------------------------
SELECT
    year,
    case_type,
    SUM(total)                          AS total_patients,
    ROUND(
        SUM(total) * 100.0
        / SUM(SUM(total)) OVER (PARTITION BY year),
    2)                                  AS pct_of_year
FROM patient_waitlist
GROUP BY year, case_type
ORDER BY year, total_patients DESC;


-- ============================================================
-- 6. TIME BAND & AGE GROUP ANALYSIS
-- ============================================================

-- ------------------------------------------------------------
-- 6.1 Wait list by time band (latest snapshot)
-- ------------------------------------------------------------
SELECT
    time_bands,
    SUM(total)                          AS total_patients,
    ROUND(SUM(total) * 100.0
        / (SELECT SUM(total)
           FROM patient_waitlist
           WHERE archive_date = (SELECT MAX(archive_date) FROM patient_waitlist)),
    2)                                  AS pct_share
FROM patient_waitlist
WHERE archive_date = (SELECT MAX(archive_date) FROM patient_waitlist)
GROUP BY time_bands
ORDER BY
    CASE time_bands
        WHEN '0-3 Months'   THEN 1
        WHEN '3-6 Months'   THEN 2
        WHEN '6-9 Months'   THEN 3
        WHEN '9-12 Months'  THEN 4
        WHEN '12-15 Months' THEN 5
        WHEN '15-18 Months' THEN 6
        WHEN '18+ Months'   THEN 7
        ELSE 99
    END;

-- ------------------------------------------------------------
-- 6.2 Long-wait patients (18+ months) trend over time
-- ------------------------------------------------------------
SELECT
    archive_date,
    SUM(total)                          AS long_wait_patients
FROM patient_waitlist
WHERE time_bands = '18+ Months'
GROUP BY archive_date
ORDER BY archive_date;

-- ------------------------------------------------------------
-- 6.3 Wait list by age profile (latest snapshot)
-- ------------------------------------------------------------
SELECT
    age_profile,
    SUM(total)                          AS total_patients,
    ROUND(SUM(total) * 100.0
        / (SELECT SUM(total)
           FROM patient_waitlist
           WHERE archive_date = (SELECT MAX(archive_date) FROM patient_waitlist)),
    2)                                  AS pct_share
FROM patient_waitlist
WHERE archive_date = (SELECT MAX(archive_date) FROM patient_waitlist)
GROUP BY age_profile
ORDER BY total_patients DESC;

-- ------------------------------------------------------------
-- 6.4 Age profile × time band cross analysis (latest snapshot)
-- ------------------------------------------------------------
SELECT
    age_profile,
    time_bands,
    SUM(total)                          AS total_patients
FROM patient_waitlist
WHERE archive_date = (SELECT MAX(archive_date) FROM patient_waitlist)
GROUP BY age_profile, time_bands
ORDER BY
    age_profile,
    CASE time_bands
        WHEN '0-3 Months'   THEN 1
        WHEN '3-6 Months'   THEN 2
        WHEN '6-9 Months'   THEN 3
        WHEN '9-12 Months'  THEN 4
        WHEN '12-15 Months' THEN 5
        WHEN '15-18 Months' THEN 6
        WHEN '18+ Months'   THEN 7
        ELSE 99
    END;

-- ------------------------------------------------------------
-- 6.5 Elderly patients (65+) in long-wait bands
-- ------------------------------------------------------------
SELECT
    archive_date,
    time_bands,
    SUM(total)                          AS elderly_patients
FROM patient_waitlist
WHERE age_profile = '65+'
  AND time_bands IN ('12-15 Months', '15-18 Months', '18+ Months')
GROUP BY archive_date, time_bands
ORDER BY archive_date,
    CASE time_bands
        WHEN '12-15 Months' THEN 1
        WHEN '15-18 Months' THEN 2
        WHEN '18+ Months'   THEN 3
    END;

-- ------------------------------------------------------------
-- 6.6 Time band distribution per case type (latest snapshot)
-- ------------------------------------------------------------
SELECT
    case_type,
    time_bands,
    SUM(total)                          AS total_patients,
    ROUND(
        SUM(total) * 100.0
        / SUM(SUM(total)) OVER (PARTITION BY case_type),
    2)                                  AS pct_within_case_type
FROM patient_waitlist
WHERE archive_date = (SELECT MAX(archive_date) FROM patient_waitlist)
GROUP BY case_type, time_bands
ORDER BY
    case_type,
    CASE time_bands
        WHEN '0-3 Months'   THEN 1
        WHEN '3-6 Months'   THEN 2
        WHEN '6-9 Months'   THEN 3
        WHEN '9-12 Months'  THEN 4
        WHEN '12-15 Months' THEN 5
        WHEN '15-18 Months' THEN 6
        WHEN '18+ Months'   THEN 7
        ELSE 99
    END;

-- ------------------------------------------------------------
-- 6.7 Age profile trend over time
-- ------------------------------------------------------------
SELECT
    archive_date,
    age_profile,
    SUM(total)                          AS total_patients
FROM patient_waitlist
GROUP BY archive_date, age_profile
ORDER BY archive_date, total_patients DESC;

-- ============================================================
-- END OF FILE
-- ============================================================
