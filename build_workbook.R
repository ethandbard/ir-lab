# Writes data/ir-lab.xlsx: the institutions table plus one worked sheet per
# lesson, built with plain Excel formulas so the "In your stack" tabs can point
# at real cells. Called from build_data.R.

build_workbook <- function(institutions, variables, path, lines = NULL, codes = NULL, history = NULL) {
  library(openxlsx)

  # The three extracts beyond the institution table. build_data.R passes them
  # in; run on its own, the function reads them from the data folder.
  read_extract <- function(x, file) {
    if (is.null(x)) read.csv(file.path(dirname(path), file), na.strings = c("", "NA")) else as.data.frame(x)
  }
  lines <- read_extract(lines, "fall_enrollment_2023.csv")
  codes <- read_extract(codes, "fall_enrollment_codes.csv")
  history <- read_extract(history, "enrollment_history.csv")

  # Functions added to Excel after 2007 must be stored with the _xlfn. prefix
  # or Excel and LibreOffice show #NAME? until the cell is re-entered.
  writeFormula <- function(wb, sheet, x, ...) {
    x <- gsub("(?<![A-Za-z._])(STDEV\\.S|STDEV\\.P|VAR\\.S|VAR\\.P|MINIFS|MAXIFS|PERCENTILE\\.INC|PERCENTILE\\.EXC|QUARTILE\\.INC|CONCAT|IFS|XLOOKUP|CONFIDENCE\\.T|T\\.INV\\.2T|T\\.DIST\\.2T|T\\.DIST\\.RT|T\\.DIST|T\\.TEST|F\\.DIST\\.RT|F\\.DIST|CHISQ\\.DIST\\.RT|CHISQ\\.TEST|NORM\\.S\\.INV|NORM\\.S\\.DIST|RANK\\.AVG)\\(",
              "_xlfn.\\1(", x, perl = TRUE)
    openxlsx::writeFormula(wb, sheet, x, ...)
  }

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
    "Each lesson sheet works its method with ordinary Excel formulas on the same data.",
    "Three sheets carry their own tables: subtotals (every fall 2023 enrollment row for Rhode Island, with the",
    "IPEDS codes beside them), proportions (counts from the institutions sheet), and forecast (fall headcount",
    "2013 to 2023, one row per institution with a complete history)."
  ), startRow = 2)
  addStyle(wb, "read-me", note, rows = 2, cols = 1)
  setRowHeights(wb, "read-me", rows = 2, heights = 84)
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
    # IF() inside an aggregate needs array evaluation outside Excel 365.
    writeFormula(wb, ws, stats$Formula[i], startRow = 4 + i, startCol = 2,
                 array = grepl("(IF(", stats$Formula[i], fixed = TRUE))
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

  # ---- missingness ----------------------------------------------------
  # Blanks per column with COUNTBLANK, split by level with COUNTIFS on "",
  # and the headcount comparison between reported and unreported rows.
  addWorksheet(wb, "missingness")
  ws <- "missingness"
  writeData(wb, ws, "Missing on purpose: blanks per column and who is dropped", startRow = 1)
  addStyle(wb, ws, title, rows = 1, cols = 1)
  writeData(wb, ws, paste(
    "COUNTBLANK counts empty cells in a Table column. An empty-string criterion in COUNTIFS matches blank cells,",
    "so the level columns count blanks within each level. Nothing here replaces a blank with a zero."
  ), startRow = 2)
  addStyle(wb, ws, note, rows = 2, cols = 1)
  mergeCells(wb, ws, cols = 1:7, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 36)

  cols <- names(institutions)
  levels <- c("4-year", "2-year", "Less than 2-year")
  writeData(wb, ws, t(c("Column", "Blanks", "Share missing", paste("Blank share,", levels))),
            startRow = 4, startCol = 1, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 4, cols = 1:6)
  writeData(wb, ws, cols, startRow = 5, startCol = 1)
  addStyle(wb, ws, mono, rows = 5:(4 + length(cols)), cols = 1)
  for (i in seq_along(cols)) {
    r <- 4 + i
    writeFormula(wb, ws, sprintf("=COUNTBLANK(Institutions[%s])", cols[i]), startRow = r, startCol = 2)
    writeFormula(wb, ws, sprintf("=B%d/ROWS(Institutions)", r), startRow = r, startCol = 3)
    for (k in seq_along(levels)) {
      writeFormula(wb, ws, sprintf(
        "=COUNTIFS(Institutions[level],\"%s\",Institutions[%s],\"\")/COUNTIFS(Institutions[level],\"%s\")",
        levels[k], cols[i], levels[k]), startRow = r, startCol = 3 + k)
    }
  }
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 5:(4 + length(cols)), cols = 3:6, gridExpand = TRUE)

  writeData(wb, ws, "Who is dropped? 4-year institutions by student-faculty ratio", startRow = 4, startCol = 8)
  addStyle(wb, ws, hdr, rows = 4, cols = 8:10)
  writeData(wb, ws, t(c("", "Ratio blank", "Ratio reported")), startRow = 5, startCol = 8, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 5, cols = 8:10)
  who <- data.frame(
    label = c("Institutions", "Median headcount", "Share under 1,000 students", "Mean 6-year completion"),
    blank = c(
      "=COUNTIFS(Institutions[level],\"4-year\",Institutions[stu_fac_ratio],\"\")",
      "=MEDIAN(IF((Institutions[level]=\"4-year\")*(Institutions[stu_fac_ratio]=\"\"),Institutions[headcount]))",
      "=COUNTIFS(Institutions[level],\"4-year\",Institutions[stu_fac_ratio],\"\",Institutions[size],\"Under 1,000\")/I6",
      "=AVERAGEIFS(Institutions[grad_rate_bach_6yr],Institutions[level],\"4-year\",Institutions[stu_fac_ratio],\"\")"
    ),
    reported = c(
      "=COUNTIFS(Institutions[level],\"4-year\",Institutions[stu_fac_ratio],\"<>\")",
      "=MEDIAN(IF((Institutions[level]=\"4-year\")*(Institutions[stu_fac_ratio]<>\"\"),Institutions[headcount]))",
      "=COUNTIFS(Institutions[level],\"4-year\",Institutions[stu_fac_ratio],\"<>\",Institutions[size],\"Under 1,000\")/J6",
      "=AVERAGEIFS(Institutions[grad_rate_bach_6yr],Institutions[level],\"4-year\",Institutions[stu_fac_ratio],\"<>\")"
    )
  )
  writeData(wb, ws, who$label, startRow = 6, startCol = 8)
  for (i in seq_len(nrow(who))) {
    # The MEDIAN(IF()) pair is written as an array formula so it evaluates the
    # same way in Excel 2019, Excel 365, and LibreOffice.
    writeFormula(wb, ws, who$blank[i], startRow = 5 + i, startCol = 9, array = (i == 2))
    writeFormula(wb, ws, who$reported[i], startRow = 5 + i, startCol = 10, array = (i == 2))
  }
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = 6:7, cols = 9:10, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 8, cols = 9:10)
  addStyle(wb, ws, num1, rows = 9, cols = 9:10)
  writeData(wb, ws, paste(
    "The array IF formulas need Excel 365 or 2021.",
    "For a PivotTable version, put level on rows, then Count of unitid and Count Numbers of the column side by side;",
    "the difference is the blanks."
  ), startRow = 11, startCol = 8)
  addStyle(wb, ws, note, rows = 11, cols = 8)
  mergeCells(wb, ws, cols = 8:11, rows = 11)
  setRowHeights(wb, ws, rows = 11, heights = 60)
  setColWidths(wb, ws, cols = 1:11, widths = c(22, 10, 14, 18, 18, 22, 3, 30, 14, 16, 3))
  freezePane(wb, ws, firstActiveRow = 5)

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

  # ---- logistic -------------------------------------------------------
  # Logistic regression by log-likelihood: probability and likelihood columns
  # driven by two coefficient cells, seeded with the maximum-likelihood fit so
  # the sheet is correct on open. Solver reproduces the fit from any start.
  lg <- institutions |>
    dplyr::filter(level == "4-year", !is.na(pct_pell), !is.na(grad_rate_bach_6yr),
                  bach_cohort >= 30) |>
    dplyr::select(unitid, name, control, pct_pell, grad_rate_bach_6yr) |>
    as.data.frame()
  lg_fit <- glm(I(grad_rate_bach_6yr >= 50) ~ pct_pell, family = binomial, data = lg)
  n <- nrow(lg)
  last <- n + 1
  addWorksheet(wb, "logistic")
  ws <- "logistic"
  writeData(wb, ws, lg, startRow = 1, startCol = 1, headerStyle = hdr)
  writeData(wb, ws, t(c("half", "probability", "log-likelihood")), startRow = 1, startCol = 6, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 1, cols = 6:8)
  rows <- 2:last
  writeFormula(wb, ws, sprintf("=IF(E%d>=50,1,0)", rows), startRow = 2, startCol = 6)
  writeFormula(wb, ws, sprintf("=1/(1+EXP(-($K$4+$K$5*D%d)))", rows), startRow = 2, startCol = 7)
  writeFormula(wb, ws, sprintf("=F%d*LN(G%d)+(1-F%d)*LN(1-G%d)", rows, rows, rows, rows), startRow = 2, startCol = 8)
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = rows, cols = 7:8, gridExpand = TRUE)

  writeData(wb, ws, "Logistic regression", startRow = 1, startCol = 10)
  addStyle(wb, ws, title, rows = 1, cols = 10)
  writeData(wb, ws, paste(
    "Outcome: graduates at least half of the bachelor's cohort within six years (column F).",
    "Predictor: percent Pell (column D). Coefficients below are the maximum-likelihood fit;",
    "Solver (maximize K6 by changing K4:K5, GRG Nonlinear) reaches them from 0 and 0."
  ), startRow = 2, startCol = 10)
  addStyle(wb, ws, note, rows = 2, cols = 10)
  mergeCells(wb, ws, cols = 10:13, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 60)
  writeData(wb, ws, c("Intercept", "Slope (per Pell point)", "Log-likelihood (maximize)",
                      "Odds ratio per point", "Odds ratio per 10 points", "Pell share where P = 50%",
                      "Pell share to predict for", "Predicted probability"),
            startRow = 4, startCol = 10)
  writeData(wb, ws, unname(coef(lg_fit)[1]), startRow = 4, startCol = 11)
  writeData(wb, ws, unname(coef(lg_fit)[2]), startRow = 5, startCol = 11)
  writeFormula(wb, ws, sprintf("=SUM(H2:H%d)", last), startRow = 6, startCol = 11)
  writeFormula(wb, ws, "=EXP(K5)", startRow = 7, startCol = 11)
  writeFormula(wb, ws, "=EXP(10*K5)", startRow = 8, startCol = 11)
  writeFormula(wb, ws, "=-K4/K5", startRow = 9, startCol = 11)
  writeData(wb, ws, 40, startRow = 10, startCol = 11)
  writeFormula(wb, ws, "=1/(1+EXP(-(K4+K5*K10)))", startRow = 11, startCol = 11)
  addStyle(wb, ws, createStyle(numFmt = "0.0000"), rows = 4:5, cols = 11)
  addStyle(wb, ws, num1, rows = 6, cols = 11)
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = 7:9, cols = 11)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 11, cols = 11)
  writeData(wb, ws, "Confusion table at a 50% cutoff", startRow = 13, startCol = 10)
  addStyle(wb, ws, hdr, rows = 13, cols = 10:12)
  writeData(wb, ws, t(c("", "Predicted no", "Predicted yes")), startRow = 14, startCol = 10, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 14, cols = 10:12)
  writeData(wb, ws, c("Actual no", "Actual yes"), startRow = 15, startCol = 10)
  writeFormula(wb, ws, sprintf("=SUMPRODUCT((F2:F%d=0)*(G2:G%d<0.5))", last, last), startRow = 15, startCol = 11)
  writeFormula(wb, ws, sprintf("=SUMPRODUCT((F2:F%d=0)*(G2:G%d>=0.5))", last, last), startRow = 15, startCol = 12)
  writeFormula(wb, ws, sprintf("=SUMPRODUCT((F2:F%d=1)*(G2:G%d<0.5))", last, last), startRow = 16, startCol = 11)
  writeFormula(wb, ws, sprintf("=SUMPRODUCT((F2:F%d=1)*(G2:G%d>=0.5))", last, last), startRow = 16, startCol = 12)
  writeData(wb, ws, "Accuracy", startRow = 17, startCol = 10)
  writeFormula(wb, ws, sprintf("=(K15+L16)/COUNT(F2:F%d)", last), startRow = 17, startCol = 11)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 17, cols = 11)
  writeData(wb, ws, paste(
    "LOGEST fits exponential growth, not a logistic curve.",
    "Data Analysis > Regression on column F fits the straight line from the lesson, whose predictions leave 0 to 1."
  ), startRow = 19, startCol = 10)
  addStyle(wb, ws, note, rows = 19, cols = 10)
  mergeCells(wb, ws, cols = 10:13, rows = 19)
  setRowHeights(wb, ws, rows = 19, heights = 48)
  setColWidths(wb, ws, cols = 1:13, widths = c(9, 40, 18, 10, 18, 7, 12, 14, 3, 28, 12, 14, 14))
  freezePane(wb, ws, firstActiveRow = 2)

  # ---- pca ------------------------------------------------------------
  # Principal components: z-scores, the 6 x 6 correlation matrix, and the
  # first component found by power iteration in eight visible rounds.
  pc <- institutions |>
    dplyr::filter(level == "4-year", control != "Private for-profit", bach_cohort >= 100) |>
    dplyr::mutate(log_headcount = round(log10(headcount), 4)) |>
    dplyr::select(unitid, name, control, pct_pell, net_price, grad_rate_bach_6yr,
                  retention_ft, stu_fac_ratio, log_headcount) |>
    tidyr::drop_na() |>
    as.data.frame()
  pc_vars <- c("pct_pell", "net_price", "grad_rate_bach_6yr", "retention_ft", "stu_fac_ratio", "log_headcount")
  pc_fit <- prcomp(pc[, pc_vars], scale. = TRUE)
  n <- nrow(pc)
  last <- n + 1
  addWorksheet(wb, "pca")
  ws <- "pca"
  writeData(wb, ws, pc, startRow = 1, startCol = 1, headerStyle = hdr)
  writeData(wb, ws, t(c(paste0("z_", pc_vars), "PC1 score")), startRow = 1, startCol = 10, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 1, cols = 10:16)
  rows <- 2:last
  for (j in seq_along(pc_vars)) {
    raw <- int2col(3 + j)
    writeFormula(wb, ws, sprintf("=STANDARDIZE(%s%d,AVERAGE(%s$2:%s$%d),STDEV.S(%s$2:%s$%d))",
                                 raw, rows, raw, raw, last, raw, raw, last),
                 startRow = 2, startCol = 9 + j)
  }
  # final iteration vector lives in column 35 (AI), rows 12:17
  vcol <- int2col(35)
  writeFormula(wb, ws, sprintf("=MMULT(J%d:O%d,$%s$12:$%s$17)", rows, rows, vcol, vcol), startRow = 2, startCol = 16)
  addStyle(wb, ws, num2, rows = rows, cols = 10:16, gridExpand = TRUE)

  writeData(wb, ws, "Principal components by hand", startRow = 1, startCol = 18)
  addStyle(wb, ws, title, rows = 1, cols = 18)
  writeData(wb, ws, paste(
    "Columns J to O standardize the six variables. The correlation matrix below is CORREL on each pair.",
    "Power iteration multiplies a starting vector by the matrix and rescales it to unit length; each round",
    "moves it closer to the first principal component. The vector's length after multiplying is the eigenvalue,",
    "and eigenvalue / 6 is the share of variance on PC1. Column P scores every institution with the final vector."
  ), startRow = 2, startCol = 18)
  addStyle(wb, ws, note, rows = 2, cols = 18)
  mergeCells(wb, ws, cols = 18:30, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 60)

  writeData(wb, ws, "Correlation matrix", startRow = 3, startCol = 18)
  writeData(wb, ws, t(pc_vars), startRow = 3, startCol = 19, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 3, cols = 18:24)
  writeData(wb, ws, pc_vars, startRow = 4, startCol = 18)
  for (i in seq_along(pc_vars)) for (j in seq_along(pc_vars)) {
    ci <- int2col(3 + i); cj <- int2col(3 + j)
    writeFormula(wb, ws, sprintf("=CORREL(%s$2:%s$%d,%s$2:%s$%d)", ci, ci, last, cj, cj, last),
                 startRow = 3 + i, startCol = 18 + j)
  }
  addStyle(wb, ws, num2, rows = 4:9, cols = 19:24, gridExpand = TRUE)

  writeData(wb, ws, "Power iteration", startRow = 11, startCol = 18)
  addStyle(wb, ws, hdr, rows = 11, cols = 18:35)
  writeData(wb, ws, pc_vars, startRow = 12, startCol = 18)
  writeData(wb, ws, "v0", startRow = 11, startCol = 19)
  writeFormula(wb, ws, rep("=1/SQRT(6)", 6), startRow = 12, startCol = 19)
  for (k in 1:8) {
    wcol <- 18 + 2 * k; vc <- 19 + 2 * k; prev <- int2col(vc - 2)
    writeData(wb, ws, paste0("w", k), startRow = 11, startCol = wcol)
    writeData(wb, ws, paste0("v", k), startRow = 11, startCol = vc)
    for (i in seq_along(pc_vars)) {
      cc <- int2col(18 + i)
      writeFormula(wb, ws, sprintf("=SUMPRODUCT(%s$4:%s$9,%s$12:%s$17)", cc, cc, prev, prev),
                   startRow = 11 + i, startCol = wcol)
    }
    wl <- int2col(wcol)
    writeFormula(wb, ws, sprintf("=%s%d/%s$18", wl, 12:17, wl), startRow = 12, startCol = vc)
    writeFormula(wb, ws, sprintf("=SQRT(SUMPRODUCT(%s12:%s17,%s12:%s17))", wl, wl, wl, wl), startRow = 18, startCol = wcol)
  }
  writeData(wb, ws, "length (eigenvalue)", startRow = 18, startCol = 18)
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = 12:18, cols = 19:35, gridExpand = TRUE)

  writeData(wb, ws, c("Eigenvalue of PC1", "Share of variance on PC1", "Share on PC1 from R (prcomp)"), startRow = 20, startCol = 18)
  writeFormula(wb, ws, sprintf("=%s18", int2col(34)), startRow = 20, startCol = 19)
  writeFormula(wb, ws, "=S20/6", startRow = 21, startCol = 19)
  writeData(wb, ws, unname(pc_fit$sdev[1]^2 / sum(pc_fit$sdev^2)), startRow = 22, startCol = 19)
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = 20, cols = 19)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 21:22, cols = 19)

  writeData(wb, ws, "PC1 loadings from R, for comparison with v8", startRow = 11, startCol = 37)
  addStyle(wb, ws, hdr, rows = 11, cols = 37)
  writeData(wb, ws, unname(pc_fit$rotation[, 1]), startRow = 12, startCol = 37)
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = 12:17, cols = 37)

  writeData(wb, ws, "Two variables, closed form: Pell share and completion", startRow = 24, startCol = 18)
  addStyle(wb, ws, hdr, rows = 24, cols = 18:19)
  writeData(wb, ws, c("Correlation r", "Eigenvalue 1 = 1 + |r|", "Eigenvalue 2 = 1 - |r|", "Share on PC1 = (1 + |r|) / 2"),
            startRow = 25, startCol = 18)
  writeFormula(wb, ws, sprintf("=CORREL(D2:D%d,F2:F%d)", last, last), startRow = 25, startCol = 19)
  writeFormula(wb, ws, "=1+ABS(S25)", startRow = 26, startCol = 19)
  writeFormula(wb, ws, "=1-ABS(S25)", startRow = 27, startCol = 19)
  writeFormula(wb, ws, "=(1+ABS(S25))/2", startRow = 28, startCol = 19)
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = 25:27, cols = 19)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 28, cols = 19)
  writeData(wb, ws, paste(
    "With r < 0 the first component is (z_pell - z_completion) / SQRT(2); with r > 0 it is the sum.",
    "The second component needs the matrix deflated by the first (C - eigenvalue * v * v^T) before iterating again."
  ), startRow = 30, startCol = 18)
  addStyle(wb, ws, note, rows = 30, cols = 18)
  mergeCells(wb, ws, cols = 18:30, rows = 30)
  setRowHeights(wb, ws, rows = 30, heights = 36)
  setColWidths(wb, ws, cols = 1:37, widths = c(9, 40, 18, 9, 10, 10, 10, 9, 9, rep(8, 6), 10, 3, 26, rep(9, 17), 3, 12))
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

  # ---- compare --------------------------------------------------------
  # Five-number summary of 6-year completion by control and by size, then
  # the between-group share of the sum of squares (eta squared) for each.
  addWorksheet(wb, "compare")
  ws <- "compare"
  writeData(wb, ws, "Compare groups: 6-year bachelor's completion by control and by size", startRow = 1)
  addStyle(wb, ws, title, rows = 1, cols = 1)
  writeData(wb, ws, paste(
    "Every formula filters to 4-year institutions with a bachelor's cohort of at least 30 and a reported rate.",
    "The array IF formulas test the rate against \"\" because a blank cell becomes a zero inside an array.",
    "Spread explained is the between-group sum of squares over the total: the eta squared of a one-way ANOVA."
  ), startRow = 2)
  addStyle(wb, ws, note, rows = 2, cols = 1)
  mergeCells(wb, ws, cols = 1:10, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 48)

  base_if <- "(Institutions[level]=\"4-year\")*(Institutions[bach_cohort]>=30)*(Institutions[grad_rate_bach_6yr]<>\"\")"
  base_ifs <- "Institutions[level],\"4-year\",Institutions[bach_cohort],\">=30\""
  rate <- "Institutions[grad_rate_bach_6yr]"
  group_block <- function(col, groups, start) {
    writeData(wb, ws, t(c(paste("By", col), "n", "Mean", "Min", "P25", "Median", "P75", "Max", "IQR")),
              startRow = start, startCol = 1, colNames = FALSE)
    addStyle(wb, ws, hdr, rows = start, cols = 1:9)
    writeData(wb, ws, groups, startRow = start + 1, startCol = 1)
    for (i in seq_along(groups)) {
      r <- start + i
      g <- groups[i]
      cond <- sprintf("%s*(Institutions[%s]=\"%s\")", base_if, col, g)
      crit <- sprintf("%s,Institutions[%s],\"%s\"", base_ifs, col, g)
      writeFormula(wb, ws, sprintf("=COUNTIFS(%s,%s,\"<>\")", crit, rate), startRow = r, startCol = 2)
      writeFormula(wb, ws, sprintf("=AVERAGEIFS(%s,%s)", rate, crit), startRow = r, startCol = 3)
      writeFormula(wb, ws, sprintf("=MINIFS(%s,%s)", rate, crit), startRow = r, startCol = 4)
      writeFormula(wb, ws, sprintf("=PERCENTILE.INC(IF(%s,%s),0.25)", cond, rate), startRow = r, startCol = 5, array = TRUE)
      writeFormula(wb, ws, sprintf("=MEDIAN(IF(%s,%s))", cond, rate), startRow = r, startCol = 6, array = TRUE)
      writeFormula(wb, ws, sprintf("=PERCENTILE.INC(IF(%s,%s),0.75)", cond, rate), startRow = r, startCol = 7, array = TRUE)
      writeFormula(wb, ws, sprintf("=MAXIFS(%s,%s)", rate, crit), startRow = r, startCol = 8)
      writeFormula(wb, ws, sprintf("=G%d-E%d", r, r), startRow = r, startCol = 9)
    }
    addStyle(wb, ws, num1, rows = (start + 1):(start + length(groups)), cols = 3:9, gridExpand = TRUE)
    invisible(start + length(groups))
  }
  controls <- c("Public", "Private nonprofit", "Private for-profit")
  sizes <- c("Under 1,000", "1,000-4,999", "5,000-9,999", "10,000-19,999", "20,000 and above")
  group_block("control", controls, 4)     # rows 5:7
  group_block("size", sizes, 10)          # rows 11:15

  # Spread explained: total SS once, between SS per grouping from the blocks above.
  writeData(wb, ws, t(c("Spread explained", "Value")), startRow = 18, startCol = 1, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 18, cols = 1:2)
  spread <- data.frame(
    label = c("Institutions in the filter", "Grand mean", "Total sum of squares",
              "Between-group SS, control", "Share explained by control",
              "Between-group SS, size", "Share explained by size"),
    formula = c(
      sprintf("=COUNTIFS(%s,%s,\"<>\")", base_ifs, rate),
      sprintf("=AVERAGEIFS(%s,%s)", rate, base_ifs),
      sprintf("=DEVSQ(IF(%s,%s))", base_if, rate),
      "=SUMPRODUCT(B5:B7,(C5:C7-B20)^2)",
      "=B22/B21",
      "=SUMPRODUCT(B11:B15,(C11:C15-B20)^2)",
      "=B24/B21"
    )
  )
  writeData(wb, ws, spread$label, startRow = 19, startCol = 1)
  for (i in seq_len(nrow(spread))) {
    writeFormula(wb, ws, spread$formula[i], startRow = 18 + i, startCol = 2, array = (i == 3))
  }
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = c(19, 21, 22, 24), cols = 2, gridExpand = TRUE)
  addStyle(wb, ws, num1, rows = 20, cols = 2)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = c(23, 25), cols = 2, gridExpand = TRUE)
  writeData(wb, ws, paste(
    "For the chart, copy the filtered rates next to their control and insert a Box and Whisker chart (Insert > Statistical).",
    "Excel has no small multiples; use one PivotChart per size band, or a matrix in Power BI with size in the Small multiples well.",
    "The array formulas need Excel 365 or 2021."
  ), startRow = 27, startCol = 1)
  addStyle(wb, ws, note, rows = 27, cols = 1)
  mergeCells(wb, ws, cols = 1:10, rows = 27)
  setRowHeights(wb, ws, rows = 27, heights = 48)
  setColWidths(wb, ws, cols = 1:10, widths = c(28, 9, 9, 9, 9, 9, 9, 9, 9, 3))
  freezePane(wb, ws, firstActiveRow = 4)

  # ---- sampling -------------------------------------------------------
  # One sample of 50 six-year completion rates (the same draw as the lesson's
  # set.seed(1) sample), the formula t interval, the population it came from,
  # and a single RANDBETWEEN bootstrap resample.
  addWorksheet(wb, "sampling")
  ws <- "sampling"
  writeData(wb, ws, "Sampling and uncertainty: one sample of 50, its 95% interval, and the population", startRow = 1)
  addStyle(wb, ws, title, rows = 1, cols = 1)
  writeData(wb, ws, paste(
    "Column B holds 50 six-year completion rates sampled from 4-year institutions with a bachelor's cohort of at least 30.",
    "CONFIDENCE.T returns the half-width of the t interval; T.INV.2T times the standard error gives the same number.",
    "Column J is one bootstrap resample: press F9 to redraw it. A real bootstrap needs thousands, which is a job for code."
  ), startRow = 2)
  addStyle(wb, ws, note, rows = 2, cols = 1)
  mergeCells(wb, ws, cols = 1:11, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 48)

  pop_rows <- institutions |>
    dplyr::filter(level == "4-year", !is.na(grad_rate_bach_6yr), bach_cohort >= 30)
  set.seed(1)
  pick <- sample(nrow(pop_rows), 50)
  samp_tbl <- data.frame(Institution = pop_rows$name[pick], Rate = pop_rows$grad_rate_bach_6yr[pick])
  writeData(wb, ws, t(c("Institution", "6-year completion")), startRow = 4, startCol = 1, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 4, cols = 1:2)
  writeData(wb, ws, samp_tbl, startRow = 5, startCol = 1, colNames = FALSE)
  addStyle(wb, ws, num1, rows = 5:54, cols = 2, gridExpand = TRUE)

  writeData(wb, ws, t(c("Sample of 50", "Value")), startRow = 4, startCol = 4, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 4, cols = 4:5)
  stats <- data.frame(
    Statistic = c("Sample size", "Mean", "Standard error", "Half-width, 95%", "Lower", "Upper",
                  "t critical, 49 df", "Half-width by t x SE"),
    Formula = c(
      "=COUNT(B5:B54)",
      "=AVERAGE(B5:B54)",
      "=STDEV.S(B5:B54)/SQRT(COUNT(B5:B54))",
      "=CONFIDENCE.T(0.05,STDEV.S(B5:B54),COUNT(B5:B54))",
      "=E6-E8",
      "=E6+E8",
      "=T.INV.2T(0.05,E5-1)",
      "=E11*E7"
    )
  )
  writeData(wb, ws, stats$Statistic, startRow = 5, startCol = 4)
  for (i in seq_len(nrow(stats))) writeFormula(wb, ws, stats$Formula[i], startRow = 4 + i, startCol = 5)
  addStyle(wb, ws, num2, rows = 5:12, cols = 5, gridExpand = TRUE)

  writeData(wb, ws, t(c("Population: 4-year, cohort >= 30", "Value")), startRow = 4, startCol = 7, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 4, cols = 7:8)
  pop_stats <- data.frame(
    Statistic = c("Institutions", "Mean", "Standard deviation", "Inside the sample's interval?"),
    Formula = c(
      "=COUNTIFS(Institutions[level],\"4-year\",Institutions[grad_rate_bach_6yr],\"<>\",Institutions[bach_cohort],\">=30\")",
      "=AVERAGEIFS(Institutions[grad_rate_bach_6yr],Institutions[level],\"4-year\",Institutions[bach_cohort],\">=30\")",
      "=STDEV.S(IF((Institutions[level]=\"4-year\")*(Institutions[bach_cohort]>=30)*(Institutions[grad_rate_bach_6yr]<>\"\"),Institutions[grad_rate_bach_6yr]))",
      "=IF(AND(H6>=E9,H6<=E10),\"Yes\",\"No\")"
    )
  )
  writeData(wb, ws, pop_stats$Statistic, startRow = 5, startCol = 7)
  for (i in seq_len(nrow(pop_stats))) writeFormula(wb, ws, pop_stats$Formula[i], startRow = 4 + i, startCol = 8, array = (i == 3))
  addStyle(wb, ws, num2, rows = 6:7, cols = 8, gridExpand = TRUE)

  writeData(wb, ws, t(c("One bootstrap resample", "Resample mean")), startRow = 4, startCol = 10, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 4, cols = 10:11)
  for (r in 5:54) writeFormula(wb, ws, "=INDEX($B$5:$B$54,RANDBETWEEN(1,50))", startRow = r, startCol = 10)
  writeFormula(wb, ws, "=AVERAGE(J5:J54)", startRow = 5, startCol = 11)
  addStyle(wb, ws, num1, rows = 5:54, cols = 10, gridExpand = TRUE)
  addStyle(wb, ws, num2, rows = 5, cols = 11)
  writeData(wb, ws, paste(
    "Each resample draws 50 rows from column B with replacement. Repeating this thousands of times and taking",
    "the standard deviation of the means is the bootstrap standard error; a Data Table can do it but recalculates",
    "on every edit. The array STDEV.S(IF()) formula needs Excel 365 or 2021."
  ), startRow = 7, startCol = 11)
  addStyle(wb, ws, note, rows = 7, cols = 11)
  mergeCells(wb, ws, cols = 11:14, rows = 7:10)
  setColWidths(wb, ws, cols = 1:14, widths = c(40, 16, 3, 22, 12, 3, 30, 12, 3, 22, 16, 12, 12, 12))
  freezePane(wb, ws, firstActiveRow = 5)

  # ---- split ----------------------------------------------------------
  # Train/test split by the last digit of unitid (7 in 10 train), rows sorted
  # so the training block is contiguous and LINEST can be pointed at it alone.
  # The model is 6-year completion on percent Pell and net price.
  sp <- institutions |>
    dplyr::filter(level == "4-year", bach_cohort >= 30, !is.na(pct_pell), !is.na(net_price),
                  !is.na(stu_fac_ratio), !is.na(headcount), !is.na(grad_rate_bach_4yr),
                  !is.na(grad_rate_bach_6yr)) |>
    dplyr::mutate(split = ifelse(unitid %% 10 < 7, "train", "test")) |>
    dplyr::arrange(split == "test", unitid) |>
    dplyr::select(unitid, name, control, pct_pell, net_price, grad_rate_bach_6yr) |>
    as.data.frame()
  n <- nrow(sp)
  last <- n + 1
  n_train <- sum(sp$unitid %% 10 < 7)
  tr_last <- n_train + 1
  te_first <- n_train + 2

  addWorksheet(wb, "split")
  ws <- "split"
  writeData(wb, ws, sp, startRow = 1, startCol = 1, headerStyle = hdr)
  writeData(wb, ws, t(c("split", "predicted", "squared error")), startRow = 1, startCol = 7, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 1, cols = 7:9)
  writeFormula(wb, ws, sprintf("=IF(MOD(A%d,10)<7,\"train\",\"test\")", 2:last), startRow = 2, startCol = 7)
  writeFormula(wb, ws, sprintf("=$L$6+$L$7*D%d+$L$8*E%d", 2:last, 2:last), startRow = 2, startCol = 8)
  writeFormula(wb, ws, sprintf("=(F%d-H%d)^2", 2:last, 2:last), startRow = 2, startCol = 9)
  addStyle(wb, ws, num1, rows = 2:last, cols = 8:9, gridExpand = TRUE)

  writeData(wb, ws, "Split before you fit", startRow = 1, startCol = 11)
  addStyle(wb, ws, title, rows = 1, cols = 11)
  writeData(wb, ws, paste(
    "Rows are sorted so the training rows (last digit of unitid 0-6) come first, rows 2 to", tr_last,
    ", and the test rows follow. LINEST is fitted on the training block only;",
    "the RMSE formulas score each block separately. y = 6-year completion (F), x = percent Pell (D) and net price (E)."
  ), startRow = 2, startCol = 11)
  addStyle(wb, ws, note, rows = 2, cols = 11)
  mergeCells(wb, ws, cols = 11:14, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 60)

  lin <- sprintf("LINEST(F2:F%d,D2:E%d,TRUE,TRUE)", tr_last, tr_last)
  labels <- c("Training rows", "Test rows", "Intercept", "Pell coefficient", "Net price coefficient",
              "Training R squared", "Training RMSE", "Test RMSE", "Test RMSE, guess the training mean")
  forms <- c(
    sprintf("=COUNTIF(G2:G%d,\"train\")", last),
    sprintf("=COUNTIF(G2:G%d,\"test\")", last),
    sprintf("=INDEX(%s,1,3)", lin),
    sprintf("=INDEX(%s,1,2)", lin),
    sprintf("=INDEX(%s,1,1)", lin),
    sprintf("=INDEX(%s,3,1)", lin),
    sprintf("=SQRT(SUMXMY2(F2:F%d,H2:H%d)/COUNT(F2:F%d))", tr_last, tr_last, tr_last),
    sprintf("=SQRT(SUMXMY2(F%d:F%d,H%d:H%d)/COUNT(F%d:F%d))", te_first, last, te_first, last, te_first, last),
    sprintf("=SQRT(SUMPRODUCT((F%d:F%d-AVERAGE(F2:F%d))^2)/COUNT(F%d:F%d))", te_first, last, tr_last, te_first, last)
  )
  writeData(wb, ws, labels, startRow = 4, startCol = 11)
  for (i in seq_along(forms)) writeFormula(wb, ws, forms[i], startRow = 3 + i, startCol = 12)
  addStyle(wb, ws, createStyle(numFmt = "0.0000"), rows = 6:8, cols = 12, gridExpand = TRUE)
  addStyle(wb, ws, num2, rows = 9:12, cols = 12, gridExpand = TRUE)
  writeData(wb, ws, "LINEST output on the training block (5 rows x 3 columns)", startRow = 14, startCol = 11)
  addStyle(wb, ws, hdr, rows = 14, cols = 11:13)
  writeFormula(wb, ws, lin, startRow = 15, startCol = 11, array = TRUE)
  writeData(wb, ws, c("net price | Pell | intercept", "standard errors", "R2 | se of y",
                      "F | df", "SS regression | SS residual"), startRow = 15, startCol = 14)
  addStyle(wb, ws, note, rows = 15:19, cols = 14)
  writeData(wb, ws, paste(
    "MOD(A2,10) also gives a fold number 0-9 for ten-fold cross-validation, but ten LINEST calls on",
    "non-contiguous blocks is where the loop belongs in R or Python. Never let a LINEST, AVERAGE, or",
    "STANDARDIZE range run past the training block: that is the test set leaking into the fit."
  ), startRow = 21, startCol = 11)
  addStyle(wb, ws, note, rows = 21, cols = 11)
  mergeCells(wb, ws, cols = 11:14, rows = 21)
  setRowHeights(wb, ws, rows = 21, heights = 60)
  setColWidths(wb, ws, cols = 1:14, widths = c(9, 40, 18, 10, 10, 18, 8, 10, 12, 3, 30, 12, 12, 26))
  freezePane(wb, ws, firstActiveRow = 2)

  # ---- relationships --------------------------------------------------
  # Correlations on the 4-year frame: CORREL for Pearson, RANK.AVG then
  # CORREL for Spearman, helper columns for the within-sector version, and
  # a matrix built one CORREL at a time so blanks are handled pairwise.
  rel <- institutions |>
    dplyr::filter(level == "4-year", bach_cohort >= 30, !is.na(grad_rate_bach_6yr)) |>
    dplyr::select(unitid, name, control, pct_pell, net_price, retention_ft, stu_fac_ratio,
                  headcount, grad_rate_bach_6yr) |>
    as.data.frame()
  n <- nrow(rel)
  last <- n + 1
  rows <- 2:last
  addWorksheet(wb, "relationships")
  ws <- "relationships"
  writeData(wb, ws, rel, startRow = 1, startCol = 1, headerStyle = hdr)
  writeData(wb, ws, t(c("log_headcount", "rank_headcount", "rank_completion",
                        "public_price", "public_completion", "nonprofit_price", "nonprofit_completion")),
            startRow = 1, startCol = 10, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 1, cols = 10:16)
  writeFormula(wb, ws, sprintf("=LOG10(H%d)", rows), startRow = 2, startCol = 10)
  writeFormula(wb, ws, sprintf("=RANK.AVG(H%d,H$2:H$%d,1)", rows, last), startRow = 2, startCol = 11)
  writeFormula(wb, ws, sprintf("=RANK.AVG(I%d,I$2:I$%d,1)", rows, last), startRow = 2, startCol = 12)
  # A blank net price would become 0 inside IF, so the helper pair blanks out together.
  writeFormula(wb, ws, sprintf("=IF(AND(C%d=\"Public\",E%d<>\"\"),E%d,\"\")", rows, rows, rows), startRow = 2, startCol = 13)
  writeFormula(wb, ws, sprintf("=IF(AND(C%d=\"Public\",E%d<>\"\"),I%d,\"\")", rows, rows, rows), startRow = 2, startCol = 14)
  writeFormula(wb, ws, sprintf("=IF(AND(C%d=\"Private nonprofit\",E%d<>\"\"),E%d,\"\")", rows, rows, rows), startRow = 2, startCol = 15)
  writeFormula(wb, ws, sprintf("=IF(AND(C%d=\"Private nonprofit\",E%d<>\"\"),I%d,\"\")", rows, rows, rows), startRow = 2, startCol = 16)
  addStyle(wb, ws, num2, rows = rows, cols = 10, gridExpand = TRUE)

  writeData(wb, ws, "Relationships", startRow = 1, startCol = 18)
  addStyle(wb, ws, title, rows = 1, cols = 18)
  writeData(wb, ws, paste(
    "CORREL skips a pair when either cell is blank or text, which is R's complete.obs.",
    "Spearman is CORREL on the RANK.AVG columns. The helper columns M to P blank out every row",
    "outside the sector, so CORREL on them is the within-sector correlation."
  ), startRow = 2, startCol = 18)
  addStyle(wb, ws, note, rows = 2, cols = 18)
  mergeCells(wb, ws, cols = 18:23, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 48)
  labels <- c("Institutions", "Pearson r, Pell and completion", "Pearson r, net price and completion",
              "R squared, net price and completion", "Pearson r, headcount and completion",
              "Pearson r, log headcount and completion", "Spearman rho, headcount and completion",
              "r, net price and completion, public only",
              "r, net price and completion, private nonprofit only")
  forms <- c(
    sprintf("=COUNT(I2:I%d)", last),
    sprintf("=CORREL(D2:D%d,I2:I%d)", last, last),
    sprintf("=CORREL(E2:E%d,I2:I%d)", last, last),
    sprintf("=RSQ(I2:I%d,E2:E%d)", last, last),
    sprintf("=CORREL(H2:H%d,I2:I%d)", last, last),
    sprintf("=CORREL(J2:J%d,I2:I%d)", last, last),
    sprintf("=CORREL(K2:K%d,L2:L%d)", last, last),
    sprintf("=CORREL(M2:M%d,N2:N%d)", last, last),
    sprintf("=CORREL(O2:O%d,P2:P%d)", last, last)
  )
  writeData(wb, ws, labels, startRow = 4, startCol = 18)
  for (i in seq_along(forms)) writeFormula(wb, ws, forms[i], startRow = 3 + i, startCol = 19)
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = 5:12, cols = 19)

  mvars <- c("pct_pell", "net_price", "retention_ft", "stu_fac_ratio", "headcount", "grad_rate_bach_6yr", "log_headcount")
  mcols <- c(4, 5, 6, 7, 8, 9, 10)
  writeData(wb, ws, "Correlation matrix (CORREL on each pair)", startRow = 14, startCol = 18)
  writeData(wb, ws, t(mvars), startRow = 15, startCol = 19, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 15, cols = 18:25)
  writeData(wb, ws, mvars, startRow = 16, startCol = 18)
  for (i in seq_along(mvars)) for (j in seq_along(mvars)) {
    ci <- int2col(mcols[i]); cj <- int2col(mcols[j])
    writeFormula(wb, ws, sprintf("=CORREL(%s$2:%s$%d,%s$2:%s$%d)", ci, ci, last, cj, cj, last),
                 startRow = 15 + i, startCol = 18 + j)
  }
  addStyle(wb, ws, num2, rows = 16:22, cols = 19:25, gridExpand = TRUE)
  writeData(wb, ws, paste(
    "Data > Data Analysis > Correlation writes the same matrix in one step but treats a blank as zero;",
    "clear or filter the blank rows first. Insert > Scatter with a trendline draws any pair."
  ), startRow = 24, startCol = 18)
  addStyle(wb, ws, note, rows = 24, cols = 18)
  mergeCells(wb, ws, cols = 18:25, rows = 24)
  setRowHeights(wb, ws, rows = 24, heights = 36)
  setColWidths(wb, ws, cols = 1:25, widths = c(9, 40, 18, 9, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 3, 44, rep(11, 7)))
  freezePane(wb, ws, firstActiveRow = 2)

  # ---- two-groups -----------------------------------------------------
  # Two columns of completion rates, then Welch's t-test and Cohen's d in
  # scalar formulas, with T.TEST as the one-call check.
  tg <- institutions |>
    dplyr::filter(level == "4-year", bach_cohort >= 30, !is.na(grad_rate_bach_6yr),
                  control %in% c("Public", "Private nonprofit"))
  pub <- tg$grad_rate_bach_6yr[tg$control == "Public"]
  npf <- tg$grad_rate_bach_6yr[tg$control == "Private nonprofit"]
  addWorksheet(wb, "two-groups")
  ws <- "two-groups"
  writeData(wb, ws, "Two groups: 6-year bachelor's completion, public against private nonprofit", startRow = 1)
  addStyle(wb, ws, title, rows = 1, cols = 1)
  writeData(wb, ws, paste(
    "4-year institutions with a bachelor's cohort of at least 30. T.TEST with type 3 is Welch's test and returns the p-value;",
    "the block below rebuilds it in steps so the t statistic, degrees of freedom, and interval are visible.",
    "Cohen's d is the difference in means over the pooled standard deviation."
  ), startRow = 2)
  addStyle(wb, ws, note, rows = 2, cols = 1)
  mergeCells(wb, ws, cols = 1:8, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 48)
  writeData(wb, ws, t(c("Public", "Private nonprofit")), startRow = 4, startCol = 1, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 4, cols = 1:2)
  writeData(wb, ws, pub, startRow = 5, startCol = 1)
  writeData(wb, ws, npf, startRow = 5, startCol = 2)
  addStyle(wb, ws, num1, rows = 5:(4 + max(length(pub), length(npf))), cols = 1:2, gridExpand = TRUE)
  ra <- "A5:A1100"
  rb <- "B5:B1100"
  writeData(wb, ws, t(c("Group statistics", "Public", "Private nonprofit")), startRow = 4, startCol = 4, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 4, cols = 4:6)
  writeData(wb, ws, c("n", "Mean", "Standard deviation", "Variance", "Standard error of the mean"),
            startRow = 5, startCol = 4)
  group_forms <- function(r) c(sprintf("=COUNT(%s)", r), sprintf("=AVERAGE(%s)", r),
                               sprintf("=STDEV.S(%s)", r), sprintf("=VAR.S(%s)", r))
  fa <- group_forms(ra)
  fb <- group_forms(rb)
  for (i in 1:4) {
    writeFormula(wb, ws, fa[i], startRow = 4 + i, startCol = 5)
    writeFormula(wb, ws, fb[i], startRow = 4 + i, startCol = 6)
  }
  writeFormula(wb, ws, "=E7/SQRT(E5)", startRow = 9, startCol = 5)
  writeFormula(wb, ws, "=F7/SQRT(F5)", startRow = 9, startCol = 6)
  addStyle(wb, ws, num2, rows = 6:9, cols = 5:6, gridExpand = TRUE)

  writeData(wb, ws, t(c("Welch's t-test and effect size", "Value")), startRow = 11, startCol = 4, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 11, cols = 4:5)
  test_labels <- c("Difference in means (nonprofit - public)", "Standard error of the difference", "t statistic",
                   "Welch degrees of freedom", "p-value, two-sided", "p-value from T.TEST (type 3)",
                   "95% interval, lower", "95% interval, upper", "Pooled standard deviation", "Cohen's d",
                   "Share of public-private pairs where the private is higher")
  test_forms <- c(
    "=F6-E6",
    "=SQRT(E8/E5+F8/F5)",
    "=E12/E13",
    "=(E8/E5+F8/F5)^2/((E8/E5)^2/(E5-1)+(F8/F5)^2/(F5-1))",
    "=T.DIST.2T(ABS(E14),E15)",
    sprintf("=T.TEST(%s,%s,2,3)", ra, rb),
    "=E12-T.INV.2T(0.05,E15)*E13",
    "=E12+T.INV.2T(0.05,E15)*E13",
    "=SQRT(((E5-1)*E8+(F5-1)*F8)/(E5+F5-2))",
    "=E12/E20",
    "=NORM.S.DIST(E21/SQRT(2),TRUE)"
  )
  writeData(wb, ws, test_labels, startRow = 12, startCol = 4)
  for (i in seq_along(test_forms)) writeFormula(wb, ws, test_forms[i], startRow = 11 + i, startCol = 5)
  addStyle(wb, ws, num2, rows = c(12:15, 18:21), cols = 5, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.00E+00"), rows = 16:17, cols = 5, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 22, cols = 5)
  writeData(wb, ws, paste(
    "Data > Data Analysis > t-Test: Two-Sample Assuming Unequal Variances writes the same numbers with one-",
    "and two-tailed p-values. T.TEST type 2 is the equal-variance version. NORM.S.DIST of d / SQRT(2) is the",
    "probability that a random private nonprofit beats a random public."
  ), startRow = 24, startCol = 4)
  addStyle(wb, ws, note, rows = 24, cols = 4)
  mergeCells(wb, ws, cols = 4:8, rows = 24)
  setRowHeights(wb, ws, rows = 24, heights = 60)
  setColWidths(wb, ws, cols = 1:8, widths = c(12, 18, 3, 52, 14, 18, 3, 3))
  freezePane(wb, ws, firstActiveRow = 5)

  # ---- predict-rate ---------------------------------------------------
  # Training rows first (last digit of unitid 0-6), LINEST with six numeric
  # predictors on that block, the exhaustive search for a tree's first split
  # on percent Pell, and ridge regression in closed form for two predictors.
  pr <- institutions |>
    dplyr::filter(level == "4-year", bach_cohort >= 30,
                  carnegie %in% c("Doctoral", "Master's", "Baccalaureate", "Special focus")) |>
    dplyr::mutate(log_headcount = round(log10(headcount), 4)) |>
    dplyr::select(unitid, name, control, locale, carnegie, hbcu, pct_pell, net_price, stu_fac_ratio,
                  log_headcount, pct_any_grant, pct_women_ug, pct_white_ug, pct_black_ug, pct_hispanic_ug,
                  pct_asian_ug, pct_intl_ug, retention_ft, grad_rate_bach_6yr) |>
    tidyr::drop_na() |>
    dplyr::mutate(split = ifelse(unitid %% 10 < 7, "train", "test")) |>
    dplyr::arrange(split == "test", unitid) |>
    dplyr::select(unitid, name, control, pct_pell, net_price, retention_ft, stu_fac_ratio,
                  log_headcount, pct_asian_ug, grad_rate_bach_6yr) |>
    as.data.frame()
  n <- nrow(pr)
  last <- n + 1
  n_train <- sum(pr$unitid %% 10 < 7)
  tr_last <- n_train + 1
  te_first <- n_train + 2
  addWorksheet(wb, "predict-rate")
  ws <- "predict-rate"
  writeData(wb, ws, pr, startRow = 1, startCol = 1, headerStyle = hdr)
  writeData(wb, ws, t(c("split", "predicted", "squared error")), startRow = 1, startCol = 11, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 1, cols = 11:13)
  rows <- 2:last
  writeFormula(wb, ws, sprintf("=IF(MOD(A%d,10)<7,\"train\",\"test\")", rows), startRow = 2, startCol = 11)
  writeFormula(wb, ws, sprintf("=$P$6+$P$7*D%d+$P$8*E%d+$P$9*F%d+$P$10*G%d+$P$11*H%d+$P$12*I%d",
                               rows, rows, rows, rows, rows, rows), startRow = 2, startCol = 12)
  writeFormula(wb, ws, sprintf("=(J%d-L%d)^2", rows, rows), startRow = 2, startCol = 13)
  addStyle(wb, ws, num1, rows = rows, cols = 12:13, gridExpand = TRUE)

  writeData(wb, ws, "Predict a rate", startRow = 1, startCol = 15)
  addStyle(wb, ws, title, rows = 1, cols = 15)
  writeData(wb, ws, paste(
    "Training rows (last digit of unitid 0-6) are rows 2 to", tr_last, "and the test rows follow.",
    "LINEST fits 6-year completion (J) on columns D to I using the training block only;",
    "the prediction column scores every row and the RMSE formulas score each block."
  ), startRow = 2, startCol = 15)
  addStyle(wb, ws, note, rows = 2, cols = 15)
  mergeCells(wb, ws, cols = 15:20, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 60)
  lin <- sprintf("LINEST(J2:J%d,D2:I%d,TRUE,TRUE)", tr_last, tr_last)
  labels <- c("Training rows", "Test rows", "Intercept", "Percent Pell", "Net price", "Full-time retention",
              "Student-faculty ratio", "Log10 headcount", "Percent Asian", "Training R squared",
              "Training RMSE", "Test RMSE", "Test RMSE, guess the training mean")
  forms <- c(
    sprintf("=COUNTIF(K2:K%d,\"train\")", last),
    sprintf("=COUNTIF(K2:K%d,\"test\")", last),
    sprintf("=INDEX(%s,1,7)", lin),
    sprintf("=INDEX(%s,1,6)", lin),
    sprintf("=INDEX(%s,1,5)", lin),
    sprintf("=INDEX(%s,1,4)", lin),
    sprintf("=INDEX(%s,1,3)", lin),
    sprintf("=INDEX(%s,1,2)", lin),
    sprintf("=INDEX(%s,1,1)", lin),
    sprintf("=INDEX(%s,3,1)", lin),
    sprintf("=SQRT(SUMXMY2(J2:J%d,L2:L%d)/COUNT(J2:J%d))", tr_last, tr_last, tr_last),
    sprintf("=SQRT(SUMXMY2(J%d:J%d,L%d:L%d)/COUNT(J%d:J%d))", te_first, last, te_first, last, te_first, last),
    sprintf("=SQRT(SUMPRODUCT((J%d:J%d-AVERAGE(J2:J%d))^2)/COUNT(J%d:J%d))", te_first, last, tr_last, te_first, last)
  )
  writeData(wb, ws, labels, startRow = 4, startCol = 15)
  for (i in seq_along(forms)) writeFormula(wb, ws, forms[i], startRow = 3 + i, startCol = 16)
  addStyle(wb, ws, createStyle(numFmt = "0.0000"), rows = 6:12, cols = 16, gridExpand = TRUE)
  addStyle(wb, ws, num2, rows = 13:16, cols = 16, gridExpand = TRUE)

  writeData(wb, ws, "A tree's first split: exhaustive search on percent Pell, training rows only", startRow = 18, startCol = 15)
  addStyle(wb, ws, hdr, rows = 18, cols = 15:20)
  writeData(wb, ws, t(c("Cut at Pell <", "n below", "Mean below", "n at or above", "Mean at or above", "Squared error left")),
            startRow = 19, startCol = 15, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 19, cols = 15:20)
  cuts <- seq(10, 90, by = 5)
  writeData(wb, ws, cuts, startRow = 20, startCol = 15)
  for (i in seq_along(cuts)) {
    r <- 19 + i
    writeFormula(wb, ws, sprintf("=COUNTIF(D$2:D$%d,\"<\"&O%d)", tr_last, r), startRow = r, startCol = 16)
    writeFormula(wb, ws, sprintf("=AVERAGEIF(D$2:D$%d,\"<\"&O%d,J$2:J$%d)", tr_last, r, tr_last), startRow = r, startCol = 17)
    writeFormula(wb, ws, sprintf("=COUNTIF(D$2:D$%d,\">=\"&O%d)", tr_last, r), startRow = r, startCol = 18)
    writeFormula(wb, ws, sprintf("=AVERAGEIF(D$2:D$%d,\">=\"&O%d,J$2:J$%d)", tr_last, r, tr_last), startRow = r, startCol = 19)
    writeFormula(wb, ws, sprintf("=DEVSQ(IF(D$2:D$%d<O%d,J$2:J$%d))+DEVSQ(IF(D$2:D$%d>=O%d,J$2:J$%d))",
                                 tr_last, r, tr_last, tr_last, r, tr_last), startRow = r, startCol = 20, array = TRUE)
  }
  last_cut <- 19 + length(cuts)
  addStyle(wb, ws, num1, rows = 20:last_cut, cols = c(17, 19), gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = 20:last_cut, cols = c(16, 18, 20), gridExpand = TRUE)
  writeData(wb, ws, c("Squared error with no split", "Best cut", "Squared error at the best cut",
                      "Share of squared error removed"), startRow = last_cut + 2, startCol = 15)
  writeFormula(wb, ws, sprintf("=DEVSQ(J2:J%d)", tr_last), startRow = last_cut + 2, startCol = 16)
  writeFormula(wb, ws, sprintf("=INDEX(O20:O%d,MATCH(MIN(T20:T%d),T20:T%d,0))", last_cut, last_cut, last_cut),
               startRow = last_cut + 3, startCol = 16)
  writeFormula(wb, ws, sprintf("=MIN(T20:T%d)", last_cut), startRow = last_cut + 4, startCol = 16)
  writeFormula(wb, ws, sprintf("=1-P%d/P%d", last_cut + 4, last_cut + 2), startRow = last_cut + 5, startCol = 16)
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = c(last_cut + 2, last_cut + 4), cols = 16, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = last_cut + 5, cols = 16)

  # Ridge in closed form. With z-scored predictors and centered y:
  #   sum z1^2 = sum z2^2 = n - 1, sum z1 z2 = (n - 1) r12,
  #   sum z1 y = (n - 1) r1y sd_y, sum z2 y = (n - 1) r2y sd_y,
  # so b = (Z'Z + lambda I)^-1 Z'y needs only five cells.
  rr <- last_cut + 8
  writeData(wb, ws, "Ridge regression in closed form: two standardized predictors, Pell (D) and net price (E)", startRow = rr, startCol = 15)
  addStyle(wb, ws, hdr, rows = rr, cols = 15:18)
  writeData(wb, ws, c("Training rows (n)", "r, Pell and net price", "r, Pell and completion",
                      "r, net price and completion", "SD of completion"), startRow = rr + 1, startCol = 15)
  writeFormula(wb, ws, sprintf("=COUNT(J2:J%d)", tr_last), startRow = rr + 1, startCol = 16)
  writeFormula(wb, ws, sprintf("=CORREL(D2:D%d,E2:E%d)", tr_last, tr_last), startRow = rr + 2, startCol = 16)
  writeFormula(wb, ws, sprintf("=CORREL(D2:D%d,J2:J%d)", tr_last, tr_last), startRow = rr + 3, startCol = 16)
  writeFormula(wb, ws, sprintf("=CORREL(E2:E%d,J2:J%d)", tr_last, tr_last), startRow = rr + 4, startCol = 16)
  writeFormula(wb, ws, sprintf("=STDEV.S(J2:J%d)", tr_last), startRow = rr + 5, startCol = 16)
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = (rr + 2):(rr + 5), cols = 16, gridExpand = TRUE)
  writeData(wb, ws, t(c("Penalty", "Pell coefficient", "Net price coefficient", "Shrinkage")),
            startRow = rr + 7, startCol = 15, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = rr + 7, cols = 15:18)
  pens <- c(0, 100, 300, 1000, 3000, 10000, 30000)
  writeData(wb, ws, pens, startRow = rr + 8, startCol = 15)
  nP <- sprintf("$P$%d", rr + 1); r12 <- sprintf("$P$%d", rr + 2); r1y <- sprintf("$P$%d", rr + 3)
  r2y <- sprintf("$P$%d", rr + 4); sdy <- sprintf("$P$%d", rr + 5)
  for (i in seq_along(pens)) {
    r <- rr + 7 + i
    det <- sprintf("(((%s-1)+O%d)*((%s-1)+O%d)-((%s-1)*%s)^2)", nP, r, nP, r, nP, r12)
    writeFormula(wb, ws, sprintf("=(((%s-1)+O%d)*(%s-1)*%s*%s-(%s-1)*%s*(%s-1)*%s*%s)/%s",
                                 nP, r, nP, r1y, sdy, nP, r12, nP, r2y, sdy, det), startRow = r, startCol = 16)
    writeFormula(wb, ws, sprintf("=(((%s-1)+O%d)*(%s-1)*%s*%s-(%s-1)*%s*(%s-1)*%s*%s)/%s",
                                 nP, r, nP, r2y, sdy, nP, r12, nP, r1y, sdy, det), startRow = r, startCol = 17)
    writeFormula(wb, ws, sprintf("=SQRT(P%d^2+Q%d^2)/SQRT(P$%d^2+Q$%d^2)", r, r, rr + 8, rr + 8), startRow = r, startCol = 18)
  }
  addStyle(wb, ws, num2, rows = (rr + 8):(rr + 7 + length(pens)), cols = 16:17, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = (rr + 8):(rr + 7 + length(pens)), cols = 18, gridExpand = TRUE)
  writeData(wb, ws, paste(
    "Coefficients are points of completion per standard deviation of the predictor. At penalty 0 they equal",
    "LINEST on the z-scored columns; as the penalty grows both shrink toward zero. The lasso has no closed form,",
    "and a full tree repeats the split search inside every leaf: both belong in R or Python."
  ), startRow = rr + 16, startCol = 15)
  addStyle(wb, ws, note, rows = rr + 16, cols = 15)
  mergeCells(wb, ws, cols = 15:20, rows = rr + 16)
  setRowHeights(wb, ws, rows = rr + 16, heights = 60)
  setColWidths(wb, ws, cols = 1:20, widths = c(9, 40, 18, 9, 10, 10, 10, 10, 10, 10, 8, 10, 12, 3, 44, 12, 12, 12, 14, 16))
  freezePane(wb, ws, firstActiveRow = 2)

  # ---- outliers -------------------------------------------------------
  # Fences, ordinary and robust z-scores, then leverage and Cook's distance
  # for the regression of completion on headcount, one helper column each,
  # and a winsorized summary of the student-faculty ratio in the panel.
  ol <- institutions |>
    dplyr::filter(level == "4-year", bach_cohort >= 30, !is.na(grad_rate_bach_6yr),
                  !is.na(stu_fac_ratio), !is.na(pct_pell)) |>
    dplyr::select(unitid, name, control, headcount, stu_fac_ratio, pct_pell, grad_rate_bach_6yr) |>
    as.data.frame()
  n <- nrow(ol)
  last <- n + 1
  rows <- 2:last
  addWorksheet(wb, "outliers")
  ws <- "outliers"
  writeData(wb, ws, ol, startRow = 1, startCol = 1, headerStyle = hdr)
  writeData(wb, ws, t(c("z_headcount", "robust_z_headcount", "above_fence", "leverage", "residual",
                        "cooks_distance", "log_headcount")), startRow = 1, startCol = 8, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 1, cols = 8:14)
  writeFormula(wb, ws, sprintf("=STANDARDIZE(D%d,AVERAGE(D$2:D$%d),STDEV.S(D$2:D$%d))", rows, last, last),
               startRow = 2, startCol = 8)
  writeFormula(wb, ws, sprintf("=(D%d-MEDIAN(D$2:D$%d))/(1.4826*$Q$9)", rows, last), startRow = 2, startCol = 9)
  writeFormula(wb, ws, sprintf("=IF(D%d>$Q$8,1,0)", rows), startRow = 2, startCol = 10)
  writeFormula(wb, ws, sprintf("=1/$Q$4+(D%d-AVERAGE(D$2:D$%d))^2/DEVSQ(D$2:D$%d)", rows, last, last),
               startRow = 2, startCol = 11)
  writeFormula(wb, ws, sprintf("=G%d-($Q$14+$Q$15*D%d)", rows, rows), startRow = 2, startCol = 12)
  writeFormula(wb, ws, sprintf("=(L%d^2/(2*$Q$17))*(K%d/(1-K%d)^2)", rows, rows, rows), startRow = 2, startCol = 13)
  writeFormula(wb, ws, sprintf("=LOG10(D%d)", rows), startRow = 2, startCol = 14)
  addStyle(wb, ws, num2, rows = rows, cols = c(8, 9, 12, 14), gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.0000"), rows = rows, cols = c(11, 13), gridExpand = TRUE)

  writeData(wb, ws, "Outliers and leverage", startRow = 1, startCol = 16)
  addStyle(wb, ws, title, rows = 1, cols = 16)
  writeData(wb, ws, paste(
    "4-year institutions with a bachelor's cohort of at least 30 and a value in every column here.",
    "Columns H to N score headcount (D): the ordinary z-score, the robust z-score built from the median and",
    "the MAD, a fence flag, then leverage, residual, and Cook's distance for the regression of completion (G)",
    "on headcount. The MAD, AVERAGE(IF()), and STDEV.S(IF()) cells are array formulas."
  ), startRow = 2, startCol = 16)
  addStyle(wb, ws, note, rows = 2, cols = 16)
  mergeCells(wb, ws, cols = 16:21, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 60)
  writeData(wb, ws, t(c("Fences and scores for headcount", "Value")), startRow = 3, startCol = 16, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 3, cols = 16:17)
  ol_labels <- c("Institutions (n)", "First quartile", "Third quartile", "Lower fence", "Upper fence",
                 "MAD (median absolute deviation)", "Rows above the upper fence", "Rows with |z| > 3",
                 "Rows with robust |z| > 3.5")
  ol_forms <- c(
    sprintf("=COUNT(D2:D%d)", last),
    sprintf("=QUARTILE.INC(D2:D%d,1)", last),
    sprintf("=QUARTILE.INC(D2:D%d,3)", last),
    "=Q5-1.5*(Q6-Q5)",
    "=Q6+1.5*(Q6-Q5)",
    sprintf("=MEDIAN(ABS(D2:D%d-MEDIAN(D2:D%d)))", last, last),
    "=COUNTIF(D2:D%d,\">\"&Q8)",
    sprintf("=SUMPRODUCT(--(ABS(H2:H%d)>3))", last),
    sprintf("=SUMPRODUCT(--(ABS(I2:I%d)>3.5))", last)
  )
  ol_forms[7] <- sprintf(ol_forms[7], last)
  writeData(wb, ws, ol_labels, startRow = 4, startCol = 16)
  for (i in seq_along(ol_forms)) writeFormula(wb, ws, ol_forms[i], startRow = 3 + i, startCol = 17, array = (i == 6))
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = 4:12, cols = 17, gridExpand = TRUE)

  writeData(wb, ws, t(c("Regression of completion on headcount", "Value")), startRow = 13, startCol = 16, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 13, cols = 16:17)
  lev_labels <- c("Intercept", "Slope (points per student)", "Sum of squared residuals", "Residual variance (s squared)",
                  "Largest Cook's distance", "Most influential institution", "Its leverage", "Average leverage (2 / n)",
                  "Cook's distance flag (4 / n)", "Rows over the flag")
  lev_forms <- c(
    sprintf("=INTERCEPT(G2:G%d,D2:D%d)", last, last),
    sprintf("=SLOPE(G2:G%d,D2:D%d)", last, last),
    sprintf("=SUMSQ(L2:L%d)", last),
    "=Q16/(Q4-2)",
    sprintf("=MAX(M2:M%d)", last),
    sprintf("=INDEX(B2:B%d,MATCH(Q18,M2:M%d,0))", last, last),
    sprintf("=INDEX(K2:K%d,MATCH(Q18,M2:M%d,0))", last, last),
    "=2/Q4",
    "=4/Q4",
    sprintf("=COUNTIF(M2:M%d,\">\"&Q22)", last)
  )
  writeData(wb, ws, lev_labels, startRow = 14, startCol = 16)
  for (i in seq_along(lev_forms)) writeFormula(wb, ws, lev_forms[i], startRow = 13 + i, startCol = 17)
  addStyle(wb, ws, createStyle(numFmt = "0.0000"), rows = c(14, 15, 17, 18, 20, 21, 22), cols = 17, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = c(16, 23), cols = 17, gridExpand = TRUE)

  writeData(wb, ws, t(c("Transform instead of delete", "Value")), startRow = 24, startCol = 16, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 24, cols = 16:17)
  writeData(wb, ws, c("r, headcount and completion", "r, log10 headcount and completion",
                      "Slope on log10 headcount (points per tenfold)"), startRow = 25, startCol = 16)
  writeFormula(wb, ws, sprintf("=CORREL(D2:D%d,G2:G%d)", last, last), startRow = 25, startCol = 17)
  writeFormula(wb, ws, sprintf("=CORREL(N2:N%d,G2:G%d)", last, last), startRow = 26, startCol = 17)
  writeFormula(wb, ws, sprintf("=SLOPE(G2:G%d,N2:N%d)", last, last), startRow = 27, startCol = 17)
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = 25:27, cols = 17, gridExpand = TRUE)

  writeData(wb, ws, t(c("Four treatments of the student-faculty ratio (E)", "Value")), startRow = 29, startCol = 16, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 29, cols = 16:17)
  win_labels <- c("99th percentile (the cap)", "Mean, every row", "SD, every row", "Mean, capped at the 99th percentile",
                  "SD, capped at the 99th percentile", "Median, every row", "MAD, every row")
  win_forms <- c(
    sprintf("=PERCENTILE.INC(E2:E%d,0.99)", last),
    sprintf("=AVERAGE(E2:E%d)", last),
    sprintf("=STDEV.S(E2:E%d)", last),
    sprintf("=AVERAGE(IF(E2:E%d>Q30,Q30,E2:E%d))", last, last),
    sprintf("=STDEV.S(IF(E2:E%d>Q30,Q30,E2:E%d))", last, last),
    sprintf("=MEDIAN(E2:E%d)", last),
    sprintf("=1.4826*MEDIAN(ABS(E2:E%d-MEDIAN(E2:E%d)))", last, last)
  )
  writeData(wb, ws, win_labels, startRow = 30, startCol = 16)
  for (i in seq_along(win_forms)) writeFormula(wb, ws, win_forms[i], startRow = 29 + i, startCol = 17, array = i %in% c(4, 5, 7))
  addStyle(wb, ws, num2, rows = 30:36, cols = 17, gridExpand = TRUE)
  writeData(wb, ws, paste(
    "Dropping rows is a fifth treatment, and the only one this sheet does not do: whatever you choose,",
    "report the statistic with and without, and name the rule. Data > Data Analysis > Regression writes",
    "residuals but not leverage or Cook's distance."
  ), startRow = 38, startCol = 16)
  addStyle(wb, ws, note, rows = 38, cols = 16)
  mergeCells(wb, ws, cols = 16:21, rows = 38)
  setRowHeights(wb, ws, rows = 38, heights = 48)
  setColWidths(wb, ws, cols = 1:21, widths = c(9, 40, 18, 10, 9, 9, 10, 10, 10, 9, 10, 10, 12, 10, 3, 44, 14, 3, 3, 3, 3))
  freezePane(wb, ws, firstActiveRow = 2)

  # ---- many-groups ----------------------------------------------------
  # One-way ANOVA of completion across the eight mainland regions from the
  # per-group counts, means, and variances, then the pairwise t-test matrix
  # with the pooled within-group variance and its Bonferroni version.
  mg <- institutions |>
    dplyr::filter(level == "4-year", bach_cohort >= 30, !is.na(grad_rate_bach_6yr), !is.na(region),
                  !region %in% c("US service schools", "Outlying areas")) |>
    dplyr::select(unitid, name, region, grad_rate_bach_6yr, retention_ft) |>
    as.data.frame()
  n <- nrow(mg)
  last <- n + 1
  region_means <- tapply(mg$grad_rate_bach_6yr, mg$region, mean)
  regions <- names(sort(region_means, decreasing = TRUE))
  k <- length(regions)
  addWorksheet(wb, "many-groups")
  ws <- "many-groups"
  writeData(wb, ws, mg, startRow = 1, startCol = 1, headerStyle = hdr)
  addStyle(wb, ws, num1, rows = 2:last, cols = 4:5, gridExpand = TRUE)

  writeData(wb, ws, "Many groups: one-way ANOVA of 6-year completion by region", startRow = 1, startCol = 7)
  addStyle(wb, ws, title, rows = 1, cols = 7)
  writeData(wb, ws, paste(
    "Region is column C and completion is column D. Each region row below has its count, mean, and variance",
    "(an array VAR.S(IF()) formula), and the sums of squares come from those rows: between is n times the squared",
    "gap from the grand mean, within is (n - 1) times the variance. F.DIST.RT turns F into a p-value."
  ), startRow = 2, startCol = 7)
  addStyle(wb, ws, note, rows = 2, cols = 7)
  mergeCells(wb, ws, cols = 7:16, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 48)
  writeData(wb, ws, t(c("Region", "n", "Mean", "Variance", "SS within", "SS between")), startRow = 4, startCol = 7, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 4, cols = 7:12)
  writeData(wb, ws, regions, startRow = 5, startCol = 7)
  for (i in seq_len(k)) {
    r <- 4 + i
    writeFormula(wb, ws, sprintf("=COUNTIF($C$2:$C$%d,G%d)", last, r), startRow = r, startCol = 8)
    writeFormula(wb, ws, sprintf("=AVERAGEIF($C$2:$C$%d,G%d,$D$2:$D$%d)", last, r, last), startRow = r, startCol = 9)
    writeFormula(wb, ws, sprintf("=VAR.S(IF($C$2:$C$%d=G%d,$D$2:$D$%d))", last, r, last), startRow = r, startCol = 10, array = TRUE)
    writeFormula(wb, ws, sprintf("=(H%d-1)*J%d", r, r), startRow = r, startCol = 11)
    writeFormula(wb, ws, sprintf("=H%d*(I%d-$H$15)^2", r, r), startRow = r, startCol = 12)
  }
  g_last <- 4 + k
  addStyle(wb, ws, num1, rows = 5:g_last, cols = 9:10, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = 5:g_last, cols = 11:12, gridExpand = TRUE)

  writeData(wb, ws, t(c("ANOVA", "Value")), startRow = 14, startCol = 7, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 14, cols = 7:8)
  an_labels <- c("Grand mean", "Institutions", "Groups", "SS between", "SS within", "SS total (check: between + within)",
                 "df between", "df within", "MS between", "MS within", "F", "p-value", "Eta squared", "Within-group SD")
  an_forms <- c(
    sprintf("=AVERAGE(D2:D%d)", last),
    sprintf("=COUNT(D2:D%d)", last),
    sprintf("=COUNTA(G5:G%d)", g_last),
    sprintf("=SUM(L5:L%d)", g_last),
    sprintf("=SUM(K5:K%d)", g_last),
    sprintf("=DEVSQ(D2:D%d)", last),
    "=H17-1",
    "=H16-H17",
    "=H18/H21",
    "=H19/H22",
    "=H23/H24",
    "=F.DIST.RT(H25,H21,H22)",
    "=H18/(H18+H19)",
    "=SQRT(H24)"
  )
  writeData(wb, ws, an_labels, startRow = 15, startCol = 7)
  for (i in seq_along(an_forms)) writeFormula(wb, ws, an_forms[i], startRow = 14 + i, startCol = 8)
  addStyle(wb, ws, num2, rows = c(15, 23, 24, 25, 28), cols = 8, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = c(16:22), cols = 8, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.00E+00"), rows = 26, cols = 8)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 27, cols = 8)

  # Pairwise matrix: pooled-variance t-tests, as R's pairwise.t.test() does.
  pm <- 31
  writeData(wb, ws, "Pairwise p-values, pooled within-group variance (diagonal set to 1)", startRow = pm - 1, startCol = 7)
  addStyle(wb, ws, hdr, rows = pm - 1, cols = 7:(8 + k))
  writeData(wb, ws, t(regions), startRow = pm, startCol = 8, colNames = FALSE)
  writeData(wb, ws, regions, startRow = pm + 1, startCol = 7)
  addStyle(wb, ws, hdr, rows = pm, cols = 7:(7 + k))
  bm <- pm + k + 3
  writeData(wb, ws, "The same p-values after Bonferroni (times the number of pairs, capped at 1)", startRow = bm - 1, startCol = 7)
  addStyle(wb, ws, hdr, rows = bm - 1, cols = 7:(8 + k))
  writeData(wb, ws, t(regions), startRow = bm, startCol = 8, colNames = FALSE)
  writeData(wb, ws, regions, startRow = bm + 1, startCol = 7)
  addStyle(wb, ws, hdr, rows = bm, cols = 7:(7 + k))
  n_pairs <- k * (k - 1) / 2
  for (i in seq_len(k)) for (j in seq_len(k)) {
    ri <- 4 + i; rj <- 4 + j
    cell_col <- 7 + j
    if (i == j) {
      writeData(wb, ws, 1, startRow = pm + i, startCol = cell_col)
      writeData(wb, ws, 1, startRow = bm + i, startCol = cell_col)
    } else {
      writeFormula(wb, ws, sprintf("=T.DIST.2T(ABS((I%d-I%d)/SQRT($H$24*(1/H%d+1/H%d))),$H$22)", ri, rj, ri, rj),
                   startRow = pm + i, startCol = cell_col)
      writeFormula(wb, ws, sprintf("=MIN(1,%s%d*%d)", int2col(cell_col), pm + i, n_pairs), startRow = bm + i, startCol = cell_col)
    }
  }
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = c((pm + 1):(pm + k), (bm + 1):(bm + k)), cols = 8:(7 + k), gridExpand = TRUE)
  cnt <- bm + k + 2
  writeData(wb, ws, c("Pairs", "Pairs significant at 0.05, no correction", "Pairs significant at 0.05, Bonferroni"),
            startRow = cnt, startCol = 7)
  writeData(wb, ws, n_pairs, startRow = cnt, startCol = 8)
  writeFormula(wb, ws, sprintf("=SUMPRODUCT(--(%s%d:%s%d<0.05))/2", int2col(8), pm + 1, int2col(7 + k), pm + k), startRow = cnt + 1, startCol = 8)
  writeFormula(wb, ws, sprintf("=SUMPRODUCT(--(%s%d:%s%d<0.05))/2", int2col(8), bm + 1, int2col(7 + k), bm + k), startRow = cnt + 2, startCol = 8)
  writeData(wb, ws, paste(
    "Each cell is the two-sided p-value of a t-test between two region means using MS within as the shared variance",
    "and df within, which matches R's pairwise.t.test(). Tukey's HSD needs the studentized range distribution,",
    "which Excel does not have. Data > Data Analysis > Anova: Single Factor writes the ANOVA table from one column per group."
  ), startRow = cnt + 4, startCol = 7)
  addStyle(wb, ws, note, rows = cnt + 4, cols = 7)
  mergeCells(wb, ws, cols = 7:16, rows = cnt + 4)
  setRowHeights(wb, ws, rows = cnt + 4, heights = 60)
  setColWidths(wb, ws, cols = 1:16, widths = c(9, 40, 16, 10, 10, 3, 34, 12, rep(11, 8)))
  freezePane(wb, ws, firstActiveRow = 2)

  # ---- classify -------------------------------------------------------
  # Two-predictor logistic regression (Pell share and retention) fitted on
  # the training rows, seeded with the maximum-likelihood coefficients, a
  # threshold cell driving the flag column, and the confusion matrix, rates,
  # and AUC scored on the test block.
  cl <- institutions |>
    dplyr::filter(level == "4-year", bach_cohort >= 30,
                  carnegie %in% c("Doctoral", "Master's", "Baccalaureate", "Special focus")) |>
    dplyr::mutate(log_headcount = log10(headcount)) |>
    dplyr::select(unitid, name, control, locale, carnegie, hbcu, pct_pell, net_price, stu_fac_ratio,
                  log_headcount, pct_any_grant, pct_women_ug, pct_white_ug, pct_black_ug, pct_hispanic_ug,
                  pct_asian_ug, pct_intl_ug, retention_ft, grad_rate_bach_6yr) |>
    tidyr::drop_na() |>
    dplyr::mutate(split = ifelse(unitid %% 10 < 7, "train", "test")) |>
    dplyr::arrange(split == "test", unitid) |>
    dplyr::select(unitid, name, control, pct_pell, retention_ft, grad_rate_bach_6yr, split) |>
    as.data.frame()
  cl_fit <- glm(I(grad_rate_bach_6yr < 50) ~ pct_pell + retention_ft, family = binomial,
                data = cl[cl$split == "train", ])
  n <- nrow(cl)
  last <- n + 1
  n_train <- sum(cl$split == "train")
  tr_last <- n_train + 1
  te_first <- n_train + 2
  cl$split <- NULL
  addWorksheet(wb, "classify")
  ws <- "classify"
  writeData(wb, ws, cl, startRow = 1, startCol = 1, headerStyle = hdr)
  writeData(wb, ws, t(c("low", "split", "probability", "log-likelihood", "flag", "rank (test rows)")),
            startRow = 1, startCol = 7, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 1, cols = 7:12)
  rows <- 2:last
  writeFormula(wb, ws, sprintf("=IF(F%d<50,1,0)", rows), startRow = 2, startCol = 7)
  writeFormula(wb, ws, sprintf("=IF(MOD(A%d,10)<7,\"train\",\"test\")", rows), startRow = 2, startCol = 8)
  writeFormula(wb, ws, sprintf("=1/(1+EXP(-($O$4+$O$5*D%d+$O$6*E%d)))", rows, rows), startRow = 2, startCol = 9)
  writeFormula(wb, ws, sprintf("=G%d*LN(I%d)+(1-G%d)*LN(1-I%d)", 2:tr_last, 2:tr_last, 2:tr_last, 2:tr_last),
               startRow = 2, startCol = 10)
  writeFormula(wb, ws, sprintf("=IF(I%d>=$O$9,1,0)", rows), startRow = 2, startCol = 11)
  writeFormula(wb, ws, sprintf("=RANK.AVG(I%d,I$%d:I$%d,1)", te_first:last, te_first, last), startRow = te_first, startCol = 12)
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = rows, cols = 9:10, gridExpand = TRUE)

  writeData(wb, ws, "Predict a yes or no", startRow = 1, startCol = 14)
  addStyle(wb, ws, title, rows = 1, cols = 14)
  writeData(wb, ws, paste(
    "Outcome: 6-year completion under 50% (column G). Training rows (last digit of unitid 0-6) are rows 2 to", tr_last,
    "and the test rows follow. The coefficients below are the maximum-likelihood fit on the training rows;",
    "Solver (maximize O7 by changing O4:O6, GRG Nonlinear) reaches them from 0, 0, 0. Every count from row 10 down",
    "scores the test rows only, and changing the threshold in O9 moves all of them."
  ), startRow = 2, startCol = 14)
  addStyle(wb, ws, note, rows = 2, cols = 14)
  mergeCells(wb, ws, cols = 14:20, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 72)
  writeData(wb, ws, c("Intercept", "Pell coefficient (per point)", "Retention coefficient (per point)",
                      "Log-likelihood on training rows (maximize)"), startRow = 4, startCol = 14)
  writeData(wb, ws, unname(coef(cl_fit)[1]), startRow = 4, startCol = 15)
  writeData(wb, ws, unname(coef(cl_fit)[2]), startRow = 5, startCol = 15)
  writeData(wb, ws, unname(coef(cl_fit)[3]), startRow = 6, startCol = 15)
  writeFormula(wb, ws, sprintf("=SUM(J2:J%d)", tr_last), startRow = 7, startCol = 15)
  addStyle(wb, ws, createStyle(numFmt = "0.0000"), rows = 4:6, cols = 15, gridExpand = TRUE)
  addStyle(wb, ws, num1, rows = 7, cols = 15)
  writeData(wb, ws, "Threshold: flag when the probability is at least", startRow = 9, startCol = 14)
  writeData(wb, ws, 0.5, startRow = 9, startCol = 15)
  addStyle(wb, ws, createStyle(numFmt = "0.00", fgFill = "#fff3e8"), rows = 9, cols = 15)
  te <- function(col) sprintf("%s%d:%s%d", col, te_first, col, last)
  cm_labels <- c("Test rows", "Low-completion rows among them", "True positives (caught)", "False positives (false alarms)",
                 "False negatives (missed)", "True negatives", "Accuracy", "Precision", "Recall", "Specificity",
                 "Flagged", "AUC (rank formula)")
  cm_forms <- c(
    sprintf("=COUNT(%s)", te("G")),
    sprintf("=SUM(%s)", te("G")),
    sprintf("=SUMPRODUCT((%s=1)*(%s=1))", te("K"), te("G")),
    sprintf("=SUMPRODUCT((%s=1)*(%s=0))", te("K"), te("G")),
    sprintf("=SUMPRODUCT((%s=0)*(%s=1))", te("K"), te("G")),
    sprintf("=SUMPRODUCT((%s=0)*(%s=0))", te("K"), te("G")),
    "=(O12+O15)/O10",
    "=O12/(O12+O13)",
    "=O12/(O12+O14)",
    "=O15/(O15+O13)",
    "=O12+O13",
    sprintf("=(SUMPRODUCT(%s,%s)-O11*(O11+1)/2)/(O11*(O10-O11))", te("L"), te("G"))
  )
  writeData(wb, ws, cm_labels, startRow = 10, startCol = 14)
  for (i in seq_along(cm_forms)) writeFormula(wb, ws, cm_forms[i], startRow = 9 + i, startCol = 15)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 16:19, cols = 15, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = 21, cols = 15)

  writeData(wb, ws, t(c("Threshold", "Caught", "False alarms", "Missed", "Left alone", "Precision", "Recall", "Flagged")),
            startRow = 24, startCol = 14, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 24, cols = 14:21)
  ths <- seq(0.1, 0.9, by = 0.1)
  writeData(wb, ws, ths, startRow = 25, startCol = 14)
  for (i in seq_along(ths)) {
    r <- 24 + i
    writeFormula(wb, ws, sprintf("=SUMPRODUCT((%s>=N%d)*(%s=1))", te("I"), r, te("G")), startRow = r, startCol = 15)
    writeFormula(wb, ws, sprintf("=SUMPRODUCT((%s>=N%d)*(%s=0))", te("I"), r, te("G")), startRow = r, startCol = 16)
    writeFormula(wb, ws, sprintf("=SUMPRODUCT((%s<N%d)*(%s=1))", te("I"), r, te("G")), startRow = r, startCol = 17)
    writeFormula(wb, ws, sprintf("=SUMPRODUCT((%s<N%d)*(%s=0))", te("I"), r, te("G")), startRow = r, startCol = 18)
    writeFormula(wb, ws, sprintf("=O%d/(O%d+P%d)", r, r, r), startRow = r, startCol = 19)
    writeFormula(wb, ws, sprintf("=O%d/(O%d+Q%d)", r, r, r), startRow = r, startCol = 20)
    writeFormula(wb, ws, sprintf("=O%d+P%d", r, r), startRow = r, startCol = 21)
  }
  th_last <- 24 + length(ths)
  addStyle(wb, ws, createStyle(numFmt = "0.0"), rows = 25:th_last, cols = 14, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 25:th_last, cols = 19:20, gridExpand = TRUE)
  writeData(wb, ws, paste(
    "Recall falls and precision rises as the threshold climbs; the model never changes, only the line through its",
    "probabilities. The AUC uses the rank of each test probability (column L): the sum of the ranks of the low-completion",
    "rows, corrected for their own count, over the number of low-and-not-low pairs."
  ), startRow = th_last + 2, startCol = 14)
  addStyle(wb, ws, note, rows = th_last + 2, cols = 14)
  mergeCells(wb, ws, cols = 14:21, rows = th_last + 2)
  setRowHeights(wb, ws, rows = th_last + 2, heights = 60)
  setColWidths(wb, ws, cols = 1:21, widths = c(9, 40, 18, 9, 10, 10, 6, 8, 11, 13, 6, 14, 3, 44, 12, 12, 10, 11, 10, 10, 10))
  freezePane(wb, ws, firstActiveRow = 2)

  # ---- subtotals ------------------------------------------------------
  # Every fall 2023 enrollment row for one state's institutions, as IPEDS
  # ships them, with the codes table beside them. INDEX/MATCH lookups turn
  # the codes into words, and the sums show every row against the detail
  # lines and the reported total, institution by institution and in all.
  ri_ids <- institutions$unitid[institutions$state == "RI"]
  st <- lines |>
    dplyr::filter(unitid %in% ri_ids) |>
    dplyr::inner_join(dplyr::select(institutions, unitid, name), by = "unitid") |>
    dplyr::arrange(unitid, efalevel) |>
    dplyr::select(unitid, name, efalevel, line, section, lstudy, eftotlt) |>
    as.data.frame()
  n <- nrow(st)
  last <- n + 1
  ws <- "subtotals"
  addWorksheet(wb, ws)
  writeData(wb, ws, st, startRow = 1, startCol = 1, headerStyle = hdr)
  writeData(wb, ws, t(c("kind", "attendance", "category")), startRow = 1, startCol = 8, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 1, cols = 8:10)
  rows <- 2:last
  writeFormula(wb, ws, sprintf("=INDEX($AD$2:$AD$28,MATCH(C%d,$W$2:$W$28,0))", rows), startRow = 2, startCol = 8)
  writeFormula(wb, ws, sprintf("=INDEX($AA$2:$AA$28,MATCH(C%d,$W$2:$W$28,0))", rows), startRow = 2, startCol = 9)
  writeFormula(wb, ws, sprintf("=INDEX($AC$2:$AC$28,MATCH(C%d,$W$2:$W$28,0))", rows), startRow = 2, startCol = 10)
  cd <- codes[, c("efalevel", "line", "section", "lstudy", "attendance", "level", "category", "kind", "label")]
  writeData(wb, ws, as.data.frame(cd), startRow = 1, startCol = 23, headerStyle = hdr)
  addStyle(wb, ws, mono, rows = 2:28, cols = 23:26, gridExpand = TRUE)

  insts <- unique(st[, c("unitid", "name")])
  k <- nrow(insts)
  writeData(wb, ws, "The subtotal trap: every fall 2023 enrollment row for Rhode Island", startRow = 1, startCol = 12)
  addStyle(wb, ws, title, rows = 1, cols = 12)
  writeData(wb, ws, paste(
    "Columns A to G are the rows as IPEDS ships them; H to J look each row's EFALEVEL up in the codes table in",
    "columns W to AE. Every row adds the same students several times over; the detail lines add each student",
    "once and reproduce the reported total (LINE 29). The grain block below is a SUMIFS grid on the lookup columns."
  ), startRow = 2, startCol = 12)
  addStyle(wb, ws, note, rows = 2, cols = 12)
  mergeCells(wb, ws, cols = 12:21, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 60)
  writeData(wb, ws, t(c("Institution", "unitid", "Rows", "Every row", "Reported total (LINE 29)", "Detail lines",
                        "Times the real headcount")), startRow = 4, startCol = 12, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 4, cols = 12:18)
  writeData(wb, ws, insts$name, startRow = 5, startCol = 12)
  writeData(wb, ws, insts$unitid, startRow = 5, startCol = 13)
  for (i in seq_len(k)) {
    r <- 4 + i
    writeFormula(wb, ws, sprintf("=COUNTIF($A$2:$A$%d,M%d)", last, r), startRow = r, startCol = 14)
    writeFormula(wb, ws, sprintf("=SUMIF($A$2:$A$%d,M%d,$G$2:$G$%d)", last, r, last), startRow = r, startCol = 15)
    writeFormula(wb, ws, sprintf("=SUMIFS($G$2:$G$%d,$A$2:$A$%d,M%d,$D$2:$D$%d,29)", last, last, r, last), startRow = r, startCol = 16)
    writeFormula(wb, ws, sprintf("=SUMIFS($G$2:$G$%d,$A$2:$A$%d,M%d,$H$2:$H$%d,\"Detail\")", last, last, r, last), startRow = r, startCol = 17)
    writeFormula(wb, ws, sprintf("=O%d/P%d", r, r), startRow = r, startCol = 18)
  }
  tot <- 5 + k
  writeData(wb, ws, "All institutions", startRow = tot, startCol = 12)
  for (cc in 14:17) writeFormula(wb, ws, sprintf("=SUM(%s5:%s%d)", int2col(cc), int2col(cc), tot - 1), startRow = tot, startCol = cc)
  writeFormula(wb, ws, sprintf("=O%d/P%d", tot, tot), startRow = tot, startCol = 18)
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = 5:tot, cols = 14:17, gridExpand = TRUE)
  addStyle(wb, ws, num1, rows = 5:tot, cols = 18, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(textDecoration = "bold"), rows = tot, cols = 12:18, gridExpand = TRUE)

  gr <- tot + 3
  writeData(wb, ws, "The clean grain: detail lines by attendance and category", startRow = gr - 1, startCol = 12)
  addStyle(wb, ws, hdr, rows = gr - 1, cols = 12:15)
  writeData(wb, ws, t(c("Category", "Full-time", "Part-time", "All")), startRow = gr, startCol = 12, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = gr, cols = 12:15)
  cats <- c("First-time", "Transfer-in", "Continuing", "Non-degree", "Graduate")
  writeData(wb, ws, cats, startRow = gr + 1, startCol = 12)
  for (i in seq_along(cats)) {
    r <- gr + i
    for (cc in 13:14) {
      writeFormula(wb, ws, sprintf("=SUMIFS($G$2:$G$%d,$H$2:$H$%d,\"Detail\",$I$2:$I$%d,%s$%d,$J$2:$J$%d,$L%d)",
                                   last, last, last, int2col(cc), gr, last, r), startRow = r, startCol = cc)
    }
    writeFormula(wb, ws, sprintf("=M%d+N%d", r, r), startRow = r, startCol = 15)
  }
  gt <- gr + length(cats) + 1
  writeData(wb, ws, "All", startRow = gt, startCol = 12)
  for (cc in 13:15) writeFormula(wb, ws, sprintf("=SUM(%s%d:%s%d)", int2col(cc), gr + 1, int2col(cc), gt - 1), startRow = gt, startCol = cc)
  writeData(wb, ws, "Check: grain total minus the reported totals (0 when the grain is right)", startRow = gt + 1, startCol = 12)
  writeFormula(wb, ws, sprintf("=O%d-P%d", gt, tot), startRow = gt + 1, startCol = 15)
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = (gr + 1):(gt + 1), cols = 13:15, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(textDecoration = "bold"), rows = gt, cols = 12:15, gridExpand = TRUE)
  setColWidths(wb, ws, cols = 1:31, widths = c(9, 36, 9, 6, 8, 7, 9, 11, 11, 20, 3, 40, 9, 8, 12, 14, 12, 12, 3, 3, 3, 3,
                                              9, 6, 8, 7, 11, 14, 20, 11, 70))
  freezePane(wb, ws, firstActiveRow = 2)

  # ---- proportions ----------------------------------------------------
  # Control by locale as a COUNTIFS grid on the Institutions table, the
  # expected counts from the margins, the chi-square statistic and its
  # p-value three ways, adjusted residuals, and Wilson and two-proportion
  # blocks on the rural column.
  ws <- "proportions"
  addWorksheet(wb, ws)
  controls <- c("Public", "Private nonprofit", "Private for-profit")
  locales <- c("City", "Suburb", "Town", "Rural")
  writeData(wb, ws, "Counts and proportions: control by locale", startRow = 1, startCol = 2)
  addStyle(wb, ws, title, rows = 1, cols = 2)
  writeData(wb, ws, paste(
    "The observed table counts the Institutions table with COUNTIFS. Expected counts are row total times column",
    "total over the grand total. Chi-square is the sum of (O - E)^2 / E, its p-value comes from CHISQ.DIST.RT and,",
    "in one step, CHISQ.TEST. Residuals are adjusted standardized residuals, matching R's chisq.test()$stdres."
  ), startRow = 2, startCol = 2)
  addStyle(wb, ws, note, rows = 2, cols = 2)
  mergeCells(wb, ws, cols = 2:17, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 48)
  block <- function(top, label, cell_formula) {
    writeData(wb, ws, t(c(label, locales, if (identical(label, "Observed")) "Total")), startRow = top, startCol = 2, colNames = FALSE)
    addStyle(wb, ws, hdr, rows = top, cols = 2:(if (identical(label, "Observed")) 7 else 6))
    writeData(wb, ws, controls, startRow = top + 1, startCol = 2)
    for (i in 1:3) for (j in 1:4) {
      writeFormula(wb, ws, cell_formula(top + i, int2col(2 + j), i, j), startRow = top + i, startCol = 2 + j)
    }
  }
  block(4, "Observed", function(r, col, i, j) sprintf("=COUNTIFS(Institutions[control],$B%d,Institutions[locale],%s$4)", r, col))
  for (i in 1:3) writeFormula(wb, ws, sprintf("=SUM(C%d:F%d)", 4 + i, 4 + i), startRow = 4 + i, startCol = 7)
  writeData(wb, ws, "Total", startRow = 8, startCol = 2)
  for (j in 3:7) writeFormula(wb, ws, sprintf("=SUM(%s5:%s7)", int2col(j), int2col(j)), startRow = 8, startCol = j)
  addStyle(wb, ws, createStyle(textDecoration = "bold"), rows = 8, cols = 2:7, gridExpand = TRUE)
  block(10, "Expected", function(r, col, i, j) sprintf("=$G%d*%s$8/$G$8", 4 + i, col))
  block(15, "(O - E)^2 / E", function(r, col, i, j) sprintf("=(%s%d-%s%d)^2/%s%d", col, 4 + i, col, 10 + i, col, 10 + i))
  block(20, "Adjusted residual", function(r, col, i, j) sprintf("=(%s%d-%s%d)/SQRT(%s%d*(1-$G%d/$G$8)*(1-%s$8/$G$8))", col, 4 + i, col, 10 + i, col, 10 + i, 4 + i, col))
  addStyle(wb, ws, num1, rows = 11:13, cols = 3:6, gridExpand = TRUE)
  addStyle(wb, ws, num1, rows = 16:18, cols = 3:6, gridExpand = TRUE)
  addStyle(wb, ws, num1, rows = 21:23, cols = 3:6, gridExpand = TRUE)

  writeData(wb, ws, t(c("Test", "Value")), startRow = 4, startCol = 9, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 4, cols = 9:10)
  test_labels <- c("Institutions (n)", "Rows", "Columns", "Degrees of freedom", "Chi-square", "p-value (CHISQ.DIST.RT)",
                   "p-value (CHISQ.TEST)", "Cramer's V", "Largest absolute residual")
  test_forms <- c("=G8", "=COUNTA(B5:B7)", "=COUNTA(C4:F4)", "=(J6-1)*(J7-1)", "=SUM(C16:F18)", "=CHISQ.DIST.RT(J9,J8)",
                  "=CHISQ.TEST(C5:F7,C11:F13)", "=SQRT(J9/(J5*(MIN(J6,J7)-1)))", "=MAX(ABS(C21:F23))")
  writeData(wb, ws, test_labels, startRow = 5, startCol = 9)
  for (i in seq_along(test_forms)) writeFormula(wb, ws, test_forms[i], startRow = 4 + i, startCol = 10, array = i == length(test_forms))
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = 5, cols = 10)
  addStyle(wb, ws, num1, rows = c(9, 13), cols = 10, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.00E+00"), rows = 10:11, cols = 10, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.000"), rows = 12, cols = 10)

  writeData(wb, ws, "Wilson 95% interval for the share of each control in a rural locale", startRow = 15, startCol = 9)
  addStyle(wb, ws, hdr, rows = 15, cols = 9:17)
  writeData(wb, ws, t(c("Control", "x (rural)", "n", "Share", "z", "Centre", "Half-width", "Lower", "Upper")),
            startRow = 16, startCol = 9, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 16, cols = 9:17)
  writeData(wb, ws, controls, startRow = 17, startCol = 9)
  for (i in 1:3) {
    r <- 16 + i
    writeFormula(wb, ws, sprintf("=F%d", 4 + i), startRow = r, startCol = 10)
    writeFormula(wb, ws, sprintf("=G%d", 4 + i), startRow = r, startCol = 11)
    writeFormula(wb, ws, sprintf("=J%d/K%d", r, r), startRow = r, startCol = 12)
    writeFormula(wb, ws, "=NORM.S.INV(0.975)", startRow = r, startCol = 13)
    writeFormula(wb, ws, sprintf("=(L%d+M%d^2/(2*K%d))/(1+M%d^2/K%d)", r, r, r, r, r), startRow = r, startCol = 14)
    writeFormula(wb, ws, sprintf("=M%d*SQRT(L%d*(1-L%d)/K%d+M%d^2/(4*K%d^2))/(1+M%d^2/K%d)", r, r, r, r, r, r, r, r), startRow = r, startCol = 15)
    writeFormula(wb, ws, sprintf("=N%d-O%d", r, r), startRow = r, startCol = 16)
    writeFormula(wb, ws, sprintf("=N%d+O%d", r, r), startRow = r, startCol = 17)
  }
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 17:19, cols = c(12, 14:17), gridExpand = TRUE)
  addStyle(wb, ws, num2, rows = 17:19, cols = 13, gridExpand = TRUE)

  writeData(wb, ws, "Two proportions: public against private nonprofit, rural share", startRow = 22, startCol = 9)
  addStyle(wb, ws, hdr, rows = 22, cols = 9:10)
  two_labels <- c("x1 (public, rural)", "n1 (public)", "x2 (nonprofit, rural)", "n2 (nonprofit)", "p1", "p2", "Difference",
                  "Pooled p", "z", "p-value (two-sided)", "Lower (95%)", "Upper (95%)")
  two_forms <- c("=F5", "=G5", "=F6", "=G6", "=J23/J24", "=J25/J26", "=J27-J28", "=(J23+J25)/(J24+J26)",
                 "=J29/SQRT(J30*(1-J30)*(1/J24+1/J26))", "=2*(1-NORM.S.DIST(ABS(J31),TRUE))",
                 "=J29-1.96*SQRT(J27*(1-J27)/J24+J28*(1-J28)/J26)", "=J29+1.96*SQRT(J27*(1-J27)/J24+J28*(1-J28)/J26)")
  writeData(wb, ws, two_labels, startRow = 23, startCol = 9)
  for (i in seq_along(two_forms)) writeFormula(wb, ws, two_forms[i], startRow = 22 + i, startCol = 10)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = c(27:30, 33:34), cols = 10, gridExpand = TRUE)
  addStyle(wb, ws, num2, rows = 31, cols = 10)
  addStyle(wb, ws, createStyle(numFmt = "0.00E+00"), rows = 32, cols = 10)
  writeData(wb, ws, paste(
    "The difference's interval is the Wald form that R's prop.test() reports without a continuity correction; z squared",
    "is the chi-square that prop.test() prints. There is no Fisher's exact test in Excel: when an expected count is",
    "under 5, collapse categories until every cell clears it, or take the question to R."
  ), startRow = 36, startCol = 9)
  addStyle(wb, ws, note, rows = 36, cols = 9)
  mergeCells(wb, ws, cols = 9:17, rows = 36)
  setRowHeights(wb, ws, rows = 36, heights = 48)
  setColWidths(wb, ws, cols = 1:17, widths = c(3, 20, 10, 10, 10, 10, 10, 3, 30, 12, 10, 10, 8, 10, 11, 10, 10))

  # ---- forecast -------------------------------------------------------
  # One row per institution with a fall headcount in every year 2013 to
  # 2023, six one-formula forecasts for fall 2023 made from the years to
  # 2022, their absolute percentage errors, and the medians by method and
  # by size that the lesson reports. The block at the right scores any
  # one institution and gives its 2024 forecast an empirical interval.
  yrs <- 2013:2023
  hc <- history |>
    dplyr::filter(!is.na(total), total > 0) |>
    dplyr::group_by(unitid) |>
    dplyr::filter(dplyr::n() == length(yrs)) |>
    dplyr::ungroup()
  fw <- hc |>
    dplyr::select(unitid, year, total) |>
    tidyr::pivot_wider(names_from = year, values_from = total, names_prefix = "fall_") |>
    dplyr::inner_join(dplyr::select(institutions, unitid, name), by = "unitid") |>
    dplyr::select(unitid, name, dplyr::everything()) |>
    dplyr::arrange(unitid) |>
    as.data.frame()
  n <- nrow(fw)
  last <- n + 1
  ws <- "forecast"
  addWorksheet(wb, ws)
  writeData(wb, ws, fw, startRow = 1, startCol = 1, headerStyle = hdr)
  method_names <- c("Last value", "Mean of last three", "Drift", "Half the last change", "Trend, last five years", "Trend, all years")
  writeData(wb, ws, t(c(method_names, paste("APE:", method_names), "Change 2022 to 2023")), startRow = 1, startCol = 14, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 1, cols = 14:26)
  rows <- 2:last
  writeFormula(wb, ws, sprintf("=L%d", rows), startRow = 2, startCol = 14)
  writeFormula(wb, ws, sprintf("=AVERAGE(J%d:L%d)", rows, rows), startRow = 2, startCol = 15)
  writeFormula(wb, ws, sprintf("=L%d+(L%d-C%d)/9", rows, rows, rows), startRow = 2, startCol = 16)
  writeFormula(wb, ws, sprintf("=L%d+0.5*(L%d-K%d)", rows, rows, rows), startRow = 2, startCol = 17)
  writeFormula(wb, ws, sprintf("=TREND(H%d:L%d,{1,2,3,4,5},6)", rows, rows), startRow = 2, startCol = 18)
  writeFormula(wb, ws, sprintf("=TREND(C%d:L%d,{1,2,3,4,5,6,7,8,9,10},11)", rows, rows), startRow = 2, startCol = 19)
  for (m in seq_along(method_names)) {
    fc_col <- int2col(13 + m)
    writeFormula(wb, ws, sprintf("=ABS(%s%d-$M%d)/$M%d", fc_col, rows, rows, rows), startRow = 2, startCol = 19 + m)
  }
  writeFormula(wb, ws, sprintf("=M%d/L%d-1", rows, rows), startRow = 2, startCol = 26)
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = rows, cols = 3:19, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = rows, cols = 20:26, gridExpand = TRUE)

  writeData(wb, ws, "Next fall: six forecasts for fall 2023, scored", startRow = 1, startCol = 28)
  addStyle(wb, ws, title, rows = 1, cols = 28)
  writeData(wb, ws, paste(
    "Columns C to M are fall headcount 2013 to 2023. Each forecast in N to S uses the years to 2022 only, and its",
    "absolute percentage error against column M sits in T to Y. The medians below are the lesson's scores for the",
    "2022 origin; the lesson pools six origins, so its numbers differ a little. The interval block uses the",
    "2022-to-2023 changes at institutions in the same size band (the lesson pools all ten years of changes)."
  ), startRow = 2, startCol = 28)
  addStyle(wb, ws, note, rows = 2, cols = 28)
  mergeCells(wb, ws, cols = 28:32, rows = 2)
  setRowHeights(wb, ws, rows = 2, heights = 84)
  writeData(wb, ws, t(c("Method", "Median APE", "Mean APE")), startRow = 4, startCol = 28, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 4, cols = 28:30)
  writeData(wb, ws, method_names, startRow = 5, startCol = 28)
  for (m in seq_along(method_names)) {
    ape_col <- int2col(19 + m)
    writeFormula(wb, ws, sprintf("=MEDIAN(%s$2:%s$%d)", ape_col, ape_col, last), startRow = 4 + m, startCol = 29)
    writeFormula(wb, ws, sprintf("=AVERAGE(%s$2:%s$%d)", ape_col, ape_col, last), startRow = 4 + m, startCol = 30)
  }
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 5:10, cols = 29:30, gridExpand = TRUE)

  writeData(wb, ws, t(c("Fall 2022 headcount", "From", "Below", "Median APE, last value", "Institutions")), startRow = 12, startCol = 28, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 12, cols = 28:32)
  bands <- data.frame(label = c("under 500", "500 to 1,999", "2,000 to 9,999", "10,000 and more"),
                      lo = c(0, 500, 2000, 10000), hi = c(500, 2000, 10000, 1e9))
  writeData(wb, ws, bands$label, startRow = 13, startCol = 28)
  writeData(wb, ws, bands$lo, startRow = 13, startCol = 29)
  writeData(wb, ws, bands$hi, startRow = 13, startCol = 30)
  for (i in seq_len(nrow(bands))) {
    r <- 12 + i
    writeFormula(wb, ws, sprintf("=MEDIAN(IF(($L$2:$L$%d>=AC%d)*($L$2:$L$%d<AD%d),$T$2:$T$%d))", last, r, last, r, last),
                 startRow = r, startCol = 31, array = TRUE)
    writeFormula(wb, ws, sprintf("=COUNTIFS($L$2:$L$%d,\">=\"&AC%d,$L$2:$L$%d,\"<\"&AD%d)", last, r, last, r), startRow = r, startCol = 32)
  }
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 13:16, cols = 31, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = 13:16, cols = c(29, 30, 32), gridExpand = TRUE)

  writeData(wb, ws, t(c("One institution", "Value")), startRow = 19, startCol = 28, colNames = FALSE)
  addStyle(wb, ws, hdr, rows = 19, cols = 28:29)
  one_labels <- c("unitid (type any from column A)", "Name", "Fall 2023", "Size band from", "Size band below",
                  "10th percentile of change in the band", "90th percentile of change in the band",
                  "Forecast for fall 2024 (last value)", "Lower (80% interval)", "Upper (80% interval)")
  one_forms <- c(
    NA,
    sprintf("=INDEX($B$2:$B$%d,MATCH(AC20,$A$2:$A$%d,0))", last, last),
    sprintf("=INDEX($M$2:$M$%d,MATCH(AC20,$A$2:$A$%d,0))", last, last),
    "=IF(AC22<500,0,IF(AC22<2000,500,IF(AC22<10000,2000,10000)))",
    "=IF(AC22<500,500,IF(AC22<2000,2000,IF(AC22<10000,10000,1E+9)))",
    sprintf("=PERCENTILE.INC(IF(($L$2:$L$%d>=AC23)*($L$2:$L$%d<AC24),$Z$2:$Z$%d),0.1)", last, last, last),
    sprintf("=PERCENTILE.INC(IF(($L$2:$L$%d>=AC23)*($L$2:$L$%d<AC24),$Z$2:$Z$%d),0.9)", last, last, last),
    "=AC22",
    "=ROUND(AC27*(1+AC25),0)",
    "=ROUND(AC27*(1+AC26),0)"
  )
  writeData(wb, ws, one_labels, startRow = 20, startCol = 28)
  writeData(wb, ws, 135717, startRow = 20, startCol = 29)
  addStyle(wb, ws, createStyle(fgFill = "#fff3e8"), rows = 20, cols = 29)
  for (i in seq_along(one_forms)) {
    if (is.na(one_forms[i])) next
    writeFormula(wb, ws, one_forms[i], startRow = 19 + i, startCol = 29, array = i %in% c(6, 7))
  }
  addStyle(wb, ws, createStyle(numFmt = "#,##0"), rows = c(22:24, 27:29), cols = 29, gridExpand = TRUE)
  addStyle(wb, ws, createStyle(numFmt = "0.0%"), rows = 25:26, cols = 29, gridExpand = TRUE)
  setColWidths(wb, ws, cols = 1:32, widths = c(9, 40, rep(9, 11), rep(12, 6), rep(9, 6), 10, 3, 40, 12, 12, 20, 12))
  freezePane(wb, ws, firstActiveRow = 2, firstActiveCol = 3)

  saveWorkbook(wb, path, overwrite = TRUE)
}
