------------------------------------------------------------------------

editor_options: markdown: wrap: sentence ---

# 🛍️ ADS 506 Final Team Project: Forecasting U.S. Retail Sales Across Sectors

> **Course:** ADS 506 – Applied Time Series Analysis\
> **Institution:** University of San Diego – Master of Science in Applied Data Science\
> **Team:** Group 8\
> **Members:**
>
> \* **Mia Arnold**\
> \* **Jordan Blackman**\
> \* **Ramin Fazli**\
> **Repository:** <https://github.com/jblackman-bit/ADS-506-Final-Project>

------------------------------------------------------------------------

## 📌 Executive Summary & Project Purpose

Retail sales time series reflect complex consumer behavior, seasonal shopping patterns, macroeconomic regimes, and supply-chain pressures. Retail executives, inventory planners, and supply chain managers face a constant trade-off between carrying costs and stockout penalties. Because seasonal retail peaks can exceed normal monthly demand by 20% to over 100%, parsimonious and accurate time series forecasting is critical to corporate operations.

This project develops, evaluates, and deploys competing time series forecasting models across **three distinct U.S. retail verticals** and a unified **Macro Retail composite series** spanning more than 34 years of monthly data (January 1992 to August 2026, \>416 observations per series):

1.  **Defensive Non-Discretionary:** *Health and Personal Care Stores* (Pharmacies, drugstores, beauty and personal care).
2.  **High-Discretionary & Cyclical:** *Clothing and Clothing Accessories Stores* (Apparel, shoes, accessories).
3.  **Housing- & Construction-Linked:** *Building Material and Garden Equipment and Supplies Dealers* (Home improvement, lumber, nursery).
4.  **Macro Retail Composite:** Aggregate total across all three verticals representing broad consumer retail demand.

Furthermore, this repository establishes an inflation-adjusted framework using the **Consumer Price Index (CPI)** to evaluate real purchasing volume versus nominal price appreciation, benchmarks initial baseline forecasters, and scaffolds subsequent econometric models (ETS, TSLM, Seasonal ARIMA, and ARIMAX dynamic regression).

------------------------------------------------------------------------

## 📊 Dataset Catalog & Architecture

All primary series originate from the **U.S. Census Bureau Monthly Retail Trade Survey (MRTS)** and the **U.S. Bureau of Labor Statistics (BLS)**, accessed via the **Federal Reserve Bank of St. Louis (FRED)** at monthly, Not Seasonally Adjusted (NSA) granularity.

### 1. Primary Target Series (MRTS via FRED)

