source("R/config.R")
source("R/fda_bspline.R")
source("R/fdid.R")
# Verify real-data objects retain missing observations and reconstruct exactly.
curves <- readRDS(file.path(DIRS$processed, "daily_curves_fda.rds"))
stopifnot(anyNA(curves$near_raw) || anyNA(curves$control_raw))
stopifnot(all(is.finite(curves$near)), all(is.finite(curves$control)))
stopifnot(max(abs(curves$near - curves$near_coefficients %*%
                   t(bspline_basis(curves$grid, curves$basis$df)))) < 1e-9)

metrics <- read.csv(file.path(DIRS$tables,"paper_metrics.csv"))
v <- setNames(metrics$value,metrics$quantity)
stopifnot(abs(v["functional_average"]-2.963529)<1e-6,
 abs(v["lambda"]-0.0275853161762919)<1e-12,
 round(v["daily_did"],1)==2.9,round(v["hourly_min"],1)==-27.6,
 round(v["hourly_max"],1)==20.6,round(v["hourly_functional_correlation"],3)==0.992)
counts <- read.csv(file.path(DIRS$tables,"paper_sample_counts.csv"))
stopifnot(identical(counts$complete,c(55L,110L)),
 identical(counts$classical,c(98L,115L)),identical(counts$functional,c(100L,116L)))
cat("Paper result checks passed.\n")
