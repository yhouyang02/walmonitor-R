library(shiny)
library(bslib)
library(dplyr)
library(ggplot2)
library(readr)
library(lubridate)
library(forcats)
library(scales)

## Data
data_raw <- read_csv(
  "data/walmart_sales_data.csv",
  show_col_types = FALSE
) |>
  mutate(Date = as.Date(Date))

comparison_choices <- c(
  "Product line" = "Product line",
  "Payment" = "Payment",
  "Gender" = "Gender",
  "Customer type" = "Customer type"
)

branch_choices <- c("All" = "all", sort(unique(data_raw$Branch)))


## UI
ui <- page_sidebar(
  title = div(
    "Walmonitor-R 0.1.0",
    style = "font-size: 32px; font-weight: 700;"
  ),
  sidebar = sidebar(
    open = "open",

    # Control bar
    div("Controls", style = "font-size: 22px;"),
    dateRangeInput(
      "date_range",
      "Date range",
      start = as.Date("2019-02-01"),
      end   = as.Date("2019-03-30"),
      min   = min(data_raw$Date, na.rm = TRUE),
      max   = max(data_raw$Date, na.rm = TRUE)
    ),
    selectInput(
      "branch",
      "Branch",
      choices = branch_choices,
      selected = "all"
    ),
    selectInput(
      "comparison",
      "Compare by",
      choices = comparison_choices,
      selected = "Product line"
    )
  ),

  # Plots
  layout_columns(
    col_widths = c(7, 5),
    card(
      card_header("Sales Mix Over Time"),
      plotOutput("sales_mix_plot")
    ),
    card(
      card_header("Ranked Sales"),
      plotOutput("ranked_bar_plot")
    )
  )
)


## Server
server <- function(input, output, session) {
  weekly_sales_by_group <- reactive({
    comp_col <- input$comparison

    df <- data_raw |>
      filter(
        Date >= input$date_range[1],
        Date <= input$date_range[2]
      )

    if (input$branch != "all") {
      df <- df |> filter(Branch == input$branch)
    }

    df |>
      select(Date, all_of(comp_col), Total) |>
      mutate(
        week = floor_date(Date, unit = "week", week_start = 1)
      ) |>
      group_by(week, .data[[comp_col]]) |>
      summarise(
        total = sum(Total, na.rm = TRUE),
        .groups = "drop"
      ) |>
      rename(category = all_of(comp_col)) |>
      arrange(week, category)
  })

  output$sales_mix_plot <- renderPlot({
    df <- weekly_sales_by_group()

    ggplot(df, aes(x = week, y = total, fill = category)) +
      geom_area(position = "stack", alpha = 0.9) +
      scale_y_continuous(labels = label_number(big.mark = ",")) +
      labs(
        x = "Week Start",
        y = "Total Weekly Sales",
        fill = NULL
      ) +
      theme_minimal(base_size = 18) + 
        theme(
            legend.position = "bottom",
            axis.title = element_text(size = 18),
            axis.text = element_text(size = 18)
        )
  })

  output$ranked_bar_plot <- renderPlot({
    df <- weekly_sales_by_group()

    ranked <- df |>
      group_by(category) |>
      summarise(
        total = sum(total, na.rm = TRUE),
        .groups = "drop"
      ) |>
      arrange(desc(total))

    if (nrow(ranked) > 6) {
      top6 <- ranked |> slice_head(n = 6)
      other <- ranked |>
        slice(-(1:6)) |>
        summarise(
          category = "Other",
          total = sum(total, na.rm = TRUE)
        )
      ranked <- bind_rows(top6, other)
    }

    ranked <- ranked |>
      mutate(category = fct_reorder(category, total))

    ggplot(ranked, aes(x = total, y = category, fill = category)) +
      geom_col(show.legend = FALSE) +
      scale_x_continuous(labels = label_number(big.mark = ",")) +
      labs(
        x = "Total Weekly Sales",
        y = NULL
      ) +
      theme_minimal(base_size = 16) + 
        theme(
            axis.title = element_text(size = 16),
            axis.text = element_text(size = 16)
        )
  })
}

shinyApp(ui, server)