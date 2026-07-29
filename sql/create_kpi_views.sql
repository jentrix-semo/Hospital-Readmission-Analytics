-- ============================================================
-- create_kpi_views.sql
-- Hospital Readmission Analytics — KPI Views
-- Dataset: UCI Diabetes 130-US Hospitals (101,766 encounters)
-- All 8 views read from public.vw_encounter_base which applies
-- clinical exclusion filters:
--   expired_or_hospice_flag = 0 (cannot be readmitted)
--   gender_invalid_flag     = 0 (unusable demographic)
-- Valid analysis population: 99,340 encounters
-- Baseline 30-day readmission rate: 11.39%
-- Power BI connects to these views via DirectQuery
-- Run after create_base_view.sql
-- ============================================================


-- ============================================================
-- KPI VIEW 1: vw_kpi_overall_readmission
-- Answers Q1: What is the overall 30-day readmission rate?
--
-- Purpose:
-- Headline KPI — the single row of summary metrics that
-- appears as card visuals on the Power BI executive summary
-- page. Every other KPI view is compared against the
-- rate_30day_pct value returned here (11.39%).
--
-- Returns: 1 row
-- Key metric: rate_30day_pct
-- Power BI visual: Card visuals for each metric
-- ============================================================

CREATE OR REPLACE VIEW public.vw_kpi_overall_readmission AS
SELECT
    COUNT(*)                                                AS total_encounters,
    SUM(led_to_30day_readmission)                           AS readmitted_30day,
    SUM(led_to_any_readmission)                             AS readmitted_any,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                    AS rate_30day_pct,
    ROUND(SUM(led_to_any_readmission) * 100.0
          / COUNT(*), 2)                                    AS rate_any_pct,
    COUNT(DISTINCT patient_nbr)                             AS unique_patients,
    ROUND(AVG(time_in_hospital), 2)                         AS avg_los_days,
    ROUND(AVG(num_medications), 2)                          AS avg_medications
FROM public.vw_encounter_base;


-- ============================================================
-- KPI VIEW 2: vw_kpi_readmission_by_diagnosis
-- Answers Q3: Which diagnosis categories drive readmissions?
--
-- Purpose:
-- Maps ICD-9 primary diagnosis codes (diag_1) to 11 clinical
-- categories using standard ICD-9 numeric ranges and regex
-- pattern matching. Computes readmission rate and average
-- length of stay per category.
--
-- Technical note:
-- The regex guard (diag_1 ~ '^\d+\.?\d*$') runs BEFORE the
-- CAST to NUMERIC in each WHEN clause. This prevents a query
-- failure when diag_1 contains V-codes (e.g. V45.81),
-- E-codes (e.g. E11.9), or the string "None" — none of which
-- can be cast to NUMERIC. Without the guard the query throws
-- an invalid input error on the first non-numeric code it
-- encounters.
--
-- EDA finding confirmed: V-codes (16.24%) and Diabetes
-- (13.10%) show highest rates above the 11.39% baseline.
-- Circulatory (29,584 encounters) produces the most absolute
-- readmissions despite a moderate rate of 11.69%.
--
-- Returns: 1 row per diagnosis category (12 categories)
-- Key metric: readmission_rate_pct
-- Power BI visual: Horizontal bar chart sorted by rate
-- ============================================================

CREATE OR REPLACE VIEW public.vw_kpi_readmission_by_diagnosis AS
SELECT
    CASE
        WHEN diag_1 ~ '^[Vv]'                              THEN 'Supplementary (V-codes)'
        WHEN diag_1 ~ '^[Ee]'                              THEN 'External Causes (E-codes)'
        WHEN diag_1 = 'None'                               THEN 'No Primary Diagnosis'
        WHEN diag_1 ~ '^\d+\.?\d*$'
             AND diag_1::NUMERIC BETWEEN 390  AND 459      THEN 'Circulatory'
        WHEN diag_1 ~ '^\d+\.?\d*$'
             AND diag_1::NUMERIC BETWEEN 460  AND 519      THEN 'Respiratory'
        WHEN diag_1 ~ '^\d+\.?\d*$'
             AND diag_1::NUMERIC BETWEEN 520  AND 579      THEN 'Digestive'
        WHEN diag_1 ~ '^\d+\.?\d*$'
             AND diag_1::NUMERIC BETWEEN 250  AND 250.99   THEN 'Diabetes'
        WHEN diag_1 ~ '^\d+\.?\d*$'
             AND diag_1::NUMERIC BETWEEN 800  AND 999      THEN 'Injury & Poisoning'
        WHEN diag_1 ~ '^\d+\.?\d*$'
             AND diag_1::NUMERIC BETWEEN 710  AND 739      THEN 'Musculoskeletal'
        WHEN diag_1 ~ '^\d+\.?\d*$'
             AND diag_1::NUMERIC BETWEEN 580  AND 629      THEN 'Genitourinary'
        WHEN diag_1 ~ '^\d+\.?\d*$'
             AND diag_1::NUMERIC BETWEEN 140  AND 239      THEN 'Neoplasms'
        WHEN diag_1 ~ '^\d+\.?\d*$'
             AND diag_1::NUMERIC BETWEEN 290  AND 319      THEN 'Mental Disorders'
        ELSE 'Other'
    END                                                     AS diagnosis_category,
    COUNT(*)                                                AS total_encounters,
    SUM(led_to_30day_readmission)                           AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                    AS readmission_rate_pct,
    ROUND(AVG(time_in_hospital), 2)                         AS avg_los_days,
    ROUND(AVG(num_medications), 2)                          AS avg_medications
