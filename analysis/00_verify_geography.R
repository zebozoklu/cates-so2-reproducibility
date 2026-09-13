source("R/config.R")
source("R/geo.R")

registry_path <- file.path(SOURCE_ROOT, "raw", "stations_national.csv")
plant_registry_path <- file.path(SOURCE_ROOT, "raw", "epias_powerplants.csv")
if (!file.exists(registry_path)) stop("Station registry is missing")
if (!file.exists(plant_registry_path)) stop("EPİAŞ plant registry is missing")

registry <- read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)
plant_registry <- read.csv(
  plant_registry_path, stringsAsFactors = FALSE, check.names = FALSE
)

selected <- registry[match(STATIONS$station_id, registry$id), ]
checks <- data.frame(
  check = c(
    "all configured station IDs occur once",
    "all configured plant IDs occur once",
    "selected monitors are in Zonguldak",
    "monitor coordinates are plausible",
    "facility coordinates are plausible"
  ),
  pass = c(
    all(vapply(STATIONS$station_id, function(id) sum(registry$id == id), 0L) == 1L),
    all(vapply(PLANTS$plant_id, function(id) sum(plant_registry$id == id), 0L) == 1L),
    all(selected$city == "Zonguldak"),
    all(selected$lat > 41 & selected$lat < 42 & selected$lon > 31 & selected$lon < 33),
    all(FACILITIES$lat > 41 & FACILITIES$lat < 42 &
          FACILITIES$lon > 31 & FACILITIES$lon < 33)
  )
)

station_metadata <- data.frame(
  analysis_name = STATIONS$station,
  role = STATIONS$role,
  station_id = STATIONS$station_id,
  registry_name = selected$name,
  city = selected$city,
  operator = selected$operator,
  lon = selected$lon,
  lat = selected$lat,
  coordinate_source = "Ministry national monitoring-station registry",
  location_note = c(
    "Coordinate agrees with official Zonguldak environmental reports",
    "Coordinate agrees with official Zonguldak environmental reports",
    paste(
      "Historical official tables contain two Kozlu coordinate rows; retain",
      "as robustness control until the station history is resolved"
    )
  )
)

for (i in seq_len(nrow(STATIONS))) {
  expected_id <- STATIONS$station_id[i]
  for (year in PERIODS$year) {
    path <- file.path(
      POLLUTION_DIR,
      sprintf("%s_%d.csv", gsub(" ", "_", STATIONS$station[i]), year)
    )
    if (!file.exists(path)) stop("Pollution file is missing: ", path)
    ids <- unique(na.omit(read.csv(path, stringsAsFactors = FALSE)$Stationid))
    if (!identical(ids, expected_id)) {
      stop("Station ID mismatch in ", path, ": expected ", expected_id)
    }
  }
}

facility_metadata <- merge(PLANTS, FACILITIES, by = "plant", all.x = TRUE)
facility_metadata$epias_name <- plant_registry$name[
  match(facility_metadata$plant_id, plant_registry$id)
]
facility_metadata$eic <- plant_registry$eic[
  match(facility_metadata$plant_id, plant_registry$id)
]

distance_rows <- lapply(seq_len(nrow(station_metadata)), function(i) {
  data.frame(
    station = station_metadata$analysis_name[i],
    station_role = station_metadata$role[i],
    plant = facility_metadata$plant,
    distance_km = round(great_circle_km(
      station_metadata$lat[i], station_metadata$lon[i],
      facility_metadata$lat, facility_metadata$lon
    ), 2)
  )
})
station_plant_distances <- do.call(rbind, distance_rows)

nearest <- aggregate(
  distance_km ~ station + station_role,
  station_plant_distances, min
)
names(nearest)[3] <- "nearest_facility_km"
checks <- rbind(
  checks,
  data.frame(
    check = c("near monitor is within 5 km", "control monitor is beyond 5 km"),
    pass = c(
      nearest$nearest_facility_km[nearest$station_role == "near"] < 5,
      nearest$nearest_facility_km[nearest$station_role == "control"] > 5
    )
  )
)

generation_files <- list.files(GENERATION_DIR, pattern = "[.]csv$", full.names = TRUE)
generation <- do.call(rbind, lapply(generation_files, read.csv, stringsAsFactors = FALSE))
generation$year <- as.integer(substr(generation$ts, 1, 4))
generation <- generation[generation$year %in% PERIODS$year, , drop = FALSE]
generation_summary <- do.call(rbind, lapply(
  split(generation, interaction(generation$unit, generation$year, drop = TRUE)),
  function(x) data.frame(
    plant = x$unit[1], year = x$year[1], hours = nrow(x),
    mean_mwh = mean(x$total), zero_share = mean(x$total == 0),
    maximum_mwh = max(x$total)
  )
))
row.names(generation_summary) <- NULL

