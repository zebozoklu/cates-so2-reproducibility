# Resolve this repository from the script path.
.local_script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)[1])
setwd(dirname(dirname(normalizePath(.local_script, mustWork=TRUE))))
source("R/classical_config.R")
source("R/sample_utils.R")

MIN_OBS <- 20L   # at least 20 of 24 observed hours per station-day
MAX_GAP <- 2L    # never recover a continuous outage longer than 2 hours

calendar <- do.call(rbind, lapply(seq_len(nrow(periods)), function(j) {
  data.frame(
    date = seq(periods$start[j], periods$end[j], by = "day"),
    off  = periods$off[j]
  )
}))

# Length of the continuous missing run containing each hour.
# Observed hours get 0.
missing_run_length <- function(missing) {
  rr <- rle(missing)
  rep(ifelse(rr$values, rr$lengths, 0L), rr$lengths)
}

# Full hourly target grid for the analysis calendar.
target_time <- as.POSIXct(
  paste(
    rep(as.character(calendar$date), each = 24),
    rep(sprintf("%02d:00:00", 0:23), times = nrow(calendar))
  ),
  format = "%Y-%m-%d %H:%M:%S",
  tz = "UTC"
)

matrices_obs  <- list()
matrices_fill <- list()
eligible      <- list()
audits        <- list()

for (s in c(near, control)) {

  # Read the full annual extracts, not only retained days.
  # This lets interpolation naturally cross midnight when needed.
  x <- read_station_sources(s, periods, pollutant)

  # Source labels are interval ends. Convert to local interval starts,
  # exactly as in the original 03_build_sample.R.
  t <- as.POSIXct(x$ts, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
  if (anyNA(t) || any(format(t, "%M:%S", tz = "UTC") != "00:00")) {
    stop("Invalid hourly timestamps")
  }
  if (anyDuplicated(x$ts)) stop("Duplicate station timestamps: ", s)

  start <- t - 3600
  value <- suppressWarnings(as.numeric(x[[pollutant]]))
  value[!is.finite(value) | value < 0] <- NA_real_

  # Build a continuous hourly series covering all source timestamps.
  grid <- seq(min(start), max(start), by = "hour")
  series <- rep(NA_real_, length(grid))
  idx <- match(start, grid)
  series[idx] <- value

  missing <- !is.finite(series)
  run_len <- missing_run_length(missing)

  # Recover ONLY gaps belonging to runs of at most MAX_GAP hours.
  # Linear interpolation is performed on the continuous hourly series,
  # so a missing 00:00 or 23:00 can use the adjacent day.
  filled <- series
  recoverable <- missing & run_len <= MAX_GAP

  if (any(recoverable) && sum(!missing) >= 2L) {
    observed_idx <- which(!missing)
    filled[recoverable] <- approx(
      x = observed_idx,
      y = series[observed_idx],
      xout = which(recoverable),
      method = "linear",
      rule = 1
    )$y
  }

  # Put observed and recovered values into daily 24-hour matrices.
  target_idx <- match(target_time, grid)

  mat_obs <- matrix(
    series[target_idx],
    nrow = nrow(calendar), ncol = 24, byrow = TRUE,
    dimnames = list(as.character(calendar$date), 0:23)
  )

  mat_fill <- matrix(
    filled[target_idx],
    nrow = nrow(calendar), ncol = 24, byrow = TRUE,
    dimnames = list(as.character(calendar$date), 0:23)
  )

  run_mat <- matrix(
    run_len[target_idx],
    nrow = nrow(calendar), ncol = 24, byrow = TRUE
  )

  valid_hours <- rowSums(is.finite(mat_obs))
  missing_hours <- 24L - valid_hours
  max_missing_run <- apply(run_mat, 1, function(z) if(anyNA(z)) Inf else max(z))
  imputed_hours <- rowSums(!is.finite(mat_obs) & is.finite(mat_fill))

  # A station-day is retained only if:
  #   1) at least MIN_OBS hours were genuinely observed;
  #   2) no missing hour belongs to a run longer than MAX_GAP;
  #   3) the resulting curve is complete after short-gap recovery.
  ok <- valid_hours >= MIN_OBS &
        max_missing_run <= MAX_GAP &
        complete.cases(mat_fill)

  matrices_obs[[s]]  <- mat_obs
  matrices_fill[[s]] <- mat_fill
  eligible[[s]]      <- ok

  audits[[s]] <- data.frame(
    station = s,
    date = calendar$date,
    off = calendar$off,
    valid_hours = valid_hours,
    missing_hours = missing_hours,
    max_missing_run = max_missing_run,
    imputed_hours = imputed_hours,
    eligible_station = ok
  )
}

# Spatial contrast requires both stations on the same date.
include <- eligible[[near]] & eligible[[control]]

if (!all(c(0, 1) %in% calendar$off[include])) {
  stop("No retained paired days in one or both periods")
}

audit <- do.call(rbind, audits)
audit$included_pair <- rep(include, 2)
write.csv(audit, output_file("sample_audit.csv"), row.names = FALSE)

# Main recovered sample. Downstream DiD scripts can remain unchanged.
sample <- list(
  near = matrices_fill[[near]][include, , drop = FALSE],
  control = matrices_fill[[control]][include, , drop = FALSE],
  calendar = calendar[include, ],
  near_name = near,
  control_name = control,
  pollutant = pollutant,
  recovery = list(
    min_observed_hours = MIN_OBS,
    max_continuous_gap = MAX_GAP,
    method = "linear interpolation of short gaps on continuous hourly series"
  )
)

sample$sample_mode <- sample_mode
saveRDS(sample, processed_file("sample.rds"))

# Daily and hourly classical DiD share the recovered 24-hour curves.
# The direct observed-hour FDA sample is built separately.
daily <- rbind(
  data.frame(
    sample$calendar,
    station = near,
    near = 1,
    daily_mean = rowMeans(sample$near)
  ),
  data.frame(
    sample$calendar,
    station = control,
    near = 0,
    daily_mean = rowMeans(sample$control)
  )
)
write.csv(daily, processed_file("daily_panel.csv"), row.names = FALSE)

# Pair counts.
pair_counts <- aggregate(
  included_pair ~ off + station,
  data = audit,
  FUN = sum
)
write.csv(pair_counts, output_file("sample_counts.csv"), row.names = FALSE)

# Exact audit trail of values actually imputed in retained paired days.
imputed_log <- list()
for (s in c(near, control)) {
  obs <- matrices_obs[[s]][include, , drop = FALSE]
  rec <- matrices_fill[[s]][include, , drop = FALSE]
  cal <- calendar[include, , drop = FALSE]

  where <- which(!is.finite(obs) & is.finite(rec), arr.ind = TRUE)

  if (nrow(where) > 0) {
    imputed_log[[s]] <- data.frame(
      station = s,
      date = cal$date[where[, 1]],
      hour_start = where[, 2] - 1L,
      observed_value = NA_real_,
      imputed_value = rec[where]
    )
  }
}

imputed_log <- if (length(imputed_log)) do.call(rbind, imputed_log) else
  data.frame(
    station = character(), date = as.Date(character()),
    hour_start = integer(), observed_value = numeric(),
    imputed_value = numeric()
  )

write.csv(imputed_log, output_file("imputed_hours.csv"), row.names = FALSE)

cat(
  "Retained paired days:", sum(include), "\n",
  "Operating:", sum(include & calendar$off == 0), "\n",
  "Shutdown:",  sum(include & calendar$off == 1), "\n",
  "Imputed station-hours in retained sample:", nrow(imputed_log), "\n"
)

