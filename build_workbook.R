# Writes data/ir-lab.xlsx: the institutions table plus one worked sheet per
# lesson, built with plain Excel formulas so the "In your stack" tabs can point
# at real cells. Called from build_data.R.

build_workbook <- function(institutions, variables, path) {
  library(openxlsx)

  # Functions added to Excel after 2007 must be stored with the _xlfn. prefix
  # or Excel and LibreOffice show #NAME? until the cell is re-entered.
  writeFormula <- function(wb, sheet, x, ...) {
    x <- gsub("(?<![A-Za-z._])(STDEV\\.S|STDEV\\.P|MINIFS|MAXIFS|PERCENTILE\\.INC|PERCENTILE\\.EXC|CONCAT|IFS|XLOOKUP|CONFIDENCE\\.T|T\\.INV\\.2T)\\(",
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

  saveWorkbook(wb, path, overwrite = TRUE)
}
