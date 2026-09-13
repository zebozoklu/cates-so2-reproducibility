# ================================================================
# 04c_main_did_figures.R
#
# FINAL main results:
#
# Classical daily/hourly DiD:
#   data/processed/sample.rds
#   short gaps recovered linearly upstream
#
# Functional DiD:
#   data/processed/daily_curves_fda.rds
#   no prior imputation; direct observed-hour B-spline fitting
# ================================================================


# ------------------------------------------------
# 0. Repository root
# ------------------------------------------------

.local_script <- if (!is.null(sys.frames()[[1]]$ofile)) {
  sys.frames()[[1]]$ofile
} else {
  sub(
    "^--file=",
    "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[1]
  )
}

setwd(dirname(dirname(
  normalizePath(.local_script, mustWork = TRUE)
)))


# ------------------------------------------------
# 1. Functions
# ------------------------------------------------

source("R/config.R")
source("R/fdid.R")
source("R/fda_bspline.R")


# ================================================================
# A. CLASSICAL DAILY + HOURLY DiD
# ================================================================

sample_path <- file.path(
  "data/processed/classical_sample.rds"
)

if (!file.exists(sample_path)) {
  stop(
    "Missing data/processed/sample.rds. ",
    "Run analysis/01_build_classical.R first."
  )
}

classical <- readRDS(sample_path)


# ------------------------------------------------
# 2. Validate recovered sample
# ------------------------------------------------

required <- c(
  "near",
  "control",
  "calendar",
  "recovery"
)

missing <- setdiff(required, names(classical))

if (length(missing)) {
  stop(
    "sample.rds missing: ",
    paste(missing, collapse = ", ")
  )
}

if (
  !is.matrix(classical$near) ||
  !is.matrix(classical$control)
) {
  stop("near and control must be matrices.")
}

if (
  ncol(classical$near) != 24L ||
  ncol(classical$control) != 24L
) {
  stop("Recovered sample must contain 24 hourly values per day.")
}

if (
  any(!is.finite(classical$near)) ||
  any(!is.finite(classical$control))
) {
  stop(
    "Recovered conventional sample still contains missing values."
  )
}

if (!"off" %in% names(classical$calendar)) {
  stop("classical$calendar must contain the off indicator.")
}

D_classical <- as.integer(classical$calendar$off)

if (!setequal(unique(D_classical), 0:1)) {
  stop("Both periods are required.")
}

n_on_classical  <- sum(D_classical == 0L)
n_off_classical <- sum(D_classical == 1L)
n_classical     <- length(D_classical)

cat("\nRECOVERED CLASSICAL SAMPLE\n")
cat("Operating:", n_on_classical, "\n")
cat("Shutdown: ", n_off_classical, "\n")
cat("Total:    ", n_classical, "\n")

# Hard safeguard: we do NOT want the strict 165-day object.
if (
  n_on_classical != 98L ||
  n_off_classical != 115L ||
  n_classical != 213L
) {
  stop(
    paste0(
      "Unexpected recovered sample. Expected ",
      "98 operating + 115 shutdown = 213 dates. ",
      "Do not proceed until analysis/01_build_classical.R ",
      "has been run correctly."
    )
  )
}

if (
  classical$recovery$min_observed_hours != 20L ||
  classical$recovery$max_continuous_gap != 2L
) {
  stop("Recovered-sample rule does not match the thesis specification.")
}


# ------------------------------------------------
# 3. Construct hourly spatial contrast
# ------------------------------------------------

contrast_classical <-
  classical$near -
  classical$control

hourly_fit <- fit_functional_did(
  contrast_classical,
  D_classical
)


# ------------------------------------------------
# 4. Recover clock-hour ordering from matrix itself
# ------------------------------------------------

hour_start <- suppressWarnings(
  as.numeric(colnames(classical$near))
)

if (
  length(hour_start) != 24L ||
  anyNA(hour_start) ||
  !setequal(hour_start, 0:23)
) {
  stop(
    "Expected recovered sample columns to be named 0,...,23."
  )
}

hour_midpoint <- hour_start + 0.5


# ------------------------------------------------
# 5. Hourly DiD table
# ------------------------------------------------

hourly_table <- data.frame(
  interval_start_hour = hour_start,
  interval_end_hour = hour_start + 1,
  interval_midpoint_hour = hour_midpoint,
  
  near_operating = colMeans(
    classical$near[
      D_classical == 0L,
      ,
      drop = FALSE
    ]
  ),
  
  near_shutdown = colMeans(
    classical$near[
      D_classical == 1L,
      ,
      drop = FALSE
    ]
  ),
  
  control_operating = colMeans(
    classical$control[
      D_classical == 0L,
      ,
      drop = FALSE
    ]
  ),
  
  control_shutdown = colMeans(
    classical$control[
      D_classical == 1L,
      ,
      drop = FALSE
    ]
  ),
  
  estimate = hourly_fit$beta
)


# Explicit algebra check
hourly_check <-
  (
    hourly_table$near_shutdown -
      hourly_table$near_operating
  ) -
  (
    hourly_table$control_shutdown -
      hourly_table$control_operating
  )

if (
  max(
    abs(hourly_check - hourly_table$estimate)
  ) > 1e-10
) {
  stop("Hourly DiD algebra check failed.")
}


# ------------------------------------------------
# 6. Daily-mean DiD
# ------------------------------------------------

daily_contrast <- rowMeans(
  contrast_classical
)

daily_mean_did <-
  mean(
    daily_contrast[D_classical == 1L]
  ) -
  mean(
    daily_contrast[D_classical == 0L]
  )

# With completed 24-hour profiles this must equal
# the mean of the 24 hourly DiD estimates.
if (
  abs(
    daily_mean_did -
    mean(hourly_fit$beta)
  ) > 1e-10
) {
  stop(
    "Daily-mean and average hourly DiD identity failed."
  )
}

cat(
  "Daily-mean DiD:",
  daily_mean_did,
  "\n"
)

write.csv(
  hourly_table,
  file.path(
    DIRS$tables,
    "hourly_did.csv"
  ),
  row.names = FALSE
)


# ================================================================
# B. FUNCTIONAL DiD
# ================================================================

fda_path <- file.path(
  DIRS$processed,
  "daily_curves_fda.rds"
)

if (!file.exists(fda_path)) {
  stop(
    "Missing data/processed/daily_curves_fda.rds. ",
    "Run analysis/02b_build_fda_curves.R first."
  )
}

fda <- readRDS(fda_path)

D_fda <- fda$D

n_on_fda  <- sum(D_fda == 0L)
n_off_fda <- sum(D_fda == 1L)
n_fda     <- length(D_fda)

cat("\nFDA SAMPLE\n")
cat("Operating:", n_on_fda, "\n")
cat("Shutdown: ", n_off_fda, "\n")
cat("Total:    ", n_fda, "\n")

if (
  n_on_fda != 100L ||
  n_off_fda != 116L ||
  n_fda != 216L
) {
  stop(
    paste0(
      "Unexpected FDA sample. Expected ",
      "100 operating + 116 shutdown = 216."
    )
  )
}


# ------------------------------------------------
# 7. Functional DiD
# ------------------------------------------------

functional_fit <- fit_functional_did(
  fda$contrast,
  D_fda
)

coefficient_fit <- fit_functional_did(
  fda$near_coefficients -
    fda$control_coefficients,
  D_fda
)

functional_from_coefficients <- drop(
  bspline_basis(
    fda$grid,
    fda$basis$df
  ) %*%
    coefficient_fit$beta
)

if (
  max(
    abs(
      functional_from_coefficients -
      functional_fit$beta
    )
  ) > 1e-8
) {
  stop("Functional coefficient check failed.")
}


# ------------------------------------------------
# 8. Integrated functional average
# ------------------------------------------------

integration_knots <- c(
  0,
  fda$basis$knots,
  24
)

functional_average <- sum(
  vapply(
    seq_len(
      length(integration_knots) - 1L
    ),
    function(j) {
      
      integrate(
        function(s) {
          drop(
            bspline_basis(
              s,
              fda$basis$df
            ) %*%
              coefficient_fit$beta
          )
        },
        integration_knots[j],
        integration_knots[j + 1L]
      )$value
      
    },
    numeric(1)
  )
) / 24


functional_min_index <-
  which.min(functional_fit$beta)

functional_max_index <-
  which.max(functional_fit$beta)

functional_min <-
  functional_fit$beta[functional_min_index]

functional_min_time <-
  fda$grid[functional_min_index]

functional_max <-
  functional_fit$beta[functional_max_index]

functional_max_time <-
  fda$grid[functional_max_index]


cat(
  "Integrated functional mean:",
  functional_average,
  "\n"
)

cat(
  "Functional minimum:",
  functional_min,
  "at",
  functional_min_time,
  "\n"
)

cat(
  "Functional maximum:",
  functional_max,
  "at",
  functional_max_time,
  "\n"
)


functional_table <- data.frame(
  hour = fda$grid,
  operating_mean = functional_fit$mean_on,
  shutdown_mean = functional_fit$mean_off,
  functional_did = functional_fit$beta
)

write.csv(
  functional_table,
  file.path(
    DIRS$tables,
    "bspline_functional_did.csv"
  ),
  row.names = FALSE
)


# ================================================================
# C. COMPARISON
# ================================================================

# Evaluate actual B-spline effect at the same 24 midpoints
functional_midpoint <- drop(
  bspline_basis(
    hour_midpoint,
    fda$basis$df
  ) %*%
    coefficient_fit$beta
)

comparison <- data.frame(
  interval_midpoint_hour = hour_midpoint,
  hourly_did = hourly_fit$beta,
  functional_did = functional_midpoint
)

shape_correlation <- cor(
  comparison$hourly_did,
  comparison$functional_did
)

cat(
  "Hourly / functional shape correlation:",
  shape_correlation,
  "\n"
)

write.csv(
  comparison,
  file.path(
    DIRS$tables,
    "hourly_vs_bspline.csv"
  ),
  row.names = FALSE
)


# ================================================================
# FIGURE 1: HOURLY DiD
# ================================================================

png(
  file.path(
    DIRS$figures,
    "hourly_did.png"
  ),
  width = 1600,
  height = 1000,
  res = 180
)

par(
  mar = c(5.2, 5.6, 1.2, 1.2),
  las = 1
)

plot(
  hourly_table$interval_midpoint_hour,
  hourly_table$estimate,
  type = "o",
  pch = 16,
  lwd = 1.5,
  cex = 0.9,
  col = "#195C75",
  xlim = c(0, 24),
  xaxt = "n",
  xlab = "Time of day",
  ylab = expression(
    paste(
      "Hourly DiD estimate (",
      mu,
      "g/m"^3,
      ")"
    )
  ),
  main = ""
)

axis(
  1,
  at = seq(0, 24, by = 4),
  labels = c(
    "00:00",
    "04:00",
    "08:00",
    "12:00",
    "16:00",
    "20:00",
    "24:00"
  )
)

abline(
  h = 0,
  lty = 2,
  lwd = 1,
  col = "#777777"
)

box()

dev.off()


# ================================================================
# FIGURE 2: FUNCTIONAL DiD
# ================================================================

png(
  file.path(
    DIRS$figures,
    "bspline_functional_did.png"
  ),
  width = 1600,
  height = 1000,
  res = 180
)

par(
  mar = c(5.2, 5.6, 1.2, 1.2),
  las = 1
)

plot(
  fda$grid,
  functional_fit$beta,
  type = "l",
  lwd = 3,
  col = "#007F7B",
  xlim = c(0, 24),
  xaxt = "n",
  xlab = "Time of day",
  ylab = expression(
    paste(
      "Functional DiD estimate (",
      mu,
      "g/m"^3,
      ")"
    )
  ),
  main = ""
)

axis(
  1,
  at = seq(0, 24, by = 4),
  labels = c(
    "00:00",
    "04:00",
    "08:00",
    "12:00",
    "16:00",
    "20:00",
    "24:00"
  )
)

abline(
  h = 0,
  lty = 2,
  lwd = 1,
  col = "#777777"
)

box()

dev.off()


# ================================================================
# FIGURE 3: HOURLY + FUNCTIONAL DiD
# ================================================================

ylim <- range(
  c(
    hourly_table$estimate,
    functional_fit$beta
  )
)

png(
  file.path(
    DIRS$figures,
    "hourly_vs_bspline.png"
  ),
  width = 1600,
  height = 1000,
  res = 180
)

par(
  mar = c(5.2, 5.6, 1.2, 1.2),
  las = 1
)

plot(
  fda$grid,
  functional_fit$beta,
  type = "l",
  lwd = 3,
  col = "#007F7B",
  xlim = c(0, 24),
  ylim = ylim,
  xaxt = "n",
  xlab = "Time of day",
  ylab = expression(
    paste(
      "DiD estimate (",
      mu,
      "g/m"^3,
      ")"
    )
  ),
  main = ""
)

axis(
  1,
  at = seq(0, 24, by = 4),
  labels = c(
    "00:00",
    "04:00",
    "08:00",
    "12:00",
    "16:00",
    "20:00",
    "24:00"
  )
)

abline(
  h = 0,
  lty = 2,
  lwd = 1,
  col = "#777777"
)

lines(
  hourly_table$interval_midpoint_hour,
  hourly_table$estimate,
  lwd = 1.2,
  col = "#195C75"
)

points(
  hourly_table$interval_midpoint_hour,
  hourly_table$estimate,
  pch = 16,
  cex = 0.9,
  col = "#195C75"
)

legend(
  "bottomleft",
  legend = c(
    "Functional DiD",
    "Hourly DiD"
  ),
  col = c(
    "#007F7B",
    "#195C75"
  ),
  lwd = c(3, 1.2),
  pch = c(NA, 16),
  bty = "n"
)

box()

dev.off()


# ================================================================
# FINAL REPORT
# ================================================================

cat("\n========================================\n")
cat("FINAL MAIN RESULTS\n")
cat("========================================\n")

cat(
  "\nRecovered classical sample:\n",
  "Operating:", n_on_classical, "\n",
  "Shutdown: ", n_off_classical, "\n",
  "Total:    ", n_classical, "\n",
  "Daily DiD:", daily_mean_did, "\n"
)

cat(
  "\nFDA sample:\n",
  "Operating:", n_on_fda, "\n",
  "Shutdown: ", n_off_fda, "\n",
  "Total:    ", n_fda, "\n",
  "Integrated DiD:", functional_average, "\n",
  "Minimum:", functional_min,
  "at", functional_min_time, "\n",
  "Maximum:", functional_max,
  "at", functional_max_time, "\n"
)

cat(
  "\nHourly / functional correlation:",
  shape_correlation,
  "\n"
)

