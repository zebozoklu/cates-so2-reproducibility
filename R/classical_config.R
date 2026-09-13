source("R/config.R")
near <- NEAR_STATION
control <- CONTROL_STATION
periods <- PERIODS
periods$off <- periods$D
pollutant <- POLLUTANT
sample_mode <- "recovered"
raw_file <- pollution_file <- function(station, year)
  file.path(POLLUTION_DIR, sprintf("%s_%d.csv", gsub(" ", "_", station), year))
output_file <- function(name) file.path(DIRS$tables, paste0("classical_", name))
processed_file <- function(name) file.path(DIRS$processed, paste0("classical_", name))
