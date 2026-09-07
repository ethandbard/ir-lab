# Run from ir-lab: Rscript powerbi/scripts/build_peers.R
# Base R only. Mirrors the five-feature R lesson; labels are ordered by Pell center.
args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) args[[1]] else "."
inst <- read.csv(file.path(root, "data/institutions.csv"), na.strings = "", check.names = FALSE)
features <- c("pct_pell", "grad_rate_bach_6yr", "net_price", "retention_ft", "stu_fac_ratio")
keep <- !is.na(inst$level) & inst$level == "4-year" & !is.na(inst$control) &
  inst$control != "Private for-profit" & !is.na(inst$bach_cohort) & inst$bach_cohort >= 100 &
  complete.cases(inst[, features])
peers <- inst[keep, ]
z <- scale(peers[, features])
stopifnot(nrow(peers) > 4, all(is.finite(z)))
set.seed(2023)
fit <- kmeans(z, centers = 4, nstart = 25)
labels <- match(fit$cluster, order(fit$centers[, "pct_pell"]))
peers$peer_group <- paste("Group", labels)
peers$peer_group_sort <- labels
out <- file.path(root, "powerbi/data")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
write.csv(peers, file.path(out, "peers.csv"), row.names = FALSE, na = "")
profile <- aggregate(peers[, features], list(peer_group = peers$peer_group), median)
profile$institutions <- as.integer(table(peers$peer_group)[profile$peer_group])
write.csv(profile, file.path(out, "peer-profiles.csv"), row.names = FALSE)
write.csv(data.frame(feature = features, mean = attr(z, "scaled:center"),
                     sample_sd = attr(z, "scaled:scale")),
          file.path(out, "scaling.csv"), row.names = FALSE)
cat(nrow(peers), "eligible peers; cluster sizes:", as.integer(table(labels)), "\n")
