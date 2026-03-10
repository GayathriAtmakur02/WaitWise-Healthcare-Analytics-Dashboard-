# WaitWise Healthcare Analytics Dashboard

> A full-cycle healthcare data analytics project analysing 450K+ patient wait list records across specialties, case types, and age groups using Power BI.

This project transforms raw healthcare operational data into an interactive Power BI dashboard that helps identify bottlenecks, track waiting times, and support data-driven decision making across healthcare services.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Business Problem](#business-problem)
- [Project Objectives](#project-objectives)
- [Dataset Information](#dataset-information)
- [Data Analytics Workflow](#data-analytics-workflow)
- [Tools and Technologies](#tools-and-technologies)
- [Data Model](#data-model)
- [Dashboard Features](#dashboard-features)
- [Key Insights](#key-insights)
- [Business Recommendations](#business-recommendations)
- [Business Impact](#business-impact)
- [Repository Structure](#repository-structure)
- [How to Use](#how-to-use)
- [Author](#author)

---

## Project Overview

Healthcare systems face increasing pressure due to growing patient waiting lists across outpatient, inpatient, and day-case services.

This project analyses **450,000+ healthcare records (2018–2021)** and builds an interactive Power BI dashboard to answer key operational questions:

- How large is the current patient wait list?
- Which specialties are most overloaded?
- Which case type contributes most to the backlog?
- How long are patients waiting for treatment?
- How has the waiting list changed over time?

The final dashboard provides real-time visibility into patient wait list performance across the organisation.

---

## Business Problem

Healthcare administrators struggle to monitor patient wait lists due to fragmented data sources and lack of interactive reporting.

**Key challenges include:**

- Increasing patient backlog with no centralised visibility
- Lack of specialty-level reporting across departments
- Long waiting times negatively impacting patient outcomes
- Inefficient resource allocation due to absent demand data

This project builds a centralised analytics solution to help healthcare stakeholders monitor and analyse waiting lists efficiently.

---

## Project Objectives

- Monitor current patient waiting list size in real time
- Compare current performance vs previous year (YoY analysis)
- Identify specialties with high backlog and capacity pressure
- Analyse waiting time bands across patient cohorts
- Understand patient distribution across age groups
- Track wait list trends over time using monthly trend analysis

---

## Dataset Information

| Attribute     | Detail                                  |
|---------------|-----------------------------------------|
| Records       | 453,000+                                |
| Time Period   | 2018 – 2021                             |
| Specialties   | 78 Medical Specialties                  |
| Case Types    | Outpatient, Day Case, Inpatient         |

**Key Fields:**

| Field              | Description                                      |
|--------------------|--------------------------------------------------|
| Archive Date       | Date the record snapshot was captured            |
| Case Type          | Treatment category (Outpatient / Day Case / Inpatient) |
| Specialty Name     | Medical specialty associated with the wait entry |
| Age Profile        | Patient age group bracket (0–15, 16–64, 65+)    |
| Waiting Time Band  | Wait duration category (0–3 months to 18+ months)|
| Patient Count      | Number of patients in each category              |

---

## Data Analytics Workflow

This project follows a complete end-to-end Data Analytics lifecycle:

```
Requirement Gathering
        ↓
Data Collection
        ↓
Data Cleaning & Transformation
        ↓
Data Modelling
        ↓
Visualization Blueprint
        ↓
Dashboard Development
        ↓
Testing & Validation
        ↓
Deployment & Sharing
```

---

## Tools and Technologies

| Tool            | Purpose                              |
|-----------------|--------------------------------------|
| Power BI        | Dashboard development & visualisation |
| Power Query     | Data ingestion & transformation      |
| DAX             | Calculated measures & KPIs           |
| Star Schema     | Dimensional data modelling           |
| CSV / Excel     | Raw data source                      |

---

## Data Model

The dataset was structured using a **star schema** for optimised query performance and dashboard responsiveness.

```
                  Date
                   |
                   |
Case Type ── Fact Wait List ── Specialty
                   |
                   |
             Age Profile
                   |
               Time Bands
```

**Fact Table:** Patient Wait List Records  
**Dimension Tables:** Date, Case Type, Specialty, Age Profile, Time Bands

---

## Dashboard Features

The solution includes two purpose-built dashboard pages:

### Page 1 — Executive Overview

- Latest Month Wait List KPI Card
- Previous Year Comparison (YoY)
- Case Type Distribution — Donut Chart
- Specialty Wait List Performance — Ranked Bar Chart
- Waiting Time Band Distribution — Stacked Bar Chart
- Monthly Trend Analysis — Line Chart

### Page 2 — Detailed Analysis View

- Drill-down matrix by Specialty, Age Profile, Time Band, and Case Type
- Cross-visual filtering across all dimensions
- Average vs Median metric toggle

---

## Dashboard Preview

### Executive Overview
![Executive Overview](images/dashboard_overview.png)

### Detailed Analysis View
![Detailed Analysis](images/dashboard_details.png)

---

## Key Insights

### 1. Wait Lists Are Increasing

| Metric              | Value     |
|---------------------|-----------|
| Latest Wait List    | 708,729   |
| Previous Year       | 640,441   |
| Year-over-Year Growth | +10.7%  |

The backlog is growing and without intervention will continue to compound.

### 2. Outpatient Services Drive the Backlog

| Case Type   | Patients | Share |
|-------------|----------|-------|
| Outpatient  | 628,756  | 89%   |
| Day Case    | 57,631   | 8%    |
| Inpatient   | 22,342   | 3%    |

Outpatient consultations and diagnostics represent the primary system bottleneck.

### 3. Certain Specialties Face Higher Demand

Specialties with the highest average wait lists include:

- Paediatric Dermatology
- Paediatric Orthopaedics
- Accident & Emergency
- Orthopaedics
- ENT (Otolaryngology)
- General Surgery

These departments require priority resource allocation.

### 4. Long Waiting Times Persist

A significant patient cohort falls into the **18+ month** waiting category, indicating a long-tail backlog requiring a dedicated clearance programme.

### 5. Elderly Patients Experience Longer Wait Times

Patients aged **65+** appear disproportionately in longer waiting bands, suggesting the need for age-sensitive prioritisation protocols within clinical triage.

---

## Business Recommendations

| Priority | Recommendation                                              |
|----------|-------------------------------------------------------------|
| High     | Expand outpatient consultation capacity and telehealth options |
| High     | Increase staffing and sessions for high-demand specialties  |
| High     | Launch a dedicated 18+ month backlog clearance programme    |
| Medium   | Introduce age-sensitive triage prioritisation for 65+ patients |
| Medium   | Implement data-driven scheduling to optimise patient flow   |
| Ongoing  | Use real-time dashboards for continuous wait list monitoring |

---

## Business Impact

This dashboard enables healthcare stakeholders to:

- Monitor backlog trends in real time across all specialties
- Identify overloaded departments and prioritise resource allocation
- Improve patient flow planning with evidence-based scheduling
- Support data-driven healthcare policy and operational decisions
- Reduce long-wait cases and improve patient outcomes

---

## Repository Structure

```
WaitWise-Healthcare-Analytics/
│
├── data/
│   ├── inpatient_2018.csv
│   ├── outpatient_2019.csv
│   └── specialty_mapping.csv
│
├── dashboard/
│   └── WaitWise_Healthcare_Dashboard.pbix
│
├── images/
│   ├── dashboard_overview.png
│   └── dashboard_details.png
│
└── README.md
```

---

## How to Use

**1. Clone the repository**

```bash
git clone https://github.com/yourusername/WaitWise-Healthcare-Analytics
```

**2. Open the Power BI file**

```
dashboard/WaitWise_Healthcare_Dashboard.pbix
```

**3. Connect your data source**

Update the data source path in Power Query to point to the `/data` folder on your local machine.

**4. Explore the dashboard**

Use the slicers to filter by Date, Specialty, Case Type, Age Profile, and Time Band. Toggle between Average and Median metrics using the parameter control.

---

## Author

**Gayathri**  
Data Analyst | Business Intelligence | Data Visualisation

---

*WaitWise Healthcare Analytics Dashboard — Power BI End-to-End Project | 2018–2021*