FROM public.vw_encounter_base
GROUP BY diagnosis_category
ORDER BY readmission_rate_pct DESC;


-- ============================================================
-- KPI VIEW 3: vw_kpi_readmission_by_disposition
-- Answers Q8: Which discharge disposition carries highest risk?
--
-- Purpose:
-- Maps discharge_disposition_id lookup codes to descriptive
-- labels using the IDs_mapping.csv reference. Computes
-- readmission rate and average LOS per disposition.
--
-- Clinical context:
-- Discharge disposition determines where the patient goes
-- after leaving hospital — home, skilled nursing facility,
-- rehabilitation, etc. The destination affects post-discharge
-- support and monitoring availability, which directly
-- influences readmission risk.
--
-- Note: Disposition codes 11,13,14,19,20,21 (expired/hospice)
-- are already excluded by vw_encounter_base filters so they
-- do not appear in this view. All rows represent patients
-- who were discharged to a recoverable setting.
--
-- EDA finding: Left Against Medical Advice (AMA) patients
-- are expected to show elevated readmission rates as they
-- leave without completing treatment or discharge planning.
--
-- Returns: 1 row per discharge disposition code
-- Key metric: readmission_rate_pct
-- Power BI visual: Bar chart or ranked table
-- ============================================================

DROP VIEW IF EXISTS public.vw_kpi_readmission_by_disposition;

CREATE VIEW public.vw_kpi_readmission_by_disposition AS
SELECT
    discharge_disposition_id,
    CASE discharge_disposition_id
        WHEN '1'  THEN 'Discharged to Home'
        WHEN '2'  THEN 'Short-Term Hospital'
        WHEN '3'  THEN 'Skilled Nursing Facility'
        WHEN '4'  THEN 'Another Inpatient Institution'
        WHEN '5'  THEN 'Another Type of Institution'
        WHEN '6'  THEN 'Home with Health Service'
        WHEN '7'  THEN 'Left Against Medical Advice'
        WHEN '9'  THEN 'Admitted as Inpatient'
        WHEN '15' THEN 'Swing Bed'
        WHEN '17' THEN 'Other Institution'
        WHEN '18' THEN 'Another Type of Health Care'
        WHEN '22' THEN 'Rehabilitation Facility'
        WHEN '23' THEN 'Long-Term Care Hospital'
        WHEN '25' THEN 'Psychiatric Hospital'
        WHEN '28' THEN 'Psychiatric Transfer'
        ELSE           'Other'
    END                                                     AS disposition_label,
    COUNT(*)                                                AS total_encounters,
    SUM(led_to_30day_readmission)                           AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                    AS readmission_rate_pct,
    ROUND(AVG(time_in_hospital), 2)                         AS avg_los_days
FROM public.vw_encounter_base
GROUP BY discharge_disposition_id
HAVING COUNT(*) >= 200
ORDER BY readmission_rate_pct DESC;

--Veifying 

SELECT disposition_label, total_encounters, readmission_rate_pct
FROM public.vw_kpi_readmission_by_disposition
ORDER BY readmission_rate_pct DESC;


-- ============================================================
-- KPI VIEW 4: vw_kpi_los_by_readmission
-- Answers Q7: Does length of stay correlate with readmission?
--
-- Purpose:
-- Compares clinical utilization metrics across the three
-- readmission outcome groups — readmitted <30 days,
-- readmitted >30 days, and not readmitted. Uses both
-- average and median LOS to capture the full distribution
-- given the right skew (skew = 1.13) confirmed in profiling.
--
-- Statistical context:
-- Mann-Whitney U Test 3 confirmed (U = 545,465,728,
-- p effectively = 0) that LOS distributions differ
-- significantly between readmitted and not readmitted
-- patients despite sharing an identical median of 4.00 days.
-- The significant difference exists in the upper tail —
-- readmitted patients are disproportionately represented
-- among the longest-stay encounters. Including both
-- avg_los_days and median_los_days in this view exposes
-- this tail difference to Power BI users.
--
-- PERCENTILE_CONT(0.5) computes the true median — more
-- appropriate than AVG for right-skewed distributions.
--
-- Returns: 3 rows (one per readmission outcome group)
-- Key metrics: avg_los_days, median_los_days
-- Power BI visual: Grouped bar — avg vs median LOS
-- ============================================================

CREATE OR REPLACE VIEW public.vw_kpi_los_by_readmission AS
SELECT
    CASE
        WHEN readmitted = '<30' THEN '1 — Readmitted <30 Days'
        WHEN readmitted = '>30' THEN '2 — Readmitted >30 Days'
        ELSE                         '3 — Not Readmitted'
    END                                                     AS readmission_status,
    COUNT(*)                                                AS encounters,
    ROUND(AVG(time_in_hospital), 2)                         AS avg_los_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP
        (ORDER BY time_in_hospital)                         AS median_los_days,
    MIN(time_in_hospital)                                   AS min_los,
    MAX(time_in_hospital)                                   AS max_los,
    ROUND(AVG(num_medications), 2)                          AS avg_medications,
    ROUND(AVG(num_active_medications), 2)                   AS avg_active_medications,
    ROUND(AVG(number_diagnoses), 2)                         AS avg_diagnoses,
    ROUND(AVG(total_prior_visits), 2)                       AS avg_prior_visits
FROM public.vw_encounter_base
GROUP BY readmission_status
ORDER BY readmission_status;


-- ============================================================
-- KPI VIEW 5: vw_kpi_readmission_by_age
-- Answers Q2: Which age groups carry highest readmission risk?
-- Answers Q6: Do prior inpatient visits predict readmission?
--
-- Purpose:
-- Two-dimensional KPI combining age band with prior inpatient
-- visit tier. Creates a matrix that Power BI can display as
-- a cross-tab showing how age and prior utilization interact
-- to determine readmission risk.
--
-- EDA finding confirmed: Non-linear U-shape pattern where
-- [20-30) (14.31%) and [80-90) (12.57%) show above-baseline
-- rates while [50-60) (9.77%) shows the lowest adult rate.
-- Prior inpatient visits escalate risk monotonically within
-- each age band.
--
-- Technical note:
-- age_midpoint is double precision (float) — requires
-- explicit cast to NUMERIC before ROUND with decimal places:
-- ROUND(AVG(age_midpoint)::NUMERIC, 1)
-- Without the cast PostgreSQL throws:
-- ERROR: function round(double precision, integer) does not exist
--
-- Returns: 1 row per age band x prior inpatient band combination
-- Key metric: readmission_rate_pct
-- Power BI visual: Matrix — age rows x prior inpatient columns
-- ============================================================

CREATE OR REPLACE VIEW public.vw_kpi_readmission_by_age AS
SELECT
    age,
    CASE
        WHEN number_inpatient = 0 THEN 'No Prior Inpatient'
        WHEN number_inpatient = 1 THEN '1 Prior Inpatient'
        WHEN number_inpatient = 2 THEN '2 Prior Inpatient'
        ELSE                          '3+ Prior Inpatient'
    END                                                     AS prior_inpatient_band,
    COUNT(*)                                                AS encounters,
    SUM(led_to_30day_readmission)                           AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                    AS readmission_rate_pct,
    ROUND(AVG(age_midpoint)::NUMERIC, 1)                    AS avg_age
FROM public.vw_encounter_base
GROUP BY age, prior_inpatient_band
ORDER BY age, prior_inpatient_band;


-- ============================================================
-- KPI VIEW 6: vw_kpi_readmission_by_specialty
-- Answers Q4: Which clinical departments have highest rates?
--
-- Purpose:
-- Computes readmission rate, average LOS, and average
-- medications per medical specialty. Restricted to specialties
-- with >= 50 encounters to ensure statistically reliable rates
-- — a specialty with 3 encounters and 1 readmission would
-- show 33.33% which is misleading due to small sample size.
-- Unknown specialty excluded — recorded for only ~51% of
-- encounters and cannot be analytically assigned.
--
-- EDA finding confirmed: Nephrology (16.11%) shows the
-- highest rate — clinically expected because Nephrology
-- patients have concurrent diabetes and kidney disease,
-- the highest-risk comorbidity combination in this dataset.
-- Internal Medicine (14,237 encounters) produces the most
-- absolute readmissions despite a near-baseline rate (11.53%).
--
-- HAVING COUNT(*) >= 50 is applied after GROUP BY to exclude
-- low-volume specialties from the KPI view. This threshold
-- ensures every rate shown in Power BI is based on a
-- meaningful sample size.
--
-- Returns: 1 row per qualifying specialty
-- Key metrics: readmission_rate_pct, avg_los_days
-- Power BI visual: Ranked bar chart (top 15 by volume)
-- Drill-through target: from executive summary specialty bar
-- ============================================================

CREATE OR REPLACE VIEW public.vw_kpi_readmission_by_specialty AS
SELECT
    medical_specialty,
    COUNT(*)                                                AS total_encounters,
    SUM(led_to_30day_readmission)                           AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                    AS readmission_rate_pct,
    ROUND(AVG(time_in_hospital), 2)                         AS avg_los_days,
    ROUND(AVG(num_medications), 2)                          AS avg_medications,
    ROUND(AVG(num_active_medications), 2)                   AS avg_active_medications
FROM public.vw_encounter_base
WHERE medical_specialty != 'Unknown'
GROUP BY medical_specialty
HAVING COUNT(*) >= 50
ORDER BY readmission_rate_pct DESC;


-- ============================================================
-- KPI VIEW 7: vw_kpi_high_risk_segments
-- Answers Q10: What is the profile of the highest-risk patient?
--
-- Purpose:
-- Stratifies all valid encounters into three risk tiers
-- using clinically grounded thresholds combining prior
-- inpatient visits, length of stay, and medication count:
--
-- High Risk    : number_inpatient >= 2
--                AND time_in_hospital >= 7
--                AND num_medications  >= 15
-- Moderate Risk: number_inpatient >= 1
--                AND time_in_hospital >= 4
-- Low Risk     : all remaining encounters
--
-- Threshold rationale:
-- number_inpatient >= 2 : above the Q3 of 1 — upper quartile
--   prior inpatient utilization confirmed as readmission
--   predictor by Mann-Whitney U Test 4 (p effectively = 0)
-- time_in_hospital >= 7 : above the IQR upper bound of 6 —
--   long-stay patients confirmed in the upper tail by
--   Mann-Whitney U Test 3 (p effectively = 0)
-- num_medications >= 15 : above the Q3 of 20 — high
--   medication burden; polypharmacy confirmed significant
--   by chi-square Test 2 (chi-sq = 143.67, p effectively = 0)
--
-- Uses a CTE (WITH risk_classified AS) to classify each
-- encounter into a risk tier before aggregating — separating
-- the classification logic from the aggregation logic makes
-- the query readable and maintainable.
--
-- EDA finding: This view is expected to show the High Risk
-- tier with a readmission rate well above the 11.39% baseline
-- confirming that the three-variable threshold combination
-- identifies a genuinely elevated-risk patient segment.
--
-- Returns: 3 rows (High Risk, Moderate Risk, Low Risk)
-- Key metrics: readmission_rate_pct, polypharmacy_pct
-- Power BI visual: Clustered bar — rate + volume side by side
-- Drill-through target: from executive summary risk card
-- ============================================================

CREATE OR REPLACE VIEW public.vw_kpi_high_risk_segments AS
WITH risk_classified AS (
    SELECT
        *,
        CASE
            WHEN number_inpatient >= 2
             AND time_in_hospital >= 7
             AND num_medications  >= 15 THEN '1 — High Risk'
            WHEN number_inpatient >= 1
             AND time_in_hospital >= 4  THEN '2 — Moderate Risk'
            ELSE                             '3 — Low Risk'
        END AS risk_tier
    FROM public.vw_encounter_base
)
SELECT
    risk_tier,
    COUNT(*)                                                AS total_encounters,
    COUNT(DISTINCT patient_nbr)                             AS unique_patients,
    SUM(led_to_30day_readmission)                           AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                    AS readmission_rate_pct,
    ROUND(AVG(time_in_hospital), 2)                         AS avg_los_days,
    ROUND(AVG(num_medications), 2)                          AS avg_medications,
    ROUND(AVG(num_active_medications), 2)                   AS avg_active_medications,
    ROUND(AVG(number_inpatient), 2)                         AS avg_prior_inpatient,
    ROUND(AVG(total_prior_visits), 2)                       AS avg_total_prior_visits,
    SUM(polypharmacy_flag)                                  AS polypharmacy_count,
    ROUND(SUM(polypharmacy_flag) * 100.0 / COUNT(*), 2)    AS polypharmacy_pct