| Series Name | NAICS Code | FRED Series ID | Category Nature & Seasonal Signature | Time Span & Observations | Units |
|:---|:--:|:--:|:---|:--:|:--:|
| **Health & Personal Care Stores** | **446** | [`MRTSSM446USN`](https://fred.stlouisfed.org/series/MRTSSM446USN) | **Defensive Staple + Discretionary Beauty:** High baseline stability through recessions (2008 barely contracted); sharp recurring December holiday peak (gifting + year-end HSA/FSA expirations); post-2021 acceleration. | Jan 1992 – Aug 2026 (416 months) | Millions of USD (Nominal, NSA) |
| **Clothing & Accessories Stores** | **448** | [`MRTSSM448USN`](https://fred.stlouisfed.org/series/MRTSSM448USN) | **High Discretionary & Cyclical:** Extreme holiday seasonality ($1.8\times$ to $2.2\times$ monthly baseline in December); secondary August back-to-school bump; sharp vulnerability to recessions (2008 GFC & March-April 2020 lockdowns). | Jan 1992 – Aug 2026 (416 months) | Millions of USD (Nominal, NSA) |
| **Building Material & Garden Equipment Dealers** | **444** | [`MRTSSM444USN`](https://fred.stlouisfed.org/series/MRTSSM444USN) | **Housing & Weather Driven:** Prominent spring/early-summer peak (April–June); closely correlated with residential construction starts, mortgage rate cycles, and the 2020–2021 pandemic DIY home improvement surge. | Jan 1992 – Aug 2026 (416 months) | Millions of USD (Nominal, NSA) |
| **Macro Retail Composite Series** | **446 + 448 + 444** | *Derived* | **Aggregated Macro Retail:** Sum of Health, Clothing, and Building Materials ($Y_{\text{macro}, t} = Y_{\text{health}, t} + Y_{\text{clothing}, t} + Y_{\text{building}, t}$). Smooths vertical-specific shocks while capturing aggregate retail momentum. | Jan 1992 – Aug 2026 (416 months) | Millions of USD (Nominal & Real) |

### 2. Inflation Control (Deflator)

- **Consumer Price Index for All Urban Consumers: All Items (`CPIAUCNS`)**
  - **Source:** U.S. Bureau of Labor Statistics via FRED\
  - **Granularity:** Monthly, Not Seasonally Adjusted (NSA), Index 1982-1984 = 100.\
  - **Role:** Controls for monetary debasement and post-2021 inflation surges, allowing the calculation of real sales volume: $$\text{Sales}_{\text{Real}, t} = \frac{\text{Sales}_{\text{Nominal}, t}}{\text{CPI}_t} \times 100$$
  - **Data Quality & Imputation Note:** In the raw FRED release, the October 2025 observation (`2025-10-01`) is missing. To maintain a complete, unbroken monthly time series without gaps, this single point is imputed via linear interpolation ($\text{CPI}_{\text{Oct 2025}} = \frac{324.800 + 324.122}{2} = 324.461$).

------------------------------------------------------------------------

## 🔮 Recommended Exogenous Datasets for Future ARIMAX Modeling

For upcoming work in **Module 4 (EDA & Feature Engineering)** and **Module 5/6 (Dynamic Regression & ARIMAX)**, the following three macroeconomic datasets from FRED are recommended to explain demand fluctuations:

1.  **Real Disposable Personal Income (`DSPIC96`)**
    - **Source / Frequency:** U.S. Bureau of Economic Analysis (BEA) / Monthly (Billions of Chained 2017 Dollars).
    - **Economic Rationale:** Direct measure of household purchasing capacity after taxes. Crucial for explaining discretionary apparel demand elasticity and premium cosmetic/wellness purchases.
2.  **Civilian Unemployment Rate (`UNRATE`)**
    - **Source / Frequency:** U.S. Bureau of Labor Statistics (BLS) / Monthly (Percent, Seasonally Adjusted or NSA `UNRATENSA`).
    - **Economic Rationale:** Captures labor market slack and household income certainty. During economic contractions, high unemployment disproportionately dampens discretionary apparel spending while leaving health/pharmacy spending largely intact.
3.  **University of Michigan: Consumer Sentiment Index (`UMCSENT`)**
    - **Source / Frequency:** University of Michigan Surveys of Consumers / Monthly (Index 1966:Q1 = 100).
    - **Economic Rationale:** Leading indicator of consumer confidence and willingness to commit to large discretionary purchases (e.g., home remodeling materials, luxury fashion, and holiday gifting).
4.  *Additional Candidate Regressor:* **30-Year Fixed Rate Mortgage Average (`MORTGAGE30US` / `FEDFUNDS`)**
    - **Source / Frequency:** Freddie Mac / Federal Reserve Board (Aggregated to Monthly).
    - **Economic Rationale:** Specifically impacts Building Material and Home Improvement retail (`MRTSSM444USN`) by dictating home renovation loans and real estate turnover.

------------------------------------------------------------------------

## 📚 Scholarly Literature & Theoretical Foundations (APA 7)

Our modeling methodology is grounded in leading econometric and time series literature:

### 1. Foundational Review (Retail Forecasting Benchmark)

> **Fildes, R., Ma, S., & Kolassa, S. (2022).** Retail forecasting: Research and practice. *International Journal of Forecasting*, 38(4), 1283–1318. <https://doi.org/10.1016/j.ijforecast.2019.06.004> \* **Summary & Relevance:** The authoritative survey of retail demand forecasting across academia and industry. The authors demonstrate that while complex machine learning models excel at store/item-level promotions, parsimonious statistical models (such as SARIMA and ETS) remain superior, robust benchmarks for aggregated category-level sales. This justifies our benchmark strategy and emphasizes the necessity of controlling for inflation and calendar anomalies.

### 2. M5 Retail Benchmark (Walmart Competition Insights)

> **Makridakis, S., Spiliotis, E., & Assimakopoulos, V. (2022).** M5 accuracy competition: Results, findings, and conclusions. *International Journal of Forecasting*, 38(4), 1346–1364. <https://doi.org/10.1016/j.ijforecast.2021.11.013> \* **Summary & Relevance:** Analyzes 42,840 hierarchical retail sales series. A pivotal finding was that over 92% of participating data science teams failed to outperform a simple bottom-up Exponential Smoothing benchmark (`ES_bu`). The paper reinforces using out-of-sample holdout validation, combining multiple forecasting methods, and evaluating scale-free metrics (MASE, MAPE, RMSE).

### 3. Core Course Textbook (Methodological Framework)

> **Hyndman, R. J., & Athanasopoulos, G. (2021).** *Forecasting: Principles and practice* (3rd ed.). OTexts: Melbourne, Australia. <https://otexts.com/fpp3/> \* **Summary & Relevance:** The primary theoretical and programmatic authority for the project. Informs our implementation of the `tidyverts` framework (`tsibble`, `feasts`, `fable`), including STL decomposition (Chapter 3), Exponential Smoothing state space taxonomy (Chapter 8), Box-Jenkins Seasonal ARIMA (Chapter 9), dynamic regression with ARIMA errors (Chapter 10), and hierarchical forecast reconciliation (Chapter 11).

## 🗺️ Project Roadmap & Workstream Allocation

Based on our team agreements and the project tracking matrix, the workflow is partitioned as follows:

| Workstream / Deliverable | Script / Deliverable File | Methodology & Framework | Lead | Status |
|:---|:---|:---|:--:|:--:|
| **1. Data Ingestion & Pipeline** | `ads506_retail_sales_analysis.Rmd` (Sec 2) | Automated FRED download via curl, CPI deflation, imputation check, unified `tsibble` table export | **Jordan** | Completed |
| **2. Exploratory Data Analysis (EDA)** | `ads506_retail_sales_analysis.Rmd` (Sec 3) | `feasts` (STL Loess, `gg_season`, `gg_subseries`, ACF/PACF diagnostics) | **Jordan** | Completed |
| **3. Baseline Benchmark Forecasters** | `ads506_retail_sales_analysis.Rmd` (Sec 4.1) | `fable` (Seasonal Naïve, Drift, Mean) with RMSE, MAE, MAPE, MASE | **Mia** | Completed |
| **4. Exponential Smoothing (ETS)** | `ads506_retail_sales_analysis.Rmd` (Sec 4.2) | `fable::ETS()` state-space models (additive vs multiplicative seasonal structures) | **Mia** | Scaffolded |
| **5. Time Series Regression (TSLM)** | `ads506_retail_sales_analysis.Rmd` (Sec 4.3) | `fable::TSLM()` deterministic trend + monthly seasonal dummies + macro predictors | **Team** | Scaffolded |
| **6. ARIMA & Seasonal ARIMA** | `ads506_retail_sales_analysis.Rmd` (Sec 4.4) | `fable::ARIMA()`, KPSS unit-root tests, differencing, Box-Jenkins diagnostic loop | **Ramin** | Scaffolded |
| **7. Advanced & Dynamic Regression** | `ads506_retail_sales_analysis.Rmd` (Sec 4.5) | Dynamic harmonic regression (Fourier), ARIMAX with FRED macro predictors, ensembles | **Team** | Scaffolded |
| **8. Interactive Shiny Dashboard** | `app.R` | `shiny`, `bslib`, `fpp3`, `ggplot2`, scenario exploration & forecast viewer | **Jordan** | Completed |
| **9. Executive Data Story (Deliverable 1)** | Slide Deck & MP4 Video Presentation | 8–10 minute executive presentation (Context-Conflict-Resolution), non-technical visuals | **All** | Upcoming (Mod 6) |
| **10. Technical Written Report (Deliverable 2)** | Final PDF / Quarto Document | 10–15 page formal paper in APA 7 format | **All** | Upcoming (Mod 7) |

------------------------------------------------------------------------

## 💻 Repository Structure & File Organization

``` text
ADS-506-Final-Project/
├── README.md                          # Central project documentation & team guide
├── ads506_retail_sales_analysis.Rmd   # Master R Markdown analysis (Ingestion, EDA, Decomposition, Models)
├── app.R                              # Interactive Shiny Dashboard application
├── data/
│   └── retail_data_clean.csv          # Processed tidy dataset (All verticals + Macro + CPI)
└── .gitignore                         # Standard R & RStudio ignore rules
```

------------------------------------------------------------------------

## 🚀 Quick Start Guide

### Prerequisites

Make sure R (\>= 4.2) and the tidyverts package suite are installed:

``` r
install.packages(c("tidyverse", "fpp3", "scales", "zoo", "shiny", "bslib"))
```

### 1. Running the Master Analysis

Open `ads506_retail_sales_analysis.Rmd` in RStudio or run in terminal:

``` r
rmarkdown::render("ads506_retail_sales_analysis.Rmd")
```

This executes: 1. Automated ingestion of all 3 MRTS series and CPI from FRED. 2. Missing value check and linear interpolation of October 2025 CPI. 3. Creation of the aggregate Macro Retail series and CPI deflation. 4. Export to `data/retail_data_clean.csv`. 5. Visualizations: time series trends, seasonal plots, and STL decomposition. 6. Benchmark model training (SNAIVE, Drift, Mean) and test set evaluation (RMSE, MAE, MAPE, MASE).

### 2. Launching the Interactive Shiny App

Run in R or RStudio:

``` r
shiny::runApp("app.R")
```

Or from the command line:

``` bash
Rscript -e "shiny::runApp('app.R', port = 8080)"
```

Features available in the Shiny Dashboard: \* Switch between **Macro Retail Composite** and individual verticals (Health, Clothing, Building). \* Toggle between **Nominal Dollar Sales** and **Real (Inflation-Adjusted) Sales**. \* Inspect **STL Decomposition**, **Seasonal Profiles**, and **Subseries Plots**. \* Generate **Baseline Point Forecasts and 80%/95% Prediction Intervals** for up to 24 months forward.
