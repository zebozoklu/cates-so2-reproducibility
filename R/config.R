options(stringsAsFactors = FALSE)
Sys.setenv(TZ = "Europe/Istanbul")

# Pollution timestamps are offset-free source labels. Parse them in a neutral,
# fixed-offset frame so their displayed date and hour are preserved verbatim.
SOURCE_LABEL_TZ <- "UTC"

SOURCE_ROOT <- Sys.getenv(
  "FDID_SOURCE_ROOT",
  unset = "data"
)

POLLUTION_DIR <- file.path(SOURCE_ROOT, "raw", "pollution")
GENERATION_DIR <- file.path(SOURCE_ROOT, "raw", "generation")

NEAR_STATION <- "Catalagzi Cumayani"
CONTROL_STATION <- "Trafik"
ROBUSTNESS_CONTROL <- "Kozlu"
POLLUTANT <- "SO2"

STATIONS <- data.frame(
  station = c(NEAR_STATION, CONTROL_STATION, ROBUSTNESS_CONTROL),
  station_id = c(
    "df9142f3-3b6c-46d6-8738-1316a6ef64dc",
    "7058210e-a4b5-4b90-9e46-ec674d6e52cd",
    "be837236-0704-447c-8a43-ccce0f3ded55"
  ),
  role = c("near", "control", "robustness_control")
)

PLANTS <- data.frame(
  plant = c("CATES", "ZETES I", "ZETES II", "ZETES III"),
  plant_id = c("688", "2264", "877", "2065")
)

# Coordinates are used only to document geometry, not in the baseline estimator.
# EPİAŞ verifies plant identities and capacities but does not return coordinates.
FACILITIES <- data.frame(
  plant = c("CATES", "ZETES I", "ZETES II", "ZETES III"),
  lon = c(31.9013, 31.8954, 31.8866, 31.9101),
  lat = c(41.5178, 41.5074, 41.5030, 41.5138),
  coordinate_source = c(
    "OpenStreetMap; cross-checked against operator address and independent plant records",
    "OpenStreetMap power=generator node; not independently surveyed",
    "OpenStreetMap power=generator node; not independently surveyed",
    "OpenStreetMap power=generator node; not independently surveyed"
  )
)

PERIODS <- data.frame(
  period = c("operating", "shutdown"),
  year = c(2019L, 2020L),
  start = as.Date(c("2019-02-01", "2020-02-01")),
  end = as.Date(c("2019-05-31", "2020-05-31")),
  D = c(0L, 1L)
)

# Ministry timestamps label the end of each one-hour averaging interval. HOURS
# retains those source labels; KNOT_HOURS gives the corresponding clock-time
# midpoints in the same column order.
HOURS <- 0:23
KNOT_HOURS <- (HOURS - 0.5) %% 24
DENSE_GRID <- seq(0, 24, by = 0.05)
BLOCK_DAYS <- 7L
BOOT_B <- 1999L
BOOT_SEED <- 20260906L
LEVEL <- 0.95
AFTERNOON <- c(12, 19)

DIRS <- list(
  processed = file.path("data", "processed"),
  figures = file.path("output", "figures"),
  tables = file.path("output", "tables")
)

invisible(lapply(DIRS, dir.create, recursive = TRUE, showWarnings = FALSE))

stopifnot(
  all(PERIODS$start <= PERIODS$end),
  length(HOURS) == 24L,
  length(KNOT_HOURS) == 24L,
  DENSE_GRID[1] == 0,
  tail(DENSE_GRID, 1) == 24
)