FROM risk_classified
GROUP BY risk_tier
ORDER BY risk_tier;


-- ============================================================
-- KPI VIEW 8: vw_kpi_repeat_patient_readmission
-- Answers Q9: Do repeat patients have higher readmission rates?
--
-- Purpose:
-- Compares readmission rates, average LOS, prior visits, and
-- medication counts between repeat patients (more than one
-- encounter on record) and first-time patients (single
-- encounter only). Derived from is_repeat_patient flag
-- computed by COUNT(*) OVER (PARTITION BY patient_nbr) > 1
-- in vw_encounter_base.
--
-- Statistical validation:
-- Chi-square Test 1 confirmed (chi-sq = 5,866.86,
-- p effectively = 0) that the difference between repeat
-- (19.76%) and first-time (4.26%) patient readmission rates
-- is statistically significant and cannot be explained by
-- random chance. This is the strongest finding in the
-- entire project.
--
-- Clinical context:
-- 16,773 unique patients have more than one encounter.
-- Repeat patient encounters generate 73% of all 30-day
-- readmissions despite representing only 46% of encounters
-- — a profound disproportionality that defines the
-- readmission problem in this dataset.
--
-- The 1st to 2nd encounter transition is the highest-
-- leverage intervention point: readmission rate jumps
-- from 8.98% (1st encounter) to 14.16% (2nd encounter)
-- — a 5.18 percentage point increase identified in the
-- encounter sequence EDA (Section 7a).
--
-- Returns: 2 rows (Repeat Patient, First-Time Patient)
-- Key metric: readmission_rate_pct
-- Power BI visual: Side-by-side comparison cards
-- Drill-through target: from executive summary patient card
-- ============================================================

CREATE OR REPLACE VIEW public.vw_kpi_repeat_patient_readmission AS
SELECT
    CASE WHEN is_repeat_patient = 1 THEN 'Repeat Patient'
         ELSE 'First-Time Patient'  END                     AS patient_type,
    COUNT(*)                                                AS total_encounters,
    COUNT(DISTINCT patient_nbr)                             AS unique_patients,
    SUM(led_to_30day_readmission)                           AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                    AS readmission_rate_pct,
    ROUND(AVG(time_in_hospital), 2)                         AS avg_los_days,
    ROUND(AVG(total_prior_visits), 2)                       AS avg_prior_visits,
    ROUND(AVG(num_medications), 2)                          AS avg_medications
FROM public.vw_encounter_base
GROUP BY patient_type
ORDER BY readmission_rate_pct DESC;


-- ============================================================
-- VERIFICATION
-- Run after all 8 views are created to confirm they exist
-- and return data. Expected: 8 rows with non-zero row counts
-- ============================================================
SELECT 'vw_kpi_overall_readmission'         AS view_name, COUNT(*) AS rows
FROM public.vw_kpi_overall_readmission
UNION ALL
SELECT 'vw_kpi_readmission_by_diagnosis',   COUNT(*) FROM public.vw_kpi_readmission_by_diagnosis
UNION ALL
SELECT 'vw_kpi_readmission_by_disposition', COUNT(*) FROM public.vw_kpi_readmission_by_disposition
UNION ALL
SELECT 'vw_kpi_los_by_readmission',         COUNT(*) FROM public.vw_kpi_los_by_readmission
UNION ALL
SELECT 'vw_kpi_readmission_by_age',         COUNT(*) FROM public.vw_kpi_readmission_by_age
UNION ALL
SELECT 'vw_kpi_readmission_by_specialty',   COUNT(*) FROM public.vw_kpi_readmission_by_specialty
UNION ALL
SELECT 'vw_kpi_high_risk_segments',         COUNT(*) FROM public.vw_kpi_high_risk_segments
UNION ALL
SELECT 'vw_kpi_repeat_patient_readmission', COUNT(*) FROM public.vw_kpi_repeat_patient_readmission;