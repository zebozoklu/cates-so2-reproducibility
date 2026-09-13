# End-to-end interpolation check in a disposable repository using generated values.
fixture <- tempfile("recovery-check-");dir.create(fixture)
for(d in c("R","analysis","data/raw/pollution"))dir.create(file.path(fixture,d),recursive=TRUE)
file.copy(list.files("R",full.names=TRUE),file.path(fixture,"R"))
file.copy("analysis/01_build_classical.R",file.path(fixture,"analysis"))
for(station in c("Catalagzi Cumayani","Trafik")) for(year in 2019:2020) {
 t <- as.POSIXct(sprintf("%d-02-01 01:00:00",year),tz="UTC")+3600*(0:71)
 y <- seq_len(72)+if(station=="Trafik") 100 else 0
 # Two missing values straddle midnight; the three-hour outage must not be filled.
 y[c(24,25,60:62)] <- NA_real_
 write.csv(data.frame(station=station,ts=format(t,"%Y-%m-%d %H:%M:%S",tz="UTC"),SO2=y),
 file.path(fixture,"data/raw/pollution",sprintf("%s_%d.csv",gsub(" ","_",station),year)),row.names=FALSE)
}
old <- Sys.getenv("FDID_SOURCE_ROOT",unset=NA_character_)
Sys.setenv(FDID_SOURCE_ROOT=file.path(fixture,"data"))
status <- system2(file.path(R.home("bin"),"Rscript"),
 shQuote(file.path(fixture,"analysis/01_build_classical.R")),stdout=TRUE,stderr=TRUE)
if(is.na(old)) Sys.unsetenv("FDID_SOURCE_ROOT") else Sys.setenv(FDID_SOURCE_ROOT=old)
stopifnot(is.null(attr(status,"status")))
s <- readRDS(file.path(fixture,"data/processed/classical_sample.rds"))
stopifnot(nrow(s$near)==4L,all(s$near[1,]==1:24),all(s$near[2,]==25:48),
 all(s$control-s$near==100),identical(as.character(s$calendar$date),
 c("2019-02-01","2019-02-02","2020-02-01","2020-02-02")))
a <- read.csv(file.path(fixture,"output/tables/classical_sample_audit.csv"))
stopifnot(!any(a$included_pair[grepl("02-03$",a$date)]))
unlink(fixture,recursive=TRUE)
cat("Cross-midnight recovery and long-outage exclusion tests passed.\n")
