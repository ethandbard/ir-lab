# One-time setup. From a terminal:  Rscript setup.R
# Installs the packages the build script and the pre-rendered page parts use.
# The live cells run in the browser and need nothing installed locally.

cran <- "https://cloud.r-project.org"

needed <- c(
  "dplyr", "readr", "tidyr", "stringr",  # build_data.R
  "htmltools",                            # variable chips in _common.R
  "openxlsx",                             # data/ir-lab.xlsx
  "rpart", "glmnet", "randomForest"       # pre-rendered numbers in ml-predict-rate.qmd
)

installed <- rownames(installed.packages())
missing <- setdiff(needed, installed)

if (length(missing) > 0) {
  message("Installing from CRAN: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = cran)
} else {
  message("All required packages are already installed.")
}

if (!file.exists(file.path("..", "ipeds", "data", "raw", "HD2023.csv"))) {
  message("Raw IPEDS files not found in ../ipeds/data/raw. See ../ipeds/README.md.")
}

message("Next: Rscript build_data.R, then quarto render.")
