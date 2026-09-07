# Shared helpers for the pre-rendered (knitr) parts of every page. The live R
# and Python cells run in the visitor's browser and do not see this file.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(htmltools)
})

vars <- read_csv("data/variables.csv", show_col_types = FALSE)
institutions <- read_csv("data/institutions.csv", show_col_types = FALSE)

# A variable chip: monospace name with the IPEDS label and source on hover.
# Use inline as `r v("grad_rate_bach_6yr")`.
v <- function(name) {
  row <- vars[vars$variable == name, ]
  if (nrow(row) != 1) stop("Unknown variable: ", name)
  as.character(tags$code(
    class = "v",
    tabindex = "0",
    `data-label` = paste0(row$label, " · ", row$source, " ", row$ipeds),
    name
  ))
}

# Comma-formatted integer for prose.
fmt <- function(x) format(x, big.mark = ",", trim = TRUE)
