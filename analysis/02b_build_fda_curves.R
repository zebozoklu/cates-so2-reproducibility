# Resolve repository root for Rscript and source(), regardless of working directory.
.local_script <- if (!is.null(sys.frames()[[1]]$ofile)) sys.frames()[[1]]$ofile else {
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
}
setwd(dirname(dirname(normalizePath(.local_script, mustWork = TRUE))))

source("R/config.R")
source("R/data.R")
source("R/fda_bspline.R")

MIN_OBS <- 20L
MAX_GAP <- 2L
N_BASIS <- 12L

panel <- read_pollution(
  c(NEAR_STATION, CONTROL_STATION),
  clean = TRUE
)

assert_unique_station_hours(panel)

near_raw <- curve_matrix(panel, NEAR_STATION)
control_raw <- curve_matrix(panel, CONTROL_STATION)

dates <- intersect(
  rownames(near_raw),
  rownames(control_raw)
)

near_raw <- near_raw[dates, , drop = FALSE]
control_raw <- control_raw[dates, , drop = FALSE]


# --------------------------------------------------
# Eligibility
# --------------------------------------------------

near_n <- rowSums(is.finite(near_raw))
control_n <- rowSums(is.finite(control_raw))

near_gap <- apply(
  near_raw, 1L, max_linear_missing_run, x = KNOT_HOURS
)

control_gap <- apply(
  control_raw, 1L, max_linear_missing_run, x = KNOT_HOURS
)

eligible <-
  near_n >= MIN_OBS &
  control_n >= MIN_OBS &
  near_gap <= MAX_GAP &
  control_gap <= MAX_GAP


near_use <- near_raw[eligible, , drop = FALSE]
control_use <- control_raw[eligible, , drop = FALSE]

included_dates <- as.Date(dates[eligible])

D <- as.integer(
  format(included_dates, "%Y") == "2020"
)

if (!setequal(unique(D), 0:1)) stop("Both operating and shutdown dates are required")

period <- ifelse(
  D == 1L,
  "shutdown",
  "operating"
)


# --------------------------------------------------
# ONE common smoothing parameter
# --------------------------------------------------

all_curves <- rbind(
  near_use[D == 0L, , drop = FALSE],
  control_use[D == 0L, , drop = FALSE]
)

lambda_fit <- choose_lambda(
  all_curves,
  df = N_BASIS
)

lambda <- lambda_fit$lambda

cat("Chosen lambda:", lambda, "\n")


# --------------------------------------------------
# Fit smooth functions directly from observed hours
# --------------------------------------------------

smooth_matrix <- function(Y) {
  
  t(vapply(
    seq_len(nrow(Y)),
    function(i)
      fit_penalized_bspline(
        Y[i, ],
        df = N_BASIS,
        lambda = lambda
      ),
    numeric(length(DENSE_GRID))
  ))
}


coefficient_matrix <- function(Y) {
  t(vapply(seq_len(nrow(Y)), function(i)
    fit_penalized_bspline(Y[i, ], df = N_BASIS, lambda = lambda,
                         return_coefficients = TRUE), numeric(N_BASIS)))
}
near_coefficients <- coefficient_matrix(near_use)
control_coefficients <- coefficient_matrix(control_use)
near_fda <- smooth_matrix(near_use)
control_fda <- smooth_matrix(control_use)

contrast_fda <- near_fda - control_fda


curves <- list(
  
  # genuinely functional objects evaluated on dense grid
  near_coefficients = near_coefficients,
  control_coefficients = control_coefficients,
  near = near_fda,
  control = control_fda,
  contrast = contrast_fda,
  
  # retain original observations for diagnostics
  near_raw = near_use,
  control_raw = control_use,
  
  dates = included_dates,
  D = D,
  period = period,
  
  grid = DENSE_GRID,
  
  basis = list(
    type = "penalized cubic B-spline",
    knots = attr(bspline_basis(KNOT_HOURS, N_BASIS), "knots"),
    boundary_knots = c(0, 24),
    penalty = "second coefficient differences",
    tuning = "eligible operating-period observations only",
    observation_model = "hourly averages approximated at interval midpoints",
    missing_data = "direct observed-only fitting; no prior interpolation",
    df = N_BASIS,
    lambda = lambda,
    lambda_grid = lambda_fit$grid,
    gcv = lambda_fit$gcv
  ),
  
  inclusion = data.frame(
    date = as.Date(dates),
    period = ifelse(
      format(as.Date(dates), "%Y") == "2020",
      "shutdown",
      "operating"
    ),
    near_observed = near_n,
    control_observed = control_n,
    near_max_gap = near_gap,
    control_max_gap = control_gap,
    included = eligible
  )
)

saveRDS(
  curves,
  file.path(DIRS$processed, "daily_curves_fda.rds")
)

write.csv(
  curves$inclusion,
  file.path(DIRS$tables, "fda_curve_inclusion.csv"),
  row.names = FALSE
)

write.csv(
  data.frame(
    lambda = lambda_fit$grid,
    gcv = lambda_fit$gcv
  ),
  file.path(DIRS$tables, "fda_lambda_gcv.csv"),
  row.names = FALSE
)

cat(
  "FDA curves:",
  sum(D == 0L), "operating,",
  sum(D == 1L), "shutdown\n"
)

