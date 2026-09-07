# Downloads the IPEDS fall enrollment files EF2013A through EF2022A into
# ../ipeds/data/raw so build_data.R can build data/enrollment_history.csv.
# ef2023a.csv is part of the 2023-24 collection already in that folder.
#
#   Rscript fetch_history.R
#
# Each zip is 6 to 7 MB from https://nces.ed.gov/ipeds/datacenter/. When NCES
# has released a revised file it ships in the same zip as ef{year}a_rv.csv,
# and ipeds_read() prefers it. Years already present are skipped.

years <- 2013:2022
raw_dir <- file.path("..", "ipeds", "data", "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = 600, HTTPUserAgent = "Mozilla/5.0 (IR Lab data build)")

for (y in years) {
  have <- list.files(raw_dir, pattern = sprintf("^ef%da(_rv)?[.]csv$", y), ignore.case = TRUE)
  if (length(have)) {
    cat(sprintf("EF%dA: already have %s\n", y, paste(have, collapse = ", ")))
    next
  }
  url <- sprintf("https://nces.ed.gov/ipeds/datacenter/data/EF%dA.zip", y)
  zip <- tempfile(fileext = ".zip")
  download.file(url, zip, mode = "wb", quiet = TRUE, method = "libcurl")
  inside <- unzip(zip, list = TRUE)$Name
  csvs <- inside[grepl("[.]csv$", inside, ignore.case = TRUE)]
  unzip(zip, files = csvs, exdir = raw_dir)
  unlink(zip)
  cat(sprintf("EF%dA: %s\n", y, paste(csvs, collapse = ", ")))
}
