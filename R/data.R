pollution_file <- function(station, year) {
  file.path(POLLUTION_DIR, sprintf("%s_%d.csv", gsub(" ", "_", station), year))
}

parse_pollution_timestamp <- function(x) {
  out <- as.POSIXct(x, format = "%Y-%m-%d %H:%M:%S", tz = SOURCE_LABEL_TZ)
  if (anyNA(out) || any(format(out, "%Y-%m-%d %H:%M:%S", tz=SOURCE_LABEL_TZ) != x) ||
      any(format(out, "%M:%S", tz=SOURCE_LABEL_TZ) != "00:00"))
    stop("Invalid hourly timestamps; expected YYYY-MM-DD HH:00:00")
  out
}

interval_date_from_end_label <- function(ts) {
  as.Date(ts - 1, tz = SOURCE_LABEL_TZ)
}

interval_end_hour <- function(ts) {
  as.integer(format(ts, "%H", tz = SOURCE_LABEL_TZ))
}

read_pollution <- function(stations = c(NEAR_STATION, CONTROL_STATION),
                           periods = PERIODS, clean = TRUE) {
  pieces <- list()
  k <- 1L
  for (station in stations) {
    for (j in seq_len(nrow(periods))) {
      year <- periods$year[j]
      path <- pollution_file(station, year)
      if (!file.exists(path)) stop("Missing pollution file: ", path)
      x <- read.csv(path, stringsAsFactors = FALSE)
      required <- c("station", "ts", POLLUTANT)
      if (!all(required %in% names(x))) stop("Missing columns in ", path)
      if (anyNA(x$station) || !all(x$station == station)) stop("Station mismatch in ", path)
      if (!is.numeric(x[[POLLUTANT]])) stop("SO2 must be numeric in ", path)
      x$ts <- parse_pollution_timestamp(x$ts)
      x$date <- interval_date_from_end_label(x$ts)
      x$hour <- interval_end_hour(x$ts)
      x$period <- periods$period[j]
      x$D <- periods$D[j]
      x <- x[x$date >= periods$start[j] & x$date <= periods$end[j],
             c("station", "ts", "date", "hour", "period", "D", POLLUTANT)]
      if (clean) x[[POLLUTANT]][!is.finite(x[[POLLUTANT]]) | x[[POLLUTANT]] < 0] <- NA_real_
      pieces[[k]] <- x
      k <- k + 1L
    }
  }
  out <- do.call(rbind, pieces)
  rownames(out) <- NULL
  out[order(out$station, out$ts), ]
}

assert_unique_station_hours <- function(panel) {
  key <- paste(panel$station, format(panel$ts, "%Y-%m-%d %H:%M:%S"))
  n_dup <- sum(duplicated(key))
  if (n_dup) stop("Duplicate station-hour rows: ", n_dup)
  invisible(TRUE)
}

curve_matrix <- function(panel, station) {
  d <- panel[panel$station == station, ]
  dates <- sort(unique(d$date))
  out <- matrix(NA_real_, nrow = length(dates), ncol = 24L,
                dimnames = list(as.character(dates), as.character(HOURS)))
  idx <- cbind(match(d$date, dates), match(d$hour, HOURS))
  out[idx] <- d[[POLLUTANT]]
  out
}

