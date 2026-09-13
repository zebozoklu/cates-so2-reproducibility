read_station_sources <- function(station, periods, pollutant) {
 required <- unique(periods$year)
 years <- sort(unique(c(required, required-1L, required+1L)))
 pieces <- lapply(years, function(year) {
  f <- raw_file(station, year)
  if(!file.exists(f)) {
   if(year %in% required) stop("Missing required extract: ", f)
   return(NULL)
  }
  z <- read.csv(f)
  if(!all(c("station","ts",pollutant) %in% names(z)) || !all(z$station==station)) stop("Invalid station extract: ",f)
  z[,c("station","ts",pollutant)]
 })
 x <- do.call(rbind,pieces)
 # Identical overlapping boundary rows are harmless; conflicting readings are not.
 for(ts in unique(x$ts[duplicated(x$ts)])) {
  z <- x[x$ts==ts,pollutant]
  if(length(unique(z))>1L) stop("Conflicting duplicate readings: ",station," ",ts)
 }
 x[!duplicated(x$ts),,drop=FALSE]
}
