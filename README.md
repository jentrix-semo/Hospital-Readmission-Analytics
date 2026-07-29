# Hospital Readmission Analytics
### End-to-End Clinical Analytics | Python · PostgreSQL · Power BI

![Python](https://img.shields.io/badge/Python-3.14-blue?logo=python)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue?logo=postgresql)
![Power BI](https://img.shields.io/badge/Power%20BI-DirectQuery-yellow?logo=powerbi)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)

---

## Project Overview

This project delivers a complete end-to-end clinical analytics pipeline analyzing **30-day hospital readmission patterns** across 101,766 diabetic inpatient encounters from 130 US hospitals (1999–2008). The analysis moves from raw data through professional-grade profiling, cleaning, statistical validation, and KPI development to an interactive Power BI dashboard connected live to PostgreSQL views via DirectQuery.

The project was built to demonstrate the analytical thinking, technical depth, and clinical reasoning that global health organizations, NGOs, and health informatics teams expect from a healthcare data analyst.

---

## Project Overview

This project delivers a complete end-to-end clinical 
analytics pipeline...

---

### Dashboard Preview

**Executive Summary — Overall 30-Day Readmission Rate**
![Executive Summary](images/Executive%20summary.png)

**Patient Demographics — Repeat Patient Risk Analysis**
![Patient Demographics](images/Patient%20Demographics.png)

**High Risk Segments — Three-Tier Risk Classification**
![High Risk Segments](images/High%20Risk%20Segments.png)

--

## Analytical Questions

This project was designed to answer ten specific clinical questions:

| # | Question |
|---|---|
| Q1 | What is the overall 30-day readmission rate across this hospital system? |
| Q2 | Which patient demographics carry the highest readmission risk? |
| Q3 | Which primary diagnosis categories drive the most readmissions? |
| Q4 | Which clinical departments have the highest readmission rates? |
| Q5 | Does medication management correlate with readmission risk? |
| Q6 | Do prior inpatient or emergency visits predict readmission? |
| Q7 | Does length of stay or polypharmacy correlate with readmission? |
| Q8 | Which discharge disposition carries the highest readmission risk? |
| Q9 | Do repeat patients have higher readmission rates than first-time patients? |
| Q10 | What is the clinical profile of the highest-risk patient segment? |

---

## Dataset

| Attribute | Detail |
|---|---|
| **Source** | UCI Machine Learning Repository |
| **Dataset** | Diabetes 130-US Hospitals for Years 1999–2008 |
| **Citation** | Strack, B. et al. (2014). Impact of HbA1c Measurement on Hospital Readmission Rates. BioMed Research International |
| **Size** | 101,766 encounters · 50 features · 130 US hospitals |
| **Target variable** | readmitted (<30, >30, NO) |
| **Download** | https://archive.ics.uci.edu/dataset/296/diabetes+130-us+hospitals+for+years+1999-2008 |

---

## Tool Stack and Responsibilities

| Tool | Role | Why |
|---|---|---|
| **Python** (pandas, numpy, scipy) | Profiling, cleaning, feature engineering, statistical validation, visualizations | Row-level transformations and statistical testing |
| **PostgreSQL** | EDA, window functions, KPI views | Set-based aggregation and reusable view objects |
| **Power BI** | Interactive dashboard | Live DirectQuery connection to SQL KPI views |
| **Jupyter Notebook** | Development environment | Interactive step-by-step analytical workflow |

---

## Pipeline Architecture

```
RAW TABLE (PostgreSQL: diabetic_data — never modified)
    │
    ▼  Python: profile → clean → engineer features → validate → export
    │
CLEAN TABLE (PostgreSQL: diabetic_data_clean)
    │
    ▼  SQL: index → base view (window functions + clinical exclusions)
    │
BASE VIEW (vw_encounter_base)
    │
    ├── SQL EDA queries (7 analytical sections)
    ├── Python statistical validation (scipy)
    ├── Python visualizations (matplotlib, seaborn)
    │
    ▼  SQL: 8 KPI views (CREATE VIEW)
    │
KPI VIEWS (vw_kpi_*)
    │
    ▼  Power BI DirectQuery → 6-page interactive dashboard
```

---

## Key Findings

### Overall Performance
- **30-day readmission rate: 11.39%** across 99,340 valid encounters
- 11,314 patients readmitted within 30 days — 1 in every 9 diabetic inpatients

### Strongest Predictor — Encounter History
- Repeat patients generate **73% of all 30-day readmissions** despite representing only 46% of encounters
- Readmission risk escalates perfectly with each encounter:
  `1st: 8.98% → 2nd: 14.16% → 3rd: 17.44% → 4th+: 23.91%`
- Statistically confirmed: chi-square = 5,866.86 (p effectively = 0)

### Highest Risk Clinical Segments
- **High Risk segment** (prior inpatient ≥ 2, LOS ≥ 7, medications ≥ 15): **21.82%** — nearly double the baseline
- **Oncology specialty**: **20.06%** — highest specialty rate (cancer-diabetes comorbidity)
- **Nephrology specialty**: **16.11%** — highest rate among high-volume specialties
- **Rehabilitation Facility discharge**: **27.71%** — highest disposition readmission rate

### Medication Management Findings
- **83% of encounters had no A1C test** — tested patients show 1.74 points lower readmission rate (chi-square = 42.11, p effectively = 0)
- Insulin dose adjustment (any direction) predicts above-baseline readmission risk
- **79.81% of encounters involve polypharmacy** (10+ medications) — polypharmacy patients show 12.00% vs 8.99% for standard burden (chi-square = 143.67, p effectively = 0)

### Not a Significant Predictor
- **Gender does NOT predict readmission** — Female (11.46%) vs Male (11.30%): 0.16 point difference not statistically significant (chi-square = 0.63, p = 0.428)

### Statistical Validation Summary

| Test | Method | EDA Finding | P-value | Significant |
|---|---|---|---|---|
| Repeat vs First-Time Patient | Chi-square | 19.76% vs 4.26% | 0.000000 | Yes |
| Polypharmacy vs Standard | Chi-square | 12.00% vs 8.99% | 0.000000 | Yes |
| Length of Stay | Mann-Whitney U | Median: 4.00 both groups | 0.000000 | Yes |
| Total Prior Visits | Mann-Whitney U | Median: 1.00 vs 0.00 | 0.000000 | Yes |
| Gender vs Readmission | Chi-square | 11.46% vs 11.30% | 0.428375 | **No** |
| A1C Tested vs Not Tested | Chi-square | 11.69% vs 9.95% | 0.000000 | Yes |
| Medication Change | Chi-square | 12.02% vs 10.62% | 0.000000 | Yes |

**6 of 7 hypotheses statistically confirmed.**

---

## Recommendations

1. **Implement repeat patient flag at admission** — prior encounter history is immediately available from hospital records and should trigger enhanced discharge planning on day 1 without requiring any predictive model

2. **Deploy intensive post-discharge support for High Risk segment** (21.82%) — case manager assignment, pharmacist medication review, and follow-up calls at 3, 7, and 14 days post-discharge

3. **Introduce universal A1C testing** as standard of care for all diabetic inpatient admissions — the statistically confirmed association represents approximately 1,436 potentially preventable readmissions if applied to the 83% currently untested

4. **Focus prevention on the 1st to 2nd encounter transition** — the 5.18 percentage point jump at this transition is the single highest-leverage intervention point in the dataset

5. **Target Oncology (20.06%) and Nephrology (16.11%)** for specialty-specific post-discharge diabetes management protocols

6. **Flag patients with medication dose changes at discharge** for pharmacist review within 48–72 hours — medication change status is known at discharge requiring no additional screening

---

## Project Structure

```
hospital-readmission-analytics/
│
├── config.py                          ← Central configuration (all column groups, valid values)
├── data_dictionary.py                 ← Column interpretation guide — run once
├── project_brief.md                   ← Analytical questions and project scope
│
├── notebooks/
│   ├── 00_setup.ipynb                 ← Environment setup, .env, project structure
│   ├── 01_data_profiling.ipynb        ← Structure, sentinel detection, cardinality, class imbalance
│   ├── 02_data_cleaning.ipynb         ← Sentinel replacement, deduplication, missing values,
│   │                                     dtype correction, text standardization, invalid value
│   │                                     flagging, outlier detection
│   ├── 03_feature_engineering.ipynb   ← 5 derived features + pre-export validation + export
│   ├── 04_eda.ipynb                   ← 7 SQL EDA sections via pd.read_sql()
│   ├── 05_statistical_validation.ipynb← 7 hypothesis tests (chi-square + Mann-Whitney U)
│   └── 06_visualizations.ipynb        ← 4 matplotlib/seaborn charts
│
├── sql/
│   ├── create_table.sql               ← Raw table DDL for diabetic_data
│   ├── post_load_validation.sql       ← 7 integrity checks after Python export
│   ├── create_indexes.sql             ← 9 indexes on diabetic_data_clean
│   ├── create_base_view.sql           ← vw_encounter_base (window functions + exclusions)
│   ├── eda_queries.sql                ← 7 EDA sections with clinical comments
│   └── create_kpi_views.sql           ← 8 KPI views for Power BI
│
├── outputs/
│   ├── data_dictionary.csv
│   ├── profile_01_raw_structure.csv
│   ├── profile_02_sentinel_report.csv
│   ├── profile_03_cardinality.csv
│   ├── profile_04_numeric_raw.csv
│   ├── profile_05_class_imbalance.csv
│   ├── outlier_report.csv
│   └── charts/
│       ├── 01_boxplots_by_readmission.png
│       ├── 02_correlation_heatmap.png
│       ├── 03_readmission_by_age.png
│       └── 04_active_meds_by_readmission.png
│
├── dashboard/
│   ├── hospital_readmission_dashboard.pbix
│   └── dashboard_screenshot.png
│
├── .gitignore
└── README.md
```

---

## Data Cleaning Decisions

| Issue | Column | Strategy | Reason |
|---|---|---|---|
| Sentinel "?" as missing | weight, race, payer_code, medical_specialty, diag_1/2/3 | Replace with NaN | Dataset encodes missing as "?" not NULL |
| High missingness | weight (96.86%) | weight_available flag | Too sparse to impute |
| High missingness | medical_specialty (49%), payer_code (40%) | Fill "Unknown" | Imputation would fabricate categories |
| Low missingness | race (2.23%) | Fill "Unknown" | Demographics never imputed |
| Absent secondary diagnoses | diag_2, diag_3 | Fill "None" | Legitimately absent for simpler cases |
| Missing primary diagnosis | diag_1 (21 rows) | diag_1_missing_flag | Data quality error — flag not drop |
| Invalid demographic | gender = Unknown/Invalid (3 rows) | gender_invalid_flag | Excluded from all KPI calculations |
| Cannot be readmitted | Discharge codes 11,13,14,19,20,21 (2,423 rows) | expired_or_hospice_flag | Dead/hospice patients inflate NO readmission count |
| Wrong dtype | admission_type_id, discharge_disposition_id, admission_source_id | Cast to string | Categorical lookup codes not quantities |
| Outliers | All 8 numeric columns | IQR flag per column | Flag not drop — clinical outliers are meaningful |

---

## Engineered Features

| Feature | Definition | Clinical Purpose |
|---|---|---|
| num_active_medications | Count of medication columns where value ≠ "No" | Diabetes-specific prescription burden |
| any_medication_change | 1 if any medication dose adjusted Up or Down | Signal of glycemic instability at admission |
| age_midpoint | Numeric midpoint of age band string e.g. [70-80) → 75 | Enables correlation analysis on age |
| total_prior_visits | number_outpatient + number_emergency + number_inpatient | Composite prior utilization indicator |
| polypharmacy_flag | 1 if num_medications ≥ 10 | Clinical threshold for medication burden |

---

## KPI Views

| View | Answers | Rows |
|---|---|---|
| vw_kpi_overall_readmission | Q1: Overall 30-day rate | 1 |
| vw_kpi_readmission_by_diagnosis | Q3: Rate by ICD-9 category | 12 |
| vw_kpi_readmission_by_disposition | Q8: Rate by discharge destination | 11 |
| vw_kpi_los_by_readmission | Q7: LOS by readmission outcome | 3 |
| vw_kpi_readmission_by_age | Q2+Q6: Rate by age and prior inpatient | 39 |
| vw_kpi_readmission_by_specialty | Q4: Rate by medical specialty | 34 |
| vw_kpi_high_risk_segments | Q10: Three-tier risk classification | 3 |
| vw_kpi_repeat_patient_readmission | Q9: Repeat vs first-time patients | 2 |

---

## Dashboard Pages

| Page | Key Visual | Primary Finding |
|---|---|---|
| Executive Summary | 4 KPI cards + risk tier bar + donut | Overall rate 11.39%, High Risk 21.82% |
| Diagnosis and Specialty | 2 bar charts + scatter plot | V-codes 16.24%, Oncology 20.06% |
| Patient Demographics | Matrix + combo chart + 2 cards | Repeat patients 19.76% vs 4.26% |
| Clinical Utilization | Grouped bar + 2 bar charts + 4 cards | Rehab Facility 27.71%, Emergency 11.98% |
| High Risk Segments | Combo chart + table + 3 cards | High Risk 21.82%, Moderate 16.95%, Low 9.91% |
| Summary and Key Findings | Text + statistical table + cards | All confirmed findings and recommendations |

---

## Limitations

1. **Observational data** — all findings confirm statistical associations, not causation. Confounders including socioeconomic status, hospital quality, care continuity, and social support are not controlled
2. **Historical dataset (1999–2008)** — clinical practices, medication options, and hospital protocols have evolved significantly since this period
3. **weight column excluded** — 96.86% missing, too sparse to use analytically
4. **medical_specialty 49% missing** — Unknown filtered from specialty KPI view; findings apply to the 51% with recorded specialty
5. **Class imbalance** — the <30 day readmission class represents only 11.16% of raw encounters (4.8:1 imbalance). Any future predictive modeling extension would require SMOTE oversampling or class weighting
6. **No multiple testing correction** — 7 tests conducted without Bonferroni correction; however 6 of 7 returned p effectively = 0, far below any corrected threshold
7. **Encounter sequence approximated** — no admission dates in dataset; encounter order derived from encounter_id which approximates but may not perfectly reflect chronological order

---

## How to Reproduce

### Prerequisites

```bash
pip install pandas numpy sqlalchemy psycopg2-binary scipy matplotlib seaborn python-dotenv
```

### Database Setup

1. Download `diabetic_data.csv` from UCI ML Repository
2. Create database in pgAdmin: `hospital_readmission_db`
3. Run `sql/create_table.sql` in pgAdmin Query Tool
4. Import CSV via pgAdmin GUI: right-click `diabetic_data` → Import/Export Data

### Environment Setup

Create a `.env` file in the project root:

```
DB_USER=postgres
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432
DB_NAME=hospital_readmission_db
```

### Run the Pipeline

```
Step 1: Run notebooks in order:
        00_setup.ipynb
        01_data_profiling.ipynb
        02_data_cleaning.ipynb
        03_feature_engineering.ipynb
        04_eda.ipynb
        05_statistical_validation.ipynb
        06_visualizations.ipynb

Step 2: Run SQL scripts in pgAdmin in order:
        sql/post_load_validation.sql
        sql/create_indexes.sql
        sql/create_base_view.sql
        sql/eda_queries.sql
        sql/create_kpi_views.sql

Step 3: Connect Power BI:
        Install psqlODBC driver (64-bit)
        Get Data → PostgreSQL → DirectQuery
        Server: localhost
        Database: hospital_readmission_db
        Connect to all vw_kpi_* views
```

---

## Author

**Jentrix Semo**
Public Health Professional | Healthcare Data Analyst

[![GitHub](https://img.shields.io/badge/GitHub-jentrix--semo-black?logo=github)](https://github.com/jentrix-semo)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Jentrix%20Semo-blue?logo=linkedin)](https://linkedin.com/in/jentrix-semo)

*Building a portfolio targeting NGO, global health, and health informatics roles.*

---

## License

This project uses the UCI Diabetes 130-US Hospitals dataset which is publicly available under the Creative Commons Attribution 4.0 International license. All code in this repository is available under the MIT License.
