-- ============================================================
-- INDEXES FOR diabetic_data_clean
-- Created after post-load validation confirms clean table
-- is correct. Indexes cover columns used in WHERE filters,
-- GROUP BY aggregations, and PARTITION BY window functions
-- across all EDA queries and KPI views.
-- ============================================================

-- Index 1: Primary key — used in every window function and join
-- PARTITION BY encounter_id and joins back to clean table
CREATE INDEX IF NOT EXISTS idx_clean_encounter_id
    ON public.diabetic_data_clean (encounter_id);

-- Index 2: Patient key — used in LAG() window function in base view
-- PARTITION BY patient_nbr ORDER BY encounter_id drives the entire
-- readmission sequence logic in vw_encounter_base
CREATE INDEX IF NOT EXISTS idx_clean_patient_nbr
    ON public.diabetic_data_clean (patient_nbr);

-- Index 3: Target variable — filtered and grouped in every KPI view
-- WHERE readmitted = '<30' and GROUP BY readmitted appear in all 8 views
CREATE INDEX IF NOT EXISTS idx_clean_readmitted
    ON public.diabetic_data_clean (readmitted);

-- Index 4: Primary diagnosis — used in GROUP BY for diagnosis category
-- KPI view and EDA queries. Also used in the CASE statement ICD-9
-- regex mapping which benefits from faster column access
CREATE INDEX IF NOT EXISTS idx_clean_diag_1
    ON public.diabetic_data_clean (diag_1);

-- Index 5: Discharge disposition — used in GROUP BY for disposition
-- KPI view and in the expired/hospice flag logic during cleaning
CREATE INDEX IF NOT EXISTS idx_clean_discharge_disposition
    ON public.diabetic_data_clean (discharge_disposition_id);

-- Index 6: Medical specialty — used in GROUP BY for specialty KPI
-- view. Filtered with WHERE medical_specialty != 'Unknown' and
-- HAVING COUNT(*) >= 50 in vw_kpi_readmission_by_specialty
CREATE INDEX IF NOT EXISTS idx_clean_medical_specialty
    ON public.diabetic_data_clean (medical_specialty);

-- Index 7: Age — used in GROUP BY for age band KPI view
-- vw_kpi_readmission_by_age groups by age and prior_inpatient_band
CREATE INDEX IF NOT EXISTS idx_clean_age
    ON public.diabetic_data_clean (age);

-- Index 8: Expired flag — filtered in WHERE clause of vw_encounter_base
-- WHERE expired_or_hospice_flag = 0 runs on every query that uses
-- the base view, making this one of the most frequently used indexes
CREATE INDEX IF NOT EXISTS idx_clean_expired_flag
    ON public.diabetic_data_clean (expired_or_hospice_flag);

-- Index 9: Gender flag — filtered alongside expired flag in base view
-- WHERE gender_invalid_flag = 0 applies to all KPI views and EDA queries
CREATE INDEX IF NOT EXISTS idx_clean_gender_flag
    ON public.diabetic_data_clean (gender_invalid_flag);

-- ============================================================
-- VERIFICATION
-- Run after index creation to confirm all 9 indexes exist
-- Expected: 9 rows returned with correct index names
-- ============================================================

-- Verify all indexes were created successfully
SELECT
    indexname                               AS index_name,
    indexdef                                AS definition
FROM pg_indexes
WHERE tablename  = 'diabetic_data_clean'
  AND schemaname = 'public'
ORDER BY indexname;