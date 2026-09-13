EARTH_RADIUS_KM <- 6371

degrees_to_radians <- function(x) x * pi / 180

great_circle_km <- function(lat1, lon1, lat2, lon2) {
  phi1 <- degrees_to_radians(lat1)
  phi2 <- degrees_to_radians(lat2)
  delta_phi <- phi2 - phi1
  delta_lambda <- degrees_to_radians(lon2 - lon1)
  a <- sin(delta_phi / 2)^2 +
    cos(phi1) * cos(phi2) * sin(delta_lambda / 2)^2
  2 * EARTH_RADIUS_KM * asin(pmin(1, sqrt(a)))
}
