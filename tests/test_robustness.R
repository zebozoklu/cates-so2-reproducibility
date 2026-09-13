source("R/config.R"); source("R/fdid.R")
r<-readRDS(file.path(DIRS$processed,"robustness.rds"))
s<-readRDS(file.path(DIRS$processed,"daily_curves_fda.rds"))
stopifnot(identical(r$input_md5,unname(tools::md5sum(file.path(DIRS$processed,"daily_curves_fda.rds")))) )
complete<-rowSums(is.finite(s$near_raw))==24 & rowSums(is.finite(s$control_raw))==24
raw<-fit_functional_did((s$near_raw-s$control_raw)[complete,,drop=FALSE],s$D[complete])$beta
stopifnot(max(abs(raw-r$raw$raw_did[r$raw$sample=="complete"]))<1e-9)
stopifnot(abs(mean(raw)-r$regular$daily)<1e-9)
for(i in seq_len(nrow(r$summary))) {
 row<-r$summary[i,];z<-r$curves[r$curves$sample==row$sample & r$curves$K==row$K,]
 w<-trapezoid_weights(z$hour,0,24)
 stopifnot(abs(sum(w*z$effect)-row$daily_fda)<0.002,
           abs(sum(w*pmax(z$effect,0))-row$positive_daily_contribution)<0.002,
           abs(sum(w*pmin(z$effect,0))-row$negative_daily_contribution)<0.002)
 w<-trapezoid_weights(z$hour,12,18)
 stopifnot(abs(sum(w*z$effect)-row$afternoon_fda)<0.002)
}
# K12 eligible results must reproduce the existing analysis, without changing fits.
e<-r$curves$effect[r$curves$sample=="eligible" & r$curves$K==12]
stopifnot(max(abs(e-fit_functional_did(s$contrast,s$D)$beta))<1e-8)
cat("Robustness verification passed: common-sample hourly contrast, scalar identity, signed integrals and original FDA reproduction.\n")
