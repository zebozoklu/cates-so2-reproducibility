source("R/config.R")
rows <- list()
for(year in PERIODS$year) {
 paths <- file.path(GENERATION_DIR,sprintf("CATES_%d-%02d.csv",year,2:5))
 if(!all(file.exists(paths)))stop("Missing CATES generation files; see docs/DATA_REQUIREMENTS.md")
 x <- do.call(rbind,lapply(paths,read.csv))
 stopifnot(all(c("ts","total","unit") %in% names(x)),all(x$unit=="CATES"),
 all(is.finite(x$total)),all(x$total>=0),!anyDuplicated(x$ts))
 expected <- seq(as.POSIXct(sprintf("%d-02-01 00:00:00",year),tz="UTC"),
 as.POSIXct(sprintf("%d-05-31 23:00:00",year),tz="UTC"),by="hour")
 stopifnot(setequal(x$ts,format(expected,"%Y-%m-%d %H:%M:%S",tz="UTC")))
 if(year==2020)stopifnot(all(x$total==0)) else stopifnot(any(x$total>0))
 rows[[as.character(year)]]<-data.frame(year=year,hours=nrow(x),mean_mwh=mean(x$total),
 zero_hours=sum(x$total==0),total_mwh=sum(x$total))
}
write.csv(do.call(rbind,rows),file.path(DIRS$tables,"paper_generation_check.csv"),row.names=FALSE)
cat("CATES coverage and operating/shutdown checks passed.\n")
