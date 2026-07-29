-- 1. Wipe the old structural footprint of the view completely
DROP VIEW IF EXISTS public.vw_encounter_base CASCADE;

-- 2. Create your clean, updated view definition
CREATE VIEW public.vw_encounter_base AS
WITH ordered_encounters AS (
    SELECT
        encounter_id,
        patient_nbr,
        readmitted,
        time_in_hospital,
        admission_type_id,
        discharge_disposition_id,
        admission_source_id,
        medical_specialty,
        diag_1,
        diag_2,
        diag_3,
        number_diagnoses,
        num_lab_procedures,
        num_procedures,
        num_medications,
        number_outpatient,
        number_emergency,
        number_inpatient,
        total_prior_visits,
        num_active_medications,
        any_medication_change,
        polypharmacy_flag,
        age,
        age_midpoint,
        gender,
        race,
        insulin,
        "diabetesMed",
        change,
        "A1Cresult",
        max_glu_serum,
        weight_available,
        any_outlier_flag,
        diag_1_missing_flag,

        -- Encounter sequence per patient (1 = earliest recorded encounter)
        ROW_NUMBER() OVER (
            PARTITION BY patient_nbr
            ORDER BY encounter_id
        ) AS encounter_seq,

        -- Total encounters on record for this patient
        COUNT(*) OVER (
            PARTITION BY patient_nbr
        ) AS patient_total_encounters,

        -- Prior encounter ID for the same patient
        LAG(encounter_id) OVER (
            PARTITION BY patient_nbr
            ORDER BY encounter_id
        ) AS prior_encounter_id

    FROM public.diabetic_data_clean
    WHERE expired_or_hospice_flag = 0   -- Cannot be readmitted
      AND gender_invalid_flag     = 0   -- Unusable demographic
)
SELECT
    *,

    -- FORWARD-LOOKING: After THIS discharge, was patient readmitted within 30 days?
    CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END  AS led_to_30day_readmission,

    -- FORWARD-LOOKING: After THIS discharge, was patient readmitted at any point?
    CASE WHEN readmitted IN ('<30', '>30') THEN 1 ELSE 0 END AS led_to_any_readmission,

    -- BACKWARD-LOOKING: Is THIS encounter itself the result of a prior discharge?
    CASE WHEN prior_encounter_id IS NOT NULL THEN 1 ELSE 0 END AS is_itself_a_readmission,

    -- Is this the patient's first recorded encounter?
    CASE WHEN prior_encounter_id IS NULL THEN 1 ELSE 0 END AS is_first_encounter,

    -- Is this a repeat patient (more than one encounter on record)?
    CASE WHEN COUNT(*) OVER (PARTITION BY patient_nbr) > 1 THEN 1 ELSE 0 END
        AS is_repeat_patient

FROM ordered_encounters;

-- Sanity check
SELECT
    COUNT(*)                        AS total_valid_encounters,
    SUM(led_to_30day_readmission)   AS will_be_readmitted_30day,
    SUM(led_to_any_readmission)     AS will_be_readmitted_any,
    SUM(is_itself_a_readmission)    AS are_readmissions,
    SUM(is_first_encounter)         AS first_encounters,
    SUM(is_repeat_patient)          AS repeat_patient_encounters
FROM public.vw_encounter_base;