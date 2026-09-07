# Builds the analysis-ready extracts in data/ from the raw IPEDS 2023-24
# collection in ../ipeds/data/raw. Run once, or whenever the raw files change:
#
#   Rscript build_data.R
#
# Output:
#   data/institutions.csv   one row per institution, ~45 columns
#   data/variables.csv      every column above with its IPEDS source and label
#   data/ir-lab.xlsx        the same table plus worked Excel sheets per lesson

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(stringr)
})

ipeds_root <- file.path("..", "ipeds")
source(file.path(ipeds_root, "load_ipeds.R"))
ipeds_dir <- file.path(ipeds_root, "data", "raw")

dir.create("data", showWarnings = FALSE)

# ---- Institution directory -------------------------------------------

hd <- ipeds_read("HD2023", dir = ipeds_dir)

sector_lab <- c(
  `0` = "Administrative unit", `1` = "Public 4-year", `2` = "Private nonprofit 4-year",
  `3` = "Private for-profit 4-year", `4` = "Public 2-year", `5` = "Private nonprofit 2-year",
  `6` = "Private for-profit 2-year", `7` = "Public less-than-2-year",
  `8` = "Private nonprofit less-than-2-year", `9` = "Private for-profit less-than-2-year",
  `99` = "Sector unknown"
)
control_lab <- c(`1` = "Public", `2` = "Private nonprofit", `3` = "Private for-profit")
level_lab <- c(`1` = "4-year", `2` = "2-year", `3` = "Less than 2-year")
size_lab <- c(`1` = "Under 1,000", `2` = "1,000-4,999", `3` = "5,000-9,999",
              `4` = "10,000-19,999", `5` = "20,000 and above")
region_lab <- c(
  `0` = "US service schools", `1` = "New England", `2` = "Mid East", `3` = "Great Lakes",
  `4` = "Plains", `5` = "Southeast", `6` = "Southwest", `7` = "Rocky Mountains",
  `8` = "Far West", `9` = "Outlying areas"
)

locale_group <- function(x) {
  case_when(x %in% 11:13 ~ "City", x %in% 21:23 ~ "Suburb",
            x %in% 31:33 ~ "Town", x %in% 41:43 ~ "Rural", TRUE ~ NA_character_)
}

carnegie_group <- function(x) {
  case_when(
    x %in% 15:17 ~ "Doctoral",
    x %in% 18:20 ~ "Master's",
    x %in% 21:23 ~ "Baccalaureate",
    x %in% 1:14  ~ "Associate's",
    x %in% 24:32 ~ "Special focus",
    x == 33      ~ "Tribal",
    TRUE ~ NA_character_
  )
}

inst <- hd |>
  filter(cyactive == 1, sector != 0) |>
  transmute(
    unitid,
    name = instnm,
    city,
    state = stabbr,
    region = unname(region_lab[as.character(obereg)]),
    sector = unname(sector_lab[as.character(sector)]),
    control = unname(control_lab[as.character(control)]),
    level = unname(level_lab[as.character(iclevel)]),
    locale = locale_group(locale),
    size = unname(size_lab[as.character(instsize)]),
    carnegie = carnegie_group(c21basic),
    hbcu = if_else(hbcu == 1, "Yes", "No"),
    tribal = if_else(tribal == 1, "Yes", "No"),
    longitude = round(longitud, 4),
    latitude = round(latitude, 4)
  )

# ---- 12-month enrollment ---------------------------------------------

effy <- ipeds_read("EFFY2023", dir = ipeds_dir)

headcount <- effy |>
  filter(effyalev == 1) |>
  transmute(unitid, headcount = efytotlt)

ug <- effy |>
  filter(effyalev == 2) |>
  transmute(
    unitid,
    undergrad = efytotlt,
    pct_women_ug = round(100 * efytotlw / efytotlt, 1),
    pct_white_ug = round(100 * efywhitt / efytotlt, 1),
    pct_black_ug = round(100 * efybkaat / efytotlt, 1),
    pct_hispanic_ug = round(100 * efyhispt / efytotlt, 1),
    pct_asian_ug = round(100 * efyasiat / efytotlt, 1),
    pct_intl_ug = round(100 * efynralt / efytotlt, 1)
  )

# ---- Retention and student-faculty ratio -----------------------------

efd <- ipeds_read("ef2023d", dir = ipeds_dir) |>
  transmute(unitid, retention_ft = ret_pcf, retention_pt = ret_pcp,
            stu_fac_ratio = stufacr)

# ---- Graduation rates -------------------------------------------------
# GRTYPE already encodes cohort and status, so each unitid x grtype is one row.
#   2  4-year institutions, adjusted cohort         3  completers within 150%
#   8  bachelor's subcohort, adjusted cohort       12  bachelor's completers 150%
#  13  bachelor's completers in 4 years or less
#  29  2-year institutions, adjusted cohort        30  completers within 150%

gr <- ipeds_read("gr2023", dir = ipeds_dir) |>
  filter(grtype %in% c(2, 3, 8, 12, 13, 29, 30)) |>
  select(unitid, grtype, n = grtotlt) |>
  pivot_wider(names_from = grtype, values_from = n, names_prefix = "g")

grad <- gr |>
  transmute(
    unitid,
    grad_cohort = coalesce(g2, g29),
    grad_rate_150 = round(100 * coalesce(g3, g30) / coalesce(g2, g29), 1),
    bach_cohort = g8,
    grad_rate_bach_6yr = round(100 * g12 / g8, 1),
    grad_rate_bach_4yr = round(100 * g13 / g8, 1)
  ) |>
  mutate(across(starts_with("grad_rate"), \(x) if_else(is.finite(x), x, NA_real_)))

# ---- Financial aid and net price --------------------------------------
# Public institutions report net price for in-state students (NPIST2, NPT4x2);
# private institutions report one figure (NPGRN2, NPIS4x2).

sfa <- ipeds_read("sfa2223", dir = ipeds_dir) |>
  transmute(
    unitid,
    aid_cohort = scugffn,
    pct_pell = upgrntp,
    pct_any_grant = uagrntp,
    net_price = coalesce(npist2, npgrn2),
    net_price_0_30k = coalesce(npt412, npis412),
    net_price_30_48k = coalesce(npt422, npis422),
    net_price_48_75k = coalesce(npt432, npis432),
    net_price_75_110k = coalesce(npt442, npis442),
    net_price_110k_plus = coalesce(npt452, npis452)
  )

# ---- Completions by award level --------------------------------------

comp <- ipeds_read("C2023_c", dir = ipeds_dir) |>
  filter(awlevelc %in% c(3, 5, 7, 9)) |>
  select(unitid, awlevelc, n = cstotlt) |>
  pivot_wider(names_from = awlevelc, values_from = n, names_prefix = "a") |>
  transmute(unitid, associates_awarded = a3, bachelors_awarded = a5,
            masters_awarded = a7, doctorates_awarded = a9)

# ---- Assemble -----------------------------------------------------------

institutions <- inst |>
  left_join(headcount, by = "unitid") |>
  left_join(ug, by = "unitid") |>
  left_join(efd, by = "unitid") |>
  left_join(grad, by = "unitid") |>
  left_join(sfa, by = "unitid") |>
  left_join(comp, by = "unitid") |>
  arrange(unitid)

write_csv(institutions, file.path("data", "institutions.csv"), na = "")

# ---- Variable dictionary ----------------------------------------------

