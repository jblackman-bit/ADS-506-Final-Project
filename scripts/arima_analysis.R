# ==============================================================================
# ADS 506 Group 8: Section 5.4 Seasonal ARIMA & Box-Jenkins (Owner: Ramin Fazli)
# Data: data/retail_data_clean.csv (FRED/Census MRTS, Jan 1992 - Aug 2026)
# Train: Jan 1992 - Dec 2023 | Test: Jan 2024 - Aug 2026 (32 months)
# Run from the repo root:  Rscript scripts/arima_analysis.R . outputs/arima
# Author: Ramin Fazli. AI disclosure (course requirement): AI assistance was used
# in drafting this code; reviewed and validated by Ramin Fazli.
# ==============================================================================
# Requires: fable, feasts, tsibble, fabletools, dplyr, tidyr, readr, ggplot2, lubridate, scales
suppressPackageStartupMessages({
  library(fable); library(feasts); library(tsibble); library(fabletools)
  library(dplyr); library(tidyr); library(readr); library(ggplot2)
})
args <- commandArgs(trailingOnly = TRUE)
repo <- if (length(args) >= 1) args[1] else "."
out  <- if (length(args) >= 2) args[2] else "outputs/arima"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
set.seed(506)

retail_ts <- read_csv(file.path(repo, "data/retail_data_clean.csv"), show_col_types = FALSE) |>
  mutate(Month = yearmonth(Month)) |>
  as_tsibble(index = Month, key = vertical)

# Trading-day calendar regressors: number of each weekday in the month.
# Not-seasonally-adjusted retail sales depend on how many Fridays/Saturdays a month has.
count_wday <- function(m, k) {
  s <- as.Date(m); n <- lubridate::days_in_month(s)
  vapply(seq_along(s), function(i) sum(lubridate::wday(s[i] + 0:(n[i] - 1)) == k), numeric(1))
}
retail_ts <- retail_ts |>
  mutate(td_mon = count_wday(Month, 2) - count_wday(Month, 1),
         td_tue = count_wday(Month, 3) - count_wday(Month, 1),
         td_wed = count_wday(Month, 4) - count_wday(Month, 1),
         td_thu = count_wday(Month, 5) - count_wday(Month, 1),
         td_fri = count_wday(Month, 6) - count_wday(Month, 1),
         td_sat = count_wday(Month, 7) - count_wday(Month, 1),
         days_in_month = as.numeric(lubridate::days_in_month(as.Date(Month))))

train_data <- retail_ts |> filter(Month <  yearmonth("2024 Jan"))
test_data  <- retail_ts |> filter(Month >= yearmonth("2024 Jan"))
labels <- retail_ts |> as_tibble() |> distinct(vertical, vertical_name)

# ------------------------------------------------------------------------------
# 1. Stationarity checks on the variance-stabilised (log) series
# ------------------------------------------------------------------------------
lambdas <- train_data |> features(sales_nominal, guerrero)
nsd <- train_data |> features(log(sales_nominal), unitroot_nsdiffs)
seas_diff <- train_data |> group_by_key() |>
  mutate(log_d12 = difference(log(sales_nominal), 12)) |> ungroup()
nd   <- seas_diff |> features(log_d12, unitroot_ndiffs)
kpss <- seas_diff |> features(log_d12, unitroot_kpss)
stationarity <- lambdas |> inner_join(nsd, by = "vertical") |>
  inner_join(nd, by = "vertical") |> inner_join(kpss, by = "vertical") |>
  left_join(labels, by = "vertical")
write_csv(stationarity, file.path(out, "stationarity_log_series.csv"))

# ACF/PACF of the differenced log series (used to pick manual orders)
for (v in unique(train_data$vertical)) {
  dvar <- if (nd$ndiffs[nd$vertical == v] >= 1) "first + seasonal" else "seasonal"
  s <- seas_diff |> filter(vertical == v) |> group_by_key() |>
    mutate(y = if (dvar == "first + seasonal") difference(log_d12) else log_d12) |> ungroup()
  p <- s |> gg_tsdisplay(y, plot_type = "partial", lag_max = 36) +
    labs(title = paste0(labels$vertical_name[labels$vertical == v],
                        ": log sales after ", dvar, " differencing"))
  ggsave(file.path(out, paste0("acf_pacf_", v, ".png")), p, width = 9, height = 6, dpi = 150)
}

# ------------------------------------------------------------------------------
# 2. Candidate ARIMA models (automated + manual, Box-Jenkins)
#    Manual orders come from the ACF/PACF above:
#    - Health, Building, Macro: d=1, D=1; lag-1/2 negative ACF + seasonal MA
#    - Clothing: d=0, D=1; PACF cuts off after lag 1-2, seasonal ACF spike at 12
# ------------------------------------------------------------------------------
lam <- setNames(lambdas$lambda_guerrero, lambdas$vertical)

fit_one <- function(v) {
  tr <- train_data |> filter(vertical == v)
  lv <- lam[[v]]
  if (v == "clothing") {
    tr |> model(
      auto_log      = ARIMA(log(sales_nominal)),
      auto_log_full = ARIMA(log(sales_nominal), stepwise = FALSE, approximation = FALSE),
      auto_boxcox   = ARIMA(box_cox(sales_nominal, lv)),
      arima_tradingday = ARIMA(log(sales_nominal) ~ td_mon + td_tue + td_wed + td_thu + td_fri + td_sat + days_in_month),
      manual_a      = ARIMA(log(sales_nominal) ~ 1 + pdq(2, 0, 0) + PDQ(0, 1, 1)),
      manual_b      = ARIMA(log(sales_nominal) ~ 1 + pdq(1, 0, 1) + PDQ(0, 1, 1)),
      airline       = ARIMA(log(sales_nominal) ~ 0 + pdq(0, 1, 1) + PDQ(0, 1, 1))
    )
  } else {
    tr |> model(
      auto_log      = ARIMA(log(sales_nominal)),
      auto_log_full = ARIMA(log(sales_nominal), stepwise = FALSE, approximation = FALSE),
      auto_boxcox   = ARIMA(box_cox(sales_nominal, lv)),
      arima_tradingday = ARIMA(log(sales_nominal) ~ td_mon + td_tue + td_wed + td_thu + td_fri + td_sat + days_in_month),
      manual_a      = ARIMA(log(sales_nominal) ~ 0 + pdq(2, 1, 0) + PDQ(0, 1, 1)),
      manual_b      = ARIMA(log(sales_nominal) ~ 0 + pdq(0, 1, 2) + PDQ(0, 1, 1)),
      airline       = ARIMA(log(sales_nominal) ~ 0 + pdq(0, 1, 1) + PDQ(0, 1, 1))
    )
  }
}
fits_arima <- bind_rows(lapply(unique(train_data$vertical), fit_one))

baseline_fits <- train_data |> model(
  snaive = SNAIVE(sales_nominal),
  drift  = RW(sales_nominal ~ drift())
)

# Model specifications + information criteria
spec_tbl <- fits_arima |>
  pivot_longer(-vertical, names_to = ".model", values_to = "fit") |>
  mutate(specification = vapply(fit, function(m) format(m), character(1))) |>
  as_tibble() |> select(vertical, .model, specification) |>
  left_join(glance(fits_arima) |> select(vertical, .model, sigma2, log_lik, AIC, AICc, BIC),
            by = c("vertical", ".model"))

# ------------------------------------------------------------------------------
# 3. Residual diagnostics: Ljung-Box (lag 24, dof = number of ARMA terms)
# ------------------------------------------------------------------------------
n_coef <- tidy(fits_arima) |> filter(!grepl("^td_|days_in_month|constant|intercept", term)) |> count(vertical, .model, name = "dof")
lb <- augment(fits_arima) |> as_tibble() |> filter(!is.na(.innov)) |>
  left_join(n_coef, by = c("vertical", ".model")) |>
  group_by(vertical, .model) |>
  summarise(lb_stat = Box.test(.innov, lag = 24, type = "Ljung-Box", fitdf = first(dof))$statistic,
            lb_pvalue = Box.test(.innov, lag = 24, type = "Ljung-Box", fitdf = first(dof))$p.value,
            .groups = "drop")
spec_tbl <- spec_tbl |> left_join(lb, by = c("vertical", ".model"))
write_csv(tidy(fits_arima), file.path(out, "arima_coefficients.csv"))

# ------------------------------------------------------------------------------
# 4. Out-of-sample forecasts (32 months) and accuracy vs. baselines
# ------------------------------------------------------------------------------
fc_arima <- fits_arima |> forecast(new_data = test_data)
fc_base  <- baseline_fits |> forecast(new_data = test_data)

acc <- bind_rows(accuracy(fc_arima, retail_ts), accuracy(fc_base, retail_ts)) |>
  select(vertical, .model, RMSE, MAE, MAPE, MASE) |>
  left_join(labels, by = "vertical") |>
  group_by(vertical) |>
  mutate(best_baseline_MASE = min(MASE[.model %in% c("snaive", "drift")]),
         beats_best_baseline = MASE < best_baseline_MASE,
         rank_by_MASE = rank(MASE)) |>
  ungroup() |> arrange(vertical, MASE)
write_csv(acc, file.path(out, "arima_accuracy_vs_baselines.csv"))

spec_tbl <- spec_tbl |> left_join(acc |> select(vertical, .model, MASE), by = c("vertical", ".model"))
write_csv(spec_tbl, file.path(out, "arima_model_specs.csv"))

# Selected model per vertical = lowest test MASE among ARIMA candidates
best <- acc |> filter(!.model %in% c("snaive", "drift")) |>
  group_by(vertical) |> slice_min(MASE, n = 1, with_ties = FALSE) |> ungroup() |>
  select(vertical, best_model = .model)
# Model chosen WITHOUT peeking at the test set = lowest training AICc among the log-scale models
# (Box-Cox models are excluded: AICc is not comparable across different transformations)
best_aicc <- spec_tbl |> filter(.model != "auto_boxcox") |>
  group_by(vertical) |> slice_min(AICc, n = 1, with_ties = FALSE) |> ungroup() |>
  select(vertical, aicc_model = .model)
write_csv(best |> left_join(best_aicc, by = "vertical"), file.path(out, "selected_models.csv"))

# Save forecasts with 80% / 95% intervals, joined with actuals
save_fc <- function(fc) {
  fc |> mutate(lo80 = quantile(sales_nominal, 0.10), hi80 = quantile(sales_nominal, 0.90),
               lo95 = quantile(sales_nominal, 0.025), hi95 = quantile(sales_nominal, 0.975)) |>
    as_tibble() |>
    transmute(vertical, .model, Month = format(Month), forecast = .mean, lo80, hi80, lo95, hi95)
}
fc_out <- bind_rows(save_fc(fc_arima), save_fc(fc_base)) |>
  left_join(test_data |> as_tibble() |> transmute(vertical, Month = format(Month), actual = sales_nominal),
            by = c("vertical", "Month"))
write_csv(fc_out, file.path(out, "arima_test_forecasts.csv"))

# Coverage of 95% intervals for the AICc-selected models
coverage <- fc_out |> inner_join(best_aicc, by = c("vertical", ".model" = "aicc_model")) |>
  group_by(vertical, .model) |>
  summarise(cover95 = mean(actual >= lo95 & actual <= hi95),
            cover80 = mean(actual >= lo80 & actual <= hi80),
            mean_pct_error = mean((actual - forecast) / actual) * 100, .groups = "drop")
write_csv(coverage, file.path(out, "interval_coverage.csv"))

# ------------------------------------------------------------------------------
# 5. Plots
# ------------------------------------------------------------------------------
sel <- fc_out |> inner_join(best_aicc, by = c("vertical", ".model" = "aicc_model")) |>
  mutate(Month = yearmonth(Month))
snv <- fc_out |> filter(.model == "snaive") |> mutate(Month = yearmonth(Month))
hist <- retail_ts |> as_tibble() |> filter(Month >= yearmonth("2019 Jan"))
nm <- setNames(labels$vertical_name, labels$vertical)
p <- ggplot() +
  geom_ribbon(data = sel, aes(x = Month, ymin = lo95, ymax = hi95), fill = "#2b6cb0", alpha = 0.15) +
  geom_ribbon(data = sel, aes(x = Month, ymin = lo80, ymax = hi80), fill = "#2b6cb0", alpha = 0.25) +
  geom_line(data = snv, aes(x = Month, y = forecast, colour = "Seasonal naive (baseline)"), linetype = "dashed") +
  geom_line(data = sel, aes(x = Month, y = forecast, colour = "ARIMA forecast")) +
  geom_line(data = hist, aes(x = Month, y = sales_nominal, colour = "Actual sales")) +
  geom_vline(xintercept = as.Date(yearmonth("2024 Jan")), linetype = "dotted", colour = "grey50") +
  scale_colour_manual(values = c("Actual sales" = "black", "ARIMA forecast" = "#2b6cb0",
                                 "Seasonal naive (baseline)" = "grey55"), name = NULL) +
  facet_wrap(vars(vertical), scales = "free_y", ncol = 1, labeller = as_labeller(nm)) +
  scale_y_continuous(labels = scales::label_dollar(suffix = "M")) +
  labs(title = "Seasonal ARIMA (with trading-day regressors) vs. actual sales",
       subtitle = "Trained on Jan 1992 - Dec 2023; tested on Jan 2024 - Aug 2026. Shaded = 80% / 95% prediction intervals.",
       y = "Monthly sales (USD millions)", x = NULL) +
  theme_minimal(base_size = 11) + theme(legend.position = "top")
ggsave(file.path(out, "arima_forecasts_vs_actuals.png"), p, width = 10, height = 11, dpi = 150)

for (i in seq_len(nrow(best_aicc))) {
  v <- best_aicc$vertical[i]; m <- best_aicc$aicc_model[i]
  r <- fits_arima |> filter(vertical == v) |> select(vertical, all_of(m))
  pr <- gg_tsresiduals(r, lag_max = 36) +
    labs(title = paste0(labels$vertical_name[labels$vertical == v], ": residuals of ", m))
  ggsave(file.path(out, paste0("residuals_", v, ".png")), pr, width = 9, height = 6, dpi = 150)
}

# ------------------------------------------------------------------------------
# 6. Forward forecast (Sep 2026 - Aug 2027): refit AICc-selected spec on all data
# ------------------------------------------------------------------------------
fwd <- bind_rows(lapply(seq_len(nrow(best_aicc)), function(i) {
  v <- best_aicc$vertical[i]; m <- best_aicc$aicc_model[i]
  # refit() keeps the selected (p,d,q)(P,D,Q) orders and re-estimates coefficients on all data
  f <- fits_arima |> filter(vertical == v) |> select(vertical, all_of(m)) |>
    refit(retail_ts |> filter(vertical == v), reestimate = TRUE)
  future <- new_data(retail_ts |> filter(vertical == v), 12) |>
    mutate(td_mon = count_wday(Month, 2) - count_wday(Month, 1),
           td_tue = count_wday(Month, 3) - count_wday(Month, 1),
           td_wed = count_wday(Month, 4) - count_wday(Month, 1),
           td_thu = count_wday(Month, 5) - count_wday(Month, 1),
           td_fri = count_wday(Month, 6) - count_wday(Month, 1),
           td_sat = count_wday(Month, 7) - count_wday(Month, 1),
           days_in_month = as.numeric(lubridate::days_in_month(as.Date(Month))))
  f <- f |> forecast(new_data = future)
  save_fc(f) |> mutate(.model = paste0(m, " (refit on 1992-2026)"))
}))
write_csv(fwd, file.path(out, "arima_forward_forecast_2026_2027.csv"))

writeLines(capture.output(sessionInfo()), file.path(out, "sessionInfo.txt"))
cat("Done. Outputs in", out, "\n")
