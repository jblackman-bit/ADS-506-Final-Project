# Section 5.4: Seasonal ARIMA Results

**Owner:** Ramin Fazli | **Data:** `data/retail_data_clean.csv` (FRED/Census MRTS, Jan 1992 to Aug 2026) | **Train:** Jan 1992 to Dec 2023 (384 months) | **Test:** Jan 2024 to Aug 2026 (32 months)

## Summary

- Seasonal ARIMA beats the best baseline on **3 of 4 series** (Clothing, Health, Macro Retail Total). Building & Garden Supplies is the exception: no ARIMA candidate beat seasonal naive there.
- The plain auto ARIMA models left significant autocorrelation in the residuals (Ljung-Box p < 0.001) for Health, Building, and Macro. The cause is **trading-day effects**, not COVID: the problem was already present in 1993 to 2019 data.
- Adding trading-day regressors (the number of each weekday in the month) fixed the residuals for all four series (Ljung-Box p from 0.13 to 0.91). It also gave the lowest training AICc, so it is our selected ARIMA model.

## 1. Stationarity (log scale)

We modeled `log(sales_nominal)` to stabilize the growing seasonal swings, as recommended in the scaffold and in Hyndman & Athanasopoulos (2021).

| Series | Seasonal diff (D) | First diff (d) | KPSS p after D=1 |
|---|---|---|---|
| Building & Garden | 1 | 1 | 0.048 |
| Clothing & Accessories | 1 | 0 | 0.100 |
| Health & Personal Care | 1 | 1 | 0.010 |
| Macro Retail Total | 1 | 1 | 0.044 |

**Note for the team:** Section 4.8 tested raw sales and found d = 0 for Building and Macro. On the log scale, both need d = 1, although their KPSS results are borderline. Only Clothing is stationary after seasonal differencing alone.

## 2. Candidate models

For each series we fit seven ARIMA candidates:

- **Automated:** stepwise auto ARIMA, full-search auto ARIMA, and auto ARIMA on a Box-Cox scale (Guerrero lambda).
- **Manual:** three specifications chosen from the ACF/PACF plots: (2,1,0)(0,1,1), (0,1,2)(0,1,1), and the airline model (0,1,1)(0,1,1). For Clothing the manual models use d = 0.
- **Trading-day ARIMA:** regression with ARIMA errors, using weekday counts and days in the month as predictors. These regressors are fixed calendar facts, so they are known in advance for any future month.

We selected the final model by **training AICc**, without looking at the test set, and checked residuals with Ljung-Box (lag 24).

## 3. Selected models and test results

| Series | Selected model | Ljung-Box p | Test MAPE | Test MASE | Best baseline (MASE) | Beats baseline? |
|---|---|---|---|---|---|---|
| Building & Garden | LM w/ ARIMA(1,1,1)(0,1,2)[12] errors | 0.40 | 7.9% | 2.10 | SNAIVE (1.14) | No |
| Clothing & Accessories | LM w/ ARIMA(2,0,3)(0,1,1)[12] errors | 0.91 | 3.9% | 0.91 | SNAIVE (1.29) | Yes |
| Health & Personal Care | LM w/ ARIMA(2,1,2)(0,1,1)[12] errors | 0.15 | 3.3% | 1.35 | Drift (2.44) | Yes |
| Macro Retail Total | LM w/ ARIMA(0,1,3)(0,1,1)[12] errors | 0.13 | 3.0% | 1.02 | SNAIVE (1.78) | Yes |

Results for all candidates are in `arima_accuracy_vs_baselines.csv`. On the test set alone, some other candidates scored slightly better. For example, the Box-Cox auto ARIMA reached a MASE of 0.83 for Clothing and 0.66 for Macro. Because those models fail the residual check or were not chosen by AICc, we report them only as sensitivity results.

## 4. What the forecasts show

- **Health & Personal Care:** the forecasts were very close for 2024 (0.1% off for the year) and 2025 (1.8% under). In 2026, actual sales flattened and came in about 7% below the forecast. Seasonal naive did badly here because it cannot follow Health's strong upward trend.
- **Building & Garden Supplies:** ARIMA over-forecast 2025 and 2026 by about 10%. The model projected the 2020 to 2022 growth forward, but sales went flat. The flat pattern favors seasonal naive, and this series is the best candidate for adding outside predictors such as mortgage rates and CPI.
- **Clothing & Accessories:** the forecasts tracked actual sales within 1% to 3% each year and captured the holiday peaks well.
- **Prediction intervals:** they were well calibrated. Between 84% and 100% of actual values fell inside the 80% intervals, and between 97% and 100% fell inside the 95% intervals.

## 5. Next steps

1. **ARIMAX:** add CPI, and mortgage rates for Building, on top of the trading-day regressors. This directly follows Makridakis et al. (2022), where external variables improved ARIMA by about 13%.
2. **Rolling-origin cross-validation:** replace the single 32-month test window, as discussed with the team.
3. **COVID intervention dummies** for March to May 2020. These months produce the largest residuals for Clothing, Health, and Macro.
4. **Combine forecasts** from ETS (Mia) and ARIMA.

## Files

| File | Contents |
|---|---|
| `arima_test_forecasts.csv` | Test forecasts for every model, with 80%/95% intervals and actual values |
| `arima_accuracy_vs_baselines.csv` | RMSE, MAE, MAPE, and MASE for all ARIMA models and baselines |
| `arima_model_specs.csv` | Model orders, AICc/BIC, Ljung-Box results, and test MASE |
| `arima_coefficients.csv` | All estimated coefficients |
| `stationarity_log_series.csv` | KPSS, ndiffs/nsdiffs, and Guerrero lambda |
| `arima_forward_forecast_2026_2027.csv` | Selected model refit on all data, forecasting Sep 2026 to Aug 2027 |
| `*.png` | Forecast plot, ACF/PACF plots, and residual diagnostics |

**Reproducibility:** baseline accuracy matches Section 5.1 exactly. Package versions are listed in `sessionInfo.txt` (fable 0.4.1). The team's machine may run newer versions, which can shift results slightly.

*Author: Ramin Fazli. AI disclosure (course requirement): AI assistance was used in drafting the code and this summary; all results were reviewed and validated by the author.*