write.csv(station_metadata, file.path(DIRS$tables, "station_metadata.csv"), row.names = FALSE)
write.csv(facility_metadata, file.path(DIRS$tables, "facility_metadata.csv"), row.names = FALSE)
write.csv(
  station_plant_distances,
  file.path(DIRS$tables, "station_plant_distances.csv"), row.names = FALSE
)
write.csv(
  generation_summary,
  file.path(DIRS$tables, "neighbor_generation_by_period.csv"), row.names = FALSE
)
write.csv(checks, file.path(DIRS$tables, "geography_checks.csv"), row.names = FALSE)

cates <- facility_metadata[facility_metadata$plant == "CATES", ]
cates_distance <- station_plant_distances[
  station_plant_distances$plant == "CATES", c("station", "distance_km")
]
station_plot <- merge(
  station_metadata, cates_distance,
  by.x = "analysis_name", by.y = "station", sort = FALSE
)
station_colors <- c(
  near = "#b23a2b", control = "#1f5c7a", robustness_control = "#6f7478"
)

png(
  file.path(DIRS$figures, "study_area_geometry.png"),
  width = 1600, height = 760, res = 150
)
par(mfrow = c(1, 2), mar = c(4.2, 4.4, 3.0, 1.0), family = "sans")

plot(
  station_plot$lon, station_plot$lat,
  xlim = range(c(station_plot$lon, facility_metadata$lon)) + c(-0.030, 0.030),
  ylim = range(c(station_plot$lat, facility_metadata$lat)) + c(-0.010, 0.010),
  xlab = "Longitude", ylab = "Latitude", asp = 1 / cos(mean(station_plot$lat) * pi / 180),
  pch = 21, bg = station_colors[station_plot$role], col = "white", cex = 1.8,
  main = "Selected monitors and generating facilities"
)
grid(col = "#dedede")
segments(
  cates$lon, cates$lat, station_plot$lon, station_plot$lat,
  col = "#a5a5a5", lty = 3
)
points(
  facility_metadata$lon, facility_metadata$lat,
  pch = 24, bg = "#d69a2d", col = "#5d4318", cex = 1.5
)
points(
  station_plot$lon, station_plot$lat,
  pch = 21, bg = station_colors[station_plot$role], col = "white", cex = 1.8
)
text(
  station_plot$lon, station_plot$lat,
  labels = sprintf("%s\n%.1f km to CATES", station_plot$analysis_name, station_plot$distance_km),
  pos = c(2, 2, 4), offset = 0.7, cex = 0.72
)
legend(
  "bottomright",
  legend = c("Near monitor", "Control monitor", "Robustness monitor", "Generating facility"),
  pch = c(21, 21, 21, 24),
  pt.bg = c(station_colors, "#d69a2d"),
  col = c(rep("white", 3), "#5d4318"), bty = "n", cex = 0.76
)

plot(
  NA, NA, xlim = c(31.872, 31.916), ylim = c(41.491, 41.522),
  xlab = "Longitude", ylab = "Latitude", asp = 1 / cos(41.505 * pi / 180),
  main = "Close-up of the plant complex"
)
grid(col = "#dedede")
points(
  facility_metadata$lon, facility_metadata$lat,
  pch = 24, bg = "#d69a2d", col = "#5d4318", cex = 1.8
)
points(
  station_plot$lon[station_plot$role == "near"],
  station_plot$lat[station_plot$role == "near"],
  pch = 21, bg = station_colors["near"], col = "white", cex = 2
)
text(
  facility_metadata$lon, facility_metadata$lat,
  labels = facility_metadata$plant,
  pos = c(4, 2, 2, 4), offset = 0.6, cex = 0.78
)
text(
  station_plot$lon[station_plot$role == "near"],
  station_plot$lat[station_plot$role == "near"],
  labels = "Cumayani monitor", pos = 4, offset = 0.7, cex = 0.78
)
dev.off()

print(station_metadata[, c("analysis_name", "role", "registry_name", "lon", "lat")],
      row.names = FALSE)
cat("\nDistances to facilities (km)\n")
print(station_plant_distances, row.names = FALSE)
cat("\nGeneration by plant and period\n")
print(generation_summary, row.names = FALSE)

if (!all(checks$pass)) {
  stop("One or more geography checks failed")
}
message("Monitor, facility, and source-identity checks passed")
