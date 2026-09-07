# Writes data/ir-lab.xlsx: the institutions table plus one worked sheet per
# lesson, built with plain Excel formulas so the "In your stack" tabs can point
# at real cells. Called from build_data.R.

build_workbook <- function(institutions, variables, path) {
  library(openxlsx)

  wb <- createWorkbook()
  hdr <- createStyle(fontName = "Aptos", fontSize = 11, textDecoration = "bold",
                     fgFill = "#e8eef8", border = "bottom", borderColour = "#9fb3d1")
  note <- createStyle(fontName = "Aptos", fontSize = 10, fontColour = "#4a5158",
                      wrapText = TRUE, valign = "top")
  title <- createStyle(fontName = "Aptos", fontSize = 14, textDecoration = "bold")
  mono <- createStyle(fontName = "Consolas", fontSize = 10)
  num1 <- createStyle(numFmt = "0.0")
  num2 <- createStyle(numFmt = "0.00")

  # ---- read-me --------------------------------------------------------
  addWorksheet(wb, "read-me")
  writeData(wb, "read-me", "IR Lab workbook", startRow = 1)
  addStyle(wb, "read-me", title, rows = 1, cols = 1)
  writeData(wb, "read-me", paste(
    "One row per U.S. institution from the IPEDS 2023-24 collection.",
    "The sheet 'institutions' is an Excel Table named Institutions, so formulas can use",
    "structured references such as Institutions[grad_rate_bach_6yr].",
    "Each lesson sheet works its method with ordinary Excel formulas on the same data."
  ), startRow = 2)
  addStyle(wb, "read-me", note, rows = 2, cols = 1)
  setRowHeights(wb, "read-me", rows = 2, heights = 48)
  writeData(wb, "read-me", as.data.frame(variables), startRow = 4, headerStyle = hdr)
  addStyle(wb, "read-me", mono, rows = 5:(4 + nrow(variables)), cols = 1:3, gridExpand = TRUE)
  setColWidths(wb, "read-me", cols = 1:4, widths = c(22, 12, 28, 80))

  # ---- institutions ---------------------------------------------------
  addWorksheet(wb, "institutions")
  writeDataTable(wb, "institutions", as.data.frame(institutions),
                 tableName = "Institutions", tableStyle = "TableStyleLight9")
  setColWidths(wb, "institutions", cols = 1:ncol(institutions), widths = 16)
  setColWidths(wb, "institutions", cols = 2, widths = 44)
  freezePane(wb, "institutions", firstActiveRow = 2, firstActiveCol = 3)

  # ---- distributions --------------------------------------------------
  # Six-year bachelor's completion at 4-year institutions: summary stats and a
  # binned frequency table, all COUNTIFS on the table.
  addWorksheet(wb, "distributions")
  ws <- "distributions"
  writeData(wb, ws, "Shape of a distribution: 6-year bachelor's completion, 4-year institutions", startRow = 1)
  addStyle(wb, ws, title, rows = 1, cols = 1)
  writeData(wb, ws, paste(
    "Column B filters the table to 4-year institutions with a reported rate.",
    "The frequency table uses COUNTIFS on the same table, so it updates if the data does."
  ), startRow = 2)
  addStyle(wb, ws, note, rows = 2, cols = 1)
  mergeCells(wb, ws, cols = 1:4, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 36)

  stats <- data.frame(
    Statistic = c("Count", "Mean", "Median", "Standard deviation", "Skewness",
                  "Minimum", "25th percentile", "75th percentile", "Maximum"),
    Formula = c(
      "=COUNTIFS(Institutions[level],\"4-year\",Institutions[grad_rate_bach_6yr],\"<>\")",
      "=AVERAGEIFS(Institutions[grad_rate_bach_6yr],Institutions[level],\"4-year\")",
      "=MEDIAN(IF(Institutions[level]=\"4-year\",Institutions[grad_rate_bach_6yr]))",
      "=STDEV.S(IF(Institutions[level]=\"4-year\",Institutions[grad_rate_bach_6yr]))",
      "=SKEW(IF(Institutions[level]=\"4-year\",Institutions[grad_rate_bach_6yr]))",
      "=MINIFS(Institutions[grad_rate_bach_6yr],Institutions[level],\"4-year\")",
      "=PERCENTILE.INC(IF(Institutions[level]=\"4-year\",Institutions[grad_rate_bach_6yr]),0.25)",
      "=PERCENTILE.INC(IF(Institutions[level]=\"4-year\",Institutions[grad_rate_bach_6yr]),0.75)",
      "=MAXIFS(Institutions[grad_rate_bach_6yr],Institutions[level],\"4-year\")"
    )
  )
  writeData(wb, ws, "Summary", startRow = 4, startCol = 1)
  addStyle(wb, ws, hdr, rows = 4, cols = 1:2)
  writeData(wb, ws, "Value", startRow = 4, startCol = 2)
  addStyle(wb, ws, hdr, rows = 4, cols = 2)
  writeData(wb, ws, stats$Statistic, startRow = 5, startCol = 1)
  for (i in seq_len(nrow(stats))) {
    writeFormula(wb, ws, stats$Formula[i], startRow = 4 + i, startCol = 2)
  }
  addStyle(wb, ws, num1, rows = 5:13, cols = 2)

  writeData(wb, ws, "Bin (from)", startRow = 4, startCol = 4)
  writeData(wb, ws, "Bin (to)", startRow = 4, startCol = 5)
  writeData(wb, ws, "Institutions", startRow = 4, startCol = 6)
  writeData(wb, ws, "Share", startRow = 4, startCol = 7)
  addStyle(wb, ws, hdr, rows = 4, cols = 4:7)
  lows <- seq(0, 90, by = 10)
  writeData(wb, ws, lows, startRow = 5, startCol = 4)
  writeData(wb, ws, lows + 10, startRow = 5, startCol = 5)
  for (i in seq_along(lows)) {
    r <- 4 + i
    op_hi <- if (i == length(lows)) "\"<=\"" else "\"<\""
    writeFormula(wb, ws, sprintf(
      "=COUNTIFS(Institutions[level],\"4-year\",Institutions[grad_rate_bach_6yr],\">=\"&D%d,Institutions[grad_rate_bach_6yr],%s&E%d)",
      r, op_hi, r), startRow = r, startCol = 6)
    writeFormula(wb, ws, sprintf("=F%d/$B$5", r), startRow = r, startCol = 7)
  }
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 5:14, cols = 7)
  writeData(wb, ws, paste(
    "Insert > Chart > Column on D4:F14 for the histogram.",
    "Excel's Histogram chart (Insert > Statistic Chart) bins for you but does not accept a filter,",
    "so copy the filtered column first or use this table."
  ), startRow = 16, startCol = 4)
  addStyle(wb, ws, note, rows = 16, cols = 4)
  mergeCells(wb, ws, cols = 4:8, rows = 16)
  setRowHeights(wb, ws, rows = 16, heights = 48)
  setColWidths(wb, ws, cols = 1:7, widths = c(22, 12, 3, 12, 12, 14, 10))

  # ---- regression -----------------------------------------------------
  reg <- institutions |>
    dplyr::filter(level == "4-year", !is.na(pct_pell), !is.na(grad_rate_bach_6yr),
                  bach_cohort >= 30) |>
    dplyr::select(unitid, name, control, pct_pell, grad_rate_bach_6yr) |>
    as.data.frame()
  n <- nrow(reg)
  last <- n + 1
  addWorksheet(wb, "regression")
  ws <- "regression"
  writeData(wb, ws, reg, startRow = 1, startCol = 1, headerStyle = hdr)
  writeData(wb, ws, "predicted", startRow = 1, startCol = 6)
  writeData(wb, ws, "residual", startRow = 1, startCol = 7)
  addStyle(wb, ws, hdr, rows = 1, cols = 6:7)
  writeFormula(wb, ws, sprintf("=$K$5+$K$4*D%d", 2:last), startRow = 2, startCol = 6)
  writeFormula(wb, ws, sprintf("=E%d-F%d", 2:last, 2:last), startRow = 2, startCol = 7)
  addStyle(wb, ws, num1, rows = 2:last, cols = 6:7, gridExpand = TRUE)

  writeData(wb, ws, "Simple linear regression", startRow = 1, startCol = 10)
  addStyle(wb, ws, title, rows = 1, cols = 10)
  writeData(wb, ws, paste(
    "y = 6-year bachelor's completion (column E), x = percent Pell (column D),",
    "4-year institutions with a bachelor's cohort of at least 30."
  ), startRow = 2, startCol = 10)
  addStyle(wb, ws, note, rows = 2, cols = 10)
  mergeCells(wb, ws, cols = 10:13, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 36)
  labels <- c("n", "Slope", "Intercept", "r", "R squared", "Standard error of estimate",
              "Slope standard error", "t statistic for slope")
  forms <- c(
    sprintf("=COUNT(D2:D%d)", last),
    sprintf("=SLOPE(E2:E%d,D2:D%d)", last, last),
    sprintf("=INTERCEPT(E2:E%d,D2:D%d)", last, last),
    sprintf("=CORREL(D2:D%d,E2:E%d)", last, last),
    sprintf("=RSQ(E2:E%d,D2:D%d)", last, last),
    sprintf("=STEYX(E2:E%d,D2:D%d)", last, last),
    sprintf("=INDEX(LINEST(E2:E%d,D2:D%d,TRUE,TRUE),2,1)", last, last),
    "=K4/K9"
  )
  writeData(wb, ws, labels, startRow = 3, startCol = 10)
  for (i in seq_along(forms)) writeFormula(wb, ws, forms[i], startRow = 2 + i, startCol = 11)
  addStyle(wb, ws, num2, rows = 4:10, cols = 11)
  writeData(wb, ws, "LINEST output (5 rows x 2 columns)", startRow = 13, startCol = 10)
  addStyle(wb, ws, hdr, rows = 13, cols = 10:11)
  writeFormula(wb, ws, sprintf("LINEST(E2:E%d,D2:D%d,TRUE,TRUE)", last, last),
               startRow = 14, startCol = 10, array = TRUE)
  writeData(wb, ws, c("slope | intercept", "se slope | se intercept", "R2 | se of y",
                      "F | df", "SS regression | SS residual"), startRow = 14, startCol = 12)
  addStyle(wb, ws, note, rows = 14:18, cols = 12)
  writeData(wb, ws, paste(
    "Data > Data Analysis > Regression gives the same numbers with a full ANOVA table.",
    "Insert > Scatter on D:E, then Chart Elements > Trendline > Display equation."
  ), startRow = 20, startCol = 10)
  addStyle(wb, ws, note, rows = 20, cols = 10)
  mergeCells(wb, ws, cols = 10:13, rows = 20)
  setRowHeights(wb, ws, rows = 20, heights = 48)
  setColWidths(wb, ws, cols = 1:13, widths = c(9, 40, 18, 10, 18, 11, 10, 3, 3, 26, 12, 12, 24))
  freezePane(wb, ws, firstActiveRow = 2)

  # ---- clustering -----------------------------------------------------
  # k-means by hand, two variables, k = 3, two iterations laid out side by side.
  set.seed(2023)
  cl <- institutions |>
    dplyr::filter(level == "4-year", control != "Private for-profit",
                  !is.na(pct_pell), !is.na(net_price), !is.na(grad_rate_bach_6yr),
                  bach_cohort >= 100) |>
    dplyr::select(unitid, name, control, pct_pell, grad_rate_bach_6yr) |>
    dplyr::slice_sample(n = 400) |>
    dplyr::arrange(unitid) |>
    as.data.frame()
  n <- nrow(cl)
  last <- n + 1
  addWorksheet(wb, "clustering")
  ws <- "clustering"
  writeData(wb, ws, cl, startRow = 1, startCol = 1, headerStyle = hdr)
  heads <- c("z_pell", "z_grad", "d to A", "d to B", "d to C", "cluster (iter 1)",
             "d to A", "d to B", "d to C", "cluster (iter 2)")
  writeData(wb, ws, t(heads), startRow = 1, startCol = 6, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 1, cols = 6:15)
  rows <- 2:last
  writeFormula(wb, ws, sprintf("=STANDARDIZE(D%d,AVERAGE($D$2:$D$%d),STDEV.S($D$2:$D$%d))", rows, last, last),
               startRow = 2, startCol = 6)
  writeFormula(wb, ws, sprintf("=STANDARDIZE(E%d,AVERAGE($E$2:$E$%d),STDEV.S($E$2:$E$%d))", rows, last, last),
               startRow = 2, startCol = 7)
  # iteration 1 distances against centroids in R4:S6
  for (k in 1:3) {
    writeFormula(wb, ws, sprintf("=SQRT((F%d-$R$%d)^2+(G%d-$S$%d)^2)", rows, 3 + k, rows, 3 + k),
                 startRow = 2, startCol = 7 + k)
  }
  writeFormula(wb, ws, sprintf("=CHOOSE(MATCH(MIN(H%d:J%d),H%d:J%d,0),\"A\",\"B\",\"C\")", rows, rows, rows, rows),
               startRow = 2, startCol = 11)
  # iteration 2 distances against updated centroids in R10:S12
  for (k in 1:3) {
    writeFormula(wb, ws, sprintf("=SQRT((F%d-$R$%d)^2+(G%d-$S$%d)^2)", rows, 9 + k, rows, 9 + k),
                 startRow = 2, startCol = 11 + k)
  }
  writeFormula(wb, ws, sprintf("=CHOOSE(MATCH(MIN(L%d:N%d),L%d:N%d,0),\"A\",\"B\",\"C\")", rows, rows, rows, rows),
               startRow = 2, startCol = 15)
  addStyle(wb, ws, num2, rows = rows, cols = c(6:10, 12:14), gridExpand = TRUE)

  writeData(wb, ws, "k-means by hand (k = 3)", startRow = 1, startCol = 17)
  addStyle(wb, ws, title, rows = 1, cols = 17)
  writeData(wb, ws, "Starting centroids (rows 2, 150, 300 of the standardized data)", startRow = 2, startCol = 17)
  addStyle(wb, ws, note, rows = 2, cols = 17)
  writeData(wb, ws, t(c("centroid", "z_pell", "z_grad", "members")), startRow = 3, startCol = 17, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 3, cols = 17:20)
  writeData(wb, ws, c("A", "B", "C"), startRow = 4, startCol = 17)
  seeds <- c(2, 150, 300)
  for (k in 1:3) {
    writeFormula(wb, ws, sprintf("=F%d", seeds[k]), startRow = 3 + k, startCol = 18)
    writeFormula(wb, ws, sprintf("=G%d", seeds[k]), startRow = 3 + k, startCol = 19)
    writeFormula(wb, ws, sprintf("=COUNTIF($K$2:$K$%d,Q%d)", last, 3 + k), startRow = 3 + k, startCol = 20)
  }
  writeData(wb, ws, "Updated centroids after iteration 1 (mean of each cluster)", startRow = 8, startCol = 17)
  addStyle(wb, ws, note, rows = 8, cols = 17)
  writeData(wb, ws, t(c("centroid", "z_pell", "z_grad", "members")), startRow = 9, startCol = 17, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 9, cols = 17:20)
  writeData(wb, ws, c("A", "B", "C"), startRow = 10, startCol = 17)
  for (k in 1:3) {
    writeFormula(wb, ws, sprintf("=AVERAGEIF($K$2:$K$%d,Q%d,$F$2:$F$%d)", last, 9 + k, last), startRow = 9 + k, startCol = 18)
    writeFormula(wb, ws, sprintf("=AVERAGEIF($K$2:$K$%d,Q%d,$G$2:$G$%d)", last, 9 + k, last), startRow = 9 + k, startCol = 19)
    writeFormula(wb, ws, sprintf("=COUNTIF($O$2:$O$%d,Q%d)", last, 9 + k), startRow = 9 + k, startCol = 20)
  }
  writeFormula(wb, ws, sprintf("=SUMPRODUCT(--(K2:K%d<>O2:O%d))", last, last), startRow = 14, startCol = 18)
  writeData(wb, ws, "Institutions that changed cluster between iterations", startRow = 14, startCol = 17)
  writeData(wb, ws, paste(
    "Real k-means repeats the assign-then-average step until nothing moves.",
    "Two iterations are laid out here so each step is visible; copy columns L:O to continue."
  ), startRow = 16, startCol = 17)
  addStyle(wb, ws, note, rows = 16, cols = 17)
  mergeCells(wb, ws, cols = 17:21, rows = 16)
  setRowHeights(wb, ws, rows = 16, heights = 48)
  addStyle(wb, ws, num2, rows = c(4:6, 10:12), cols = 18:19, gridExpand = TRUE)
  setColWidths(wb, ws, cols = 1:21, widths = c(9, 40, 18, 9, 10, 8, 8, 8, 8, 8, 14, 8, 8, 8, 14, 3, 12, 9, 9, 9, 3))
  freezePane(wb, ws, firstActiveRow = 2)

  saveWorkbook(wb, path, overwrite = TRUE)
}