variables <- tribble(
  ~variable, ~source, ~ipeds, ~label,
  "unitid", "HD2023", "UNITID", "Unique identification number of the institution",
  "name", "HD2023", "INSTNM", "Institution name",
  "city", "HD2023", "CITY", "City location of institution",
  "state", "HD2023", "STABBR", "State abbreviation",
  "region", "HD2023", "OBEREG", "Bureau of Economic Analysis region",
  "sector", "HD2023", "SECTOR", "Sector of institution (control x level)",
  "control", "HD2023", "CONTROL", "Control of institution",
  "level", "HD2023", "ICLEVEL", "Level of institution",
  "locale", "HD2023", "LOCALE", "Degree of urbanization, grouped to City, Suburb, Town, Rural",
  "size", "HD2023", "INSTSIZE", "Institution size category (fall headcount)",
  "carnegie", "HD2023", "C21BASIC", "Carnegie Classification 2021: Basic, grouped",
  "hbcu", "HD2023", "HBCU", "Historically Black College or University",
  "tribal", "HD2023", "TRIBAL", "Tribal college",
  "longitude", "HD2023", "LONGITUD", "Longitude location of institution",
  "latitude", "HD2023", "LATITUDE", "Latitude location of institution",
  "headcount", "EFFY2023", "EFYTOTLT (EFFYALEV=1)", "12-month unduplicated headcount, all students",
  "undergrad", "EFFY2023", "EFYTOTLT (EFFYALEV=2)", "12-month unduplicated headcount, undergraduate",
  "pct_women_ug", "EFFY2023", "EFYTOTLW / EFYTOTLT", "Percent of undergraduates who are women",
  "pct_white_ug", "EFFY2023", "EFYWHITT / EFYTOTLT", "Percent of undergraduates who are White",
  "pct_black_ug", "EFFY2023", "EFYBKAAT / EFYTOTLT", "Percent of undergraduates who are Black or African American",
  "pct_hispanic_ug", "EFFY2023", "EFYHISPT / EFYTOTLT", "Percent of undergraduates who are Hispanic or Latino",
  "pct_asian_ug", "EFFY2023", "EFYASIAT / EFYTOTLT", "Percent of undergraduates who are Asian",
  "pct_intl_ug", "EFFY2023", "EFYNRALT / EFYTOTLT", "Percent of undergraduates who are U.S. nonresidents",
  "retention_ft", "EF2023D", "RET_PCF", "Full-time retention rate, fall 2022 to fall 2023",
  "retention_pt", "EF2023D", "RET_PCP", "Part-time retention rate, fall 2022 to fall 2023",
  "stu_fac_ratio", "EF2023D", "STUFACR", "Student-to-faculty ratio",
  "grad_cohort", "GR2023", "GRTOTLT (GRTYPE=2 or 29)", "Adjusted cohort, all degree/certificate-seeking students",
  "grad_rate_150", "GR2023", "GRTYPE 3/2 or 30/29", "Graduation rate within 150% of normal time, all students",
  "bach_cohort", "GR2023", "GRTOTLT (GRTYPE=8)", "Adjusted cohort, bachelor's-seeking subcohort at 4-year institutions",
  "grad_rate_bach_6yr", "GR2023", "GRTYPE 12/8", "Bachelor's degree completion within 6 years",
  "grad_rate_bach_4yr", "GR2023", "GRTYPE 13/8", "Bachelor's degree completion within 4 years",
  "aid_cohort", "SFA2223", "SCUGFFN", "Full-time first-time degree-seeking undergraduates in the aid cohort",
  "pct_pell", "SFA2223", "UPGRNTP", "Percent of undergraduates awarded Pell grants",
  "pct_any_grant", "SFA2223", "UAGRNTP", "Percent of undergraduates awarded any grant aid",
  "net_price", "SFA2223", "NPIST2 or NPGRN2", "Average net price for students awarded grant aid, 2022-23 (in-state at publics)",
  "net_price_0_30k", "SFA2223", "NPT412 or NPIS412", "Average net price, family income $0-30,000",
  "net_price_30_48k", "SFA2223", "NPT422 or NPIS422", "Average net price, family income $30,001-48,000",
  "net_price_48_75k", "SFA2223", "NPT432 or NPIS432", "Average net price, family income $48,001-75,000",
  "net_price_75_110k", "SFA2223", "NPT442 or NPIS442", "Average net price, family income $75,001-110,000",
  "net_price_110k_plus", "SFA2223", "NPT452 or NPIS452", "Average net price, family income $110,001 or more",
  "associates_awarded", "C2023_C", "CSTOTLT (AWLEVELC=3)", "Associate's degrees awarded, 2022-23",
  "bachelors_awarded", "C2023_C", "CSTOTLT (AWLEVELC=5)", "Bachelor's degrees awarded, 2022-23",
  "masters_awarded", "C2023_C", "CSTOTLT (AWLEVELC=7)", "Master's degrees awarded, 2022-23",
  "doctorates_awarded", "C2023_C", "CSTOTLT (AWLEVELC=9)", "Doctor's degrees awarded, 2022-23"
)

stopifnot(setequal(variables$variable, names(institutions)))
write_csv(variables, file.path("data", "variables.csv"))

cat("institutions.csv:", nrow(institutions), "rows x", ncol(institutions), "cols,",
    round(file.size(file.path("data", "institutions.csv")) / 1024), "KB\n")

# ---- Excel workbook -----------------------------------------------------
# Built here so the workbook always matches the CSV the R and Python cells use.

if (requireNamespace("openxlsx", quietly = TRUE)) {
  source("build_workbook.R")
  build_workbook(institutions, variables, file.path("data", "ir-lab.xlsx"))
  cat("ir-lab.xlsx written\n")
} else {
  cat("openxlsx not installed; skipped ir-lab.xlsx\n")
}
