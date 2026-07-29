-- ============================================================
-- eda_queries.sql
-- Exploratory Data Analysis queries for hospital readmission
-- All queries read from public.vw_encounter_base
-- Run after create_base_view.sql
-- ============================================================


-- ============================================================
-- SECTION 1: TARGET VARIABLE DISTRIBUTION
-- Q1: What is the overall 30-day readmission rate?
-- ============================================================

SELECT
    readmitted,
    COUNT(*)                                             AS encounters,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)  AS pct_of_total
FROM public.vw_encounter_base
GROUP BY readmitted
ORDER BY encounters DESC;


-- ============================================================
-- SECTION 2: DEMOGRAPHIC EDA
-- Q2: Which demographics carry the highest readmission risk?
-- ============================================================

-- By age band
SELECT
    age,
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct
FROM public.vw_encounter_base
GROUP BY age
ORDER BY age;

-- By gender
SELECT
    gender,
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct
FROM public.vw_encounter_base
GROUP BY gender
ORDER BY readmission_rate_pct DESC;

-- By race
SELECT
    race,
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct
FROM public.vw_encounter_base
WHERE race != 'Unknown'
GROUP BY race
ORDER BY readmission_rate_pct DESC;


-- ============================================================
-- SECTION 3: CLINICAL UTILIZATION EDA
-- Q7: Does length of stay or polypharmacy correlate with
--     readmission?
-- ============================================================

-- Average utilization by readmission outcome
SELECT
    CASE
        WHEN readmitted = '<30' THEN '1 — Readmitted <30 Days'
        WHEN readmitted = '>30' THEN '2 — Readmitted >30 Days'
        ELSE                         '3 — Not Readmitted'
    END                                                         AS readmission_outcome,
    COUNT(*)                                                    AS encounters,
    ROUND(AVG(time_in_hospital), 2)                             AS avg_los_days,
    ROUND(AVG(num_medications), 2)                              AS avg_medications,
    ROUND(AVG(num_active_medications), 2)                       AS avg_active_medications,
    ROUND(AVG(num_lab_procedures), 2)                           AS avg_lab_procedures,
    ROUND(AVG(number_diagnoses), 2)                             AS avg_diagnoses,
    ROUND(AVG(total_prior_visits), 2)                           AS avg_prior_visits,
    ROUND(SUM(polypharmacy_flag) * 100.0 / COUNT(*), 2)        AS polypharmacy_pct
FROM public.vw_encounter_base
GROUP BY readmission_outcome
ORDER BY readmission_outcome;

-- Length of stay distribution
SELECT
    CASE
        WHEN time_in_hospital <= 2  THEN '1 — 1-2 days'
        WHEN time_in_hospital <= 5  THEN '2 — 3-5 days'
        WHEN time_in_hospital <= 7  THEN '3 — 6-7 days'
        WHEN time_in_hospital <= 14 THEN '4 — 8-14 days'
        ELSE                             '5 — 15+ days'
    END                                                         AS los_band,
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct
FROM public.vw_encounter_base
GROUP BY los_band
ORDER BY los_band;


-- ============================================================
-- SECTION 4: DIAGNOSIS CATEGORY EDA
-- Q3: Which diagnosis categories drive the most readmissions?
-- ============================================================

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
    END                                                         AS diagnosis_category,
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct,
    ROUND(AVG(time_in_hospital), 2)                             AS avg_los_days
FROM public.vw_encounter_base
GROUP BY diagnosis_category
ORDER BY readmission_rate_pct DESC;


-- ============================================================
-- SECTION 5: MEDICAL SPECIALTY AND ADMISSION SOURCE EDA
-- Q4: Which clinical departments have the highest rates?
-- Q8: Does admission source affect readmission risk?
-- ============================================================

-- By medical specialty
SELECT
    medical_specialty,
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct,
    ROUND(AVG(time_in_hospital), 2)                             AS avg_los_days
FROM public.vw_encounter_base
WHERE medical_specialty != 'Unknown'
GROUP BY medical_specialty
HAVING COUNT(*) >= 50
ORDER BY encounters DESC
LIMIT 15;

-- By admission source
SELECT
    admission_source_id,
    CASE admission_source_id
        WHEN '1' THEN 'Physician Referral'
        WHEN '2' THEN 'Clinic Referral'
        WHEN '3' THEN 'HMO Referral'
        WHEN '4' THEN 'Transfer from Hospital'
        WHEN '5' THEN 'Transfer from SNF'
        WHEN '6' THEN 'Transfer from Another Facility'
        WHEN '7' THEN 'Emergency Room'
        WHEN '8' THEN 'Court / Law Enforcement'
        WHEN '9' THEN 'Not Available'
        ELSE          'Other'
    END                                                         AS source_label,
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct
FROM public.vw_encounter_base
GROUP BY admission_source_id
ORDER BY readmission_rate_pct DESC;


-- ============================================================
-- SECTION 6: MEDICATION AND DIABETES MANAGEMENT EDA
-- Q5: Does medication management correlate with readmission?
-- ============================================================

-- By insulin prescription
SELECT
    insulin,
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct
FROM public.vw_encounter_base
GROUP BY insulin
ORDER BY readmission_rate_pct DESC;

-- By A1C result
SELECT
    "A1Cresult",
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct
FROM public.vw_encounter_base
GROUP BY "A1Cresult"
ORDER BY readmission_rate_pct DESC;

-- Medication change cross-tab
SELECT
    change                                                      AS medication_change,
    "diabetesMed"                                               AS on_diabetes_medication,
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct
FROM public.vw_encounter_base
GROUP BY change, "diabetesMed"
ORDER BY readmission_rate_pct DESC;

-- Polypharmacy vs readmission
SELECT
    CASE WHEN polypharmacy_flag = 1 THEN 'Polypharmacy (10+ meds)'
         ELSE 'Standard (<10 meds)' END                        AS medication_burden,
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct
FROM public.vw_encounter_base
GROUP BY polypharmacy_flag
ORDER BY readmission_rate_pct DESC;


-- ============================================================
-- SECTION 7: REPEAT PATIENT AND PRIOR UTILIZATION EDA
-- Q6: Do prior visits predict readmission?
-- Q9: Do repeat patients have higher readmission rates?
-- ============================================================

-- Encounter sequence vs readmission risk
SELECT
    CASE
        WHEN encounter_seq = 1 THEN '1st Encounter'
        WHEN encounter_seq = 2 THEN '2nd Encounter'
        WHEN encounter_seq = 3 THEN '3rd Encounter'
        ELSE                        '4th+ Encounter'
    END                                                         AS encounter_tier,
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct
FROM public.vw_encounter_base
GROUP BY encounter_tier
ORDER BY readmission_rate_pct DESC;

-- Repeat vs first-time patients
SELECT
    CASE WHEN is_repeat_patient = 1 THEN 'Repeat Patient'
         ELSE 'First-Time Patient' END                         AS patient_type,
    COUNT(*)                                                    AS encounters,
    SUM(led_to_30day_readmission)                               AS readmitted_30day,
    ROUND(SUM(led_to_30day_readmission) * 100.0
          / COUNT(*), 2)                                        AS readmission_rate_pct,
    ROUND(AVG(time_in_hospital), 2)                             AS avg_los,
    ROUND(AVG(num_medications), 2)                              AS avg_medications,
    ROUND(AVG(total_prior_visits), 2)                           AS avg_prior_visits
FROM public.vw_encounter_base
GROUP BY patient_type;