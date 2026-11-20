# ==============================================================================
# ADS 506 Final Team Project: Interactive Retail Demand Forecasting Dashboard
# Group 8: Mia Arnold, Jordan Blackman, Ramin Fazli
# ==============================================================================
# 
# Description:
# Interactive Shiny application supporting executive data storytelling (Deliverable 1)
# and technical exploration (Deliverable 2). Allows stakeholders to analyze historical
# U.S. retail sales across verticals, evaluate inflation deflation (CPI), inspect
# STL decomposition components, and generate multi-horizon forecasts with prediction
# intervals.
# ==============================================================================

library(shiny)
library(bslib)
library(tidyverse)
library(fpp3)
library(scales)

# ------------------------------------------------------------------------------
# 1. Data Ingestion & Preprocessing
# ------------------------------------------------------------------------------

# Load preprocessed tidy retail dataset
data_path <- file.path("data", "retail_data_clean.csv")
if (!file.exists(data_path)) {
  # Fallback for alternative working directories
  data_path <- "retail_data_clean.csv"
}

raw_df <- read_csv(data_path, show_col_types = FALSE)

# Convert to tsibble
retail_tsibble <- raw_df |>
  mutate(Month = yearmonth(Month)) |>
  as_tsibble(key = vertical, index = Month)

vertical_choices <- c(
  "Macro Retail Composite (Total)" = "macro_retail",
  "Health & Personal Care Stores (NAICS 446)" = "health",
  "Clothing & Accessories Stores (NAICS 448)" = "clothing",
  "Building & Garden Supplies Dealers (NAICS 444)" = "building"
)

# Benchmark scorecard summary data
benchmark_matrix <- tibble(
  Vertical = c("Building & Garden Supplies", "Clothing & Accessories", "Health & Personal Care", "Macro Retail Composite"),
  `Champion Specification` = c("3-Way Ensemble (ETS+ARIMA+TSLM)", "2-Way Ensemble (ETS+ARIMAX)", "ARIMAX with Trading Days", "2-Way Ensemble (ETS+ARIMAX)"),
  `Benchmark (SNAIVE)` = c("$2,756M CV / $2,153M Test", "$3,462M CV / $1,667M Test", "$1,616M CV / $4,505M Test", "$6,108M CV / $6,279M Test"),
  `Champion Accuracy` = c("$2,023M CV / $1,804M Test", "$3,384M CV / $956M Test", "$886M CV / $1,504M Test", "$4,360M CV / $1,970M Test"),
  `CV Error Reduction` = c("26.6%", "2.2%", "45.2%", "28.6%"),
  `Test Error Reduction` = c("16.2%", "42.6%", "66.6%", "68.6%"),
  `Status` = c("Champion Wins (Both)", "Champion Wins (Both)", "Champion Wins (Both)", "Champion Wins (Both)")
)

# ------------------------------------------------------------------------------
# 2. User Interface (UI)
# ------------------------------------------------------------------------------

ui <- page_sidebar(
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#1B4F72",
    secondary = "#5D6D7E",
    base_font = font_google("Inter")
  ),
  title = "U.S. Retail Sales Demand Forecasting Hub",
  
  sidebar = sidebar(
    title = "Controls & Parameters",
    selectInput(
      inputId = "vertical_select",
      label = "Retail Vertical / Sector:",
      choices = vertical_choices,
      selected = "macro_retail"
    ),
    radioButtons(
      inputId = "val_type",
      label = "Sales Valuation:",
      choices = c("Nominal Dollars ($M)" = "nominal", "Real (CPI-Deflated $M)" = "real"),
      selected = "nominal"
    ),
    sliderInput(
      inputId = "year_range",
      label = "Historical Window:",
      min = 1992,
      max = 2026,
      value = c(2010, 2026),
      step = 1,
      sep = ""
    ),
    hr(),
    h6("Forecast Simulation Controls"),
    selectInput(
      inputId = "fc_model",
      label = "Forecast Model:",
      choices = c(
        "Seasonal Naïve Baseline" = "snaive",
        "Exponential Smoothing (ETS)" = "ets",
        "Seasonal ARIMA" = "arima"
      ),
      selected = "ets"
    ),
    sliderInput(
      inputId = "fc_horizon",
      label = "Forecast Horizon (Months Ahead):",
      min = 6,
      max = 36,
      value = 24,
      step = 6
    ),
    markdown(
      "<small class='text-muted'>ADS 506 Applied Time Series Analysis<br>Group 8: Jordan Blackman, Mia Arnold, Ramin Fazli</small>"
    )
  ),
  
  # Main Display Area
  layout_columns(
    fill = FALSE,
    value_box(
      title = "Latest Reported Month",
      value = textOutput("vb_latest_month"),
      theme = "primary"
    ),
    value_box(
      title = "Latest Monthly Sales",
      value = textOutput("vb_latest_sales"),
      theme = "info"
    ),
    value_box(
      title = "YoY Growth (Nominal)",
      value = textOutput("vb_yoy_growth"),
      theme = "success"
    )
  ),
  
  navset_card_pill(
    nav_panel(
      title = "Historical Trajectory & Inflation",
      card_header("Nominal vs. Real Sales Trajectory (1992–2026)"),
      plotOutput("plot_historical", height = "450px"),
      markdown(
        "> **Key Takeaway:** Real CPI deflation reveals whether top-line revenue expansion represents genuine unit volume growth or price appreciation from macroeconomic monetary inflation."
      )
    ),
    nav_panel(
      title = "STL Decomposition",
      card_header("Trend-Cycle, 12-Month Seasonality & Remainder Shock Breakdown"),
      plotOutput("plot_stl", height = "520px"),
      markdown(
        "> **Key Takeaway:** Robust STL Loess decomposition isolates deterministic seasonal oscillations from long-term structural momentum and episodic outliers (e.g., April 2020 COVID lockdowns)."
      )
    ),
    nav_panel(
      title = "Seasonality Profile",
      card_header("Monthly Seasonal Cycle & Distribution"),
      plotOutput("plot_seasonal", height = "450px")
    ),
    nav_panel(
      title = "Multi-Horizon Forecasts",
      card_header("Out-of-Sample Production Projections with 80% & 95% Confidence Intervals"),
      plotOutput("plot_forecast", height = "480px"),
      markdown(
        "> **Methodology:** Point forecasts and shaded prediction intervals depict projected demand. In our full technical evaluation, multi-family ensembles outperform individual models across all retail sectors."
      )
    ),
    nav_panel(
      title = "Benchmark Scorecard",
      card_header("Champion Model vs. Seasonal Naïve Benchmark Evaluation Matrix"),
      tableOutput("table_benchmark"),
      markdown(
        "**Summary Findings:** Across all four retail series, our champion forecasting specifications outperform the Seasonal Naïve benchmark across **both** 13-fold rolling cross-validation and the 32-month test holdout set (100% win rate)."
      )
    )
  )
)

# ------------------------------------------------------------------------------
# 3. Server Logic
# ------------------------------------------------------------------------------

server <- function(input, output, session) {
  
  # Reactive subset of data based on user controls
  selected_data <- reactive({
    req(input$vertical_select, input$year_range)
    retail_tsibble |>
      filter(vertical == input$vertical_select) |>
      filter(year(Month) >= input$year_range[1] & year(Month) <= input$year_range[2])
  })
  
  # Value Boxes
  output$vb_latest_month <- renderText({
    latest_row <- retail_tsibble |>
      filter(vertical == input$vertical_select) |>
      slice_tail(n = 1)
    format(as.Date(latest_row$Month), "%b %Y")
  })
  
  output$vb_latest_sales <- renderText({
    latest_row <- retail_tsibble |>
      filter(vertical == input$vertical_select) |>
      slice_tail(n = 1)
    val <- if (input$val_type == "nominal") latest_row$sales_nominal else latest_row$sales_real
    paste0("$", comma(round(val), accuracy = 1), " M")
  })
  
  output$vb_yoy_growth <- renderText({
    series <- retail_tsibble |>
      filter(vertical == input$vertical_select) |>
      arrange(Month)
    n <- nrow(series)
    if (n > 12) {
      cur <- series$sales_nominal[n]
      prev <- series$sales_nominal[n - 12]
      growth <- (cur - prev) / prev
      percent(growth, accuracy = 0.1)
    } else {
      "N/A"
    }
  })
  
  # Plot 1: Historical Trajectory
  output$plot_historical <- renderPlot({
    df <- selected_data()
    y_var <- if (input$val_type == "nominal") "sales_nominal" else "sales_real"
    y_label <- if (input$val_type == "nominal") "Nominal Sales (USD Millions)" else "Real Sales (CPI Deflated, 1982-84 USD Millions)"
    
    p <- ggplot(df, aes(x = Month, y = .data[[y_var]])) +
      geom_line(color = "#1B4F72", linewidth = 0.9) +
      geom_point(color = "#2874A6", size = 1.2, alpha = 0.7) +
      scale_y_continuous(labels = dollar_format(suffix = "M")) +
      scale_x_yearmonth(date_breaks = "2 years", date_labels = "%Y") +
      labs(
        title = paste("Monthly Sales Trajectory:", names(vertical_choices)[vertical_choices == input$vertical_select]),
        subtitle = paste("Granularity: Monthly Not Seasonally Adjusted | Valuation:", input$val_type),
        x = "Month",
        y = y_label
      ) +
      theme_minimal(base_size = 13) +
      theme(
        plot.title = element_text(face = "bold", color = "#1B4F72"),
        panel.grid.minor = element_blank()
      )
    
    # If nominal selected, optionally overlay real as a secondary dashed line
    if (input$val_type == "nominal") {
      p <- p +
        geom_line(aes(y = sales_real, color = "Real Sales (CPI Deflated)"), linetype = "dashed", linewidth = 0.8) +
        scale_color_manual(name = "", values = c("Real Sales (CPI Deflated)" = "#7F8C8D")) +
        theme(legend.position = "top")
    }
    
    p
  })
  
  # Plot 2: STL Decomposition
  output$plot_stl <- renderPlot({
    df <- selected_data()
    y_var <- if (input$val_type == "nominal") "sales_nominal" else "sales_real"
    
    decomp <- df |>
      model(stl = STL(.data[[y_var]] ~ season(window = "periodic"))) |>
      components()
    
    autoplot(decomp) +
      scale_y_continuous(labels = dollar_format(suffix = "M")) +
      scale_x_yearmonth(date_breaks = "2 years", date_labels = "%Y") +
      labs(
        title = paste("STL Loess Decomposition:", names(vertical_choices)[vertical_choices == input$vertical_select]),
        subtitle = "Additive Trend + Periodic 12-Month Seasonality + Irregular Remainder"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        strip.text = element_text(face = "bold", color = "#1B4F72"),
        panel.grid.minor = element_blank()
      )
  })
  
  # Plot 3: Seasonal Profile
  output$plot_seasonal <- renderPlot({
    df <- selected_data()
    y_var <- if (input$val_type == "nominal") "sales_nominal" else "sales_real"
    
    df |>
      gg_season(.data[[y_var]], labels = "both") +
      scale_y_continuous(labels = dollar_format(suffix = "M")) +
      labs(
        title = paste("Seasonal Pattern by Calendar Month:", names(vertical_choices)[vertical_choices == input$vertical_select]),
        subtitle = "Lines depict individual years, illustrating seasonal consistency and holiday spikes",
        x = "Month",
        y = "Monthly Sales (USD Millions)"
      ) +
      theme_minimal(base_size = 13) +
      theme(
        legend.position = "none",
        plot.title = element_text(face = "bold", color = "#1B4F72")
      )
  })
  
  # Plot 4: Forecasts with Prediction Intervals
  output$plot_forecast <- renderPlot({
    df <- selected_data()
    y_var <- if (input$val_type == "nominal") "sales_nominal" else "sales_real"
    h_months <- input$fc_horizon
    
    fit <- switch(
      input$fc_model,
      "snaive" = df |> model(SNAIVE(.data[[y_var]])),
      "ets"    = df |> model(ETS(.data[[y_var]] ~ error("M") + trend("A") + season("M"))),
      "arima"  = df |> model(ARIMA(log(.data[[y_var]])))
    )
    
    fc <- fit |> forecast(h = paste(h_months, "months"))
    
    fc |>
      autoplot(df |> filter(year(Month) >= (input$year_range[2] - 5)), level = c(80, 95)) +
      scale_y_continuous(labels = dollar_format(suffix = "M")) +
      scale_x_yearmonth(date_breaks = "1 year", date_labels = "%Y") +
      labs(
        title = paste("Out-of-Sample Production Forecast:", names(vertical_choices)[vertical_choices == input$vertical_select]),
        subtitle = paste("Model:", toupper(input$fc_model), "| Horizon:", h_months, "Months Ahead | Ribbons: 80% & 95% Confidence Intervals"),
        x = "Month",
        y = "Monthly Sales (USD Millions)"
      ) +
      theme_minimal(base_size = 13) +
      theme(
        plot.title = element_text(face = "bold", color = "#1B4F72"),
        legend.position = "bottom"
      )
  })
  
  # Table 5: Benchmark Scorecard
  output$table_benchmark <- renderTable({
    benchmark_matrix
  }, striped = TRUE, hover = TRUE, bordered = TRUE)
  
}

# ------------------------------------------------------------------------------
# 4. App Launch
# ------------------------------------------------------------------------------

shinyApp(ui = ui, server = server)
