# Three implementation checks for the main Cumayani–Trafik direct-fit analysis.
.local_script <- if (!is.null(sys.frames()[[1]]$ofile)) sys.frames()[[1]]$ofile else {
 sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)[1])
}
setwd(dirname(dirname(normalizePath(.local_script,mustWork=TRUE))))
source("R/config.R"); source("R/fda_bspline.R"); source("R/fdid.R")
s <- readRDS(file.path(DIRS$processed,"daily_curves_fda.rds"))
complete <- rowSums(is.finite(s$near_raw))==24 & rowSums(is.finite(s$control_raw))==24
samples <- list(eligible=rep(TRUE,length(s$D)),complete=complete)
# Identical operating-period training data and GCV rule for each K.
training <- rbind(s$near_raw[s$D==0,,drop=FALSE],s$control_raw[s$D==0,,drop=FALSE])
rows <- curves <- tuning <- raw_rows <- list()
for(K in c(8L,10L,12L,14L)) {
 tune <- choose_lambda(training,df=K)
 tuning[[as.character(K)]] <- data.frame(K=K,lambda=tune$grid,gcv=tune$gcv,chosen=tune$grid==tune$lambda)
 fit_matrix <- function(Y) t(vapply(seq_len(nrow(Y)),function(i)
   fit_penalized_bspline(Y[i,],df=K,lambda=tune$lambda,return_coefficients=TRUE),numeric(K)))
 near <- fit_matrix(s$near_raw); control <- fit_matrix(s$control_raw)
 B <- bspline_basis(DENSE_GRID,K)
 if(K==12L) stopifnot(abs(tune$lambda-s$basis$lambda)<1e-12,
  max(abs(near-s$near_coefficients))<1e-9,max(abs(control-s$control_coefficients))<1e-9)
 for(mode in names(samples)) {
  keep<-samples[[mode]];D<-s$D[keep]
  beta<-fit_functional_did((near-control)[keep,,drop=FALSE],D)$beta
  effect<-drop(B%*%beta)
  f<-function(x) drop(bspline_basis(x,K)%*%beta)
  average<-function(a,b,transform=identity) {
   knots<-attr(B,"knots");cuts<-sort(unique(c(a,knots[knots>a & knots<b],b)))
   sum(vapply(seq_len(length(cuts)-1),function(j)
    integrate(function(x) transform(f(x)),cuts[j],cuts[j+1],rel.tol=1e-8,subdivisions=500L)$value,numeric(1)))/(b-a)
  }
  positive<-average(0,24,function(x)pmax(x,0));negative<-average(0,24,function(x)pmin(x,0))
  rows[[length(rows)+1L]]<-data.frame(sample=mode,K=K,lambda=tune$lambda,n_on=sum(D==0),n_off=sum(D==1),
   daily_fda=average(0,24),afternoon_fda=average(12,18),min_effect=min(effect),min_hour=DENSE_GRID[which.min(effect)],
   positive_daily_contribution=positive,negative_daily_contribution=negative,
   cancellation_fraction=1-abs(positive+negative)/(positive-negative))
  curves[[length(curves)+1L]]<-data.frame(sample=mode,K=K,hour=DENSE_GRID,effect=effect)
  if(K==12L) {
   contrast<-(s$near_raw-s$control_raw)[keep,,drop=FALSE]
   raw<-colMeans(contrast[D==1,,drop=FALSE],na.rm=TRUE)-colMeans(contrast[D==0,,drop=FALSE],na.rm=TRUE)
   raw_rows[[mode]]<-data.frame(sample=mode,hour=KNOT_HOURS,raw_did=raw,
    paired_on=colSums(is.finite(contrast[D==0,,drop=FALSE])),paired_off=colSums(is.finite(contrast[D==1,,drop=FALSE])))
  }
 }
 cat("Finished K =",K,"lambda =",tune$lambda,"\n")
}
summary<-do.call(rbind,rows);profiles<-do.call(rbind,curves);raw<-do.call(rbind,raw_rows)
for(i in seq_len(nrow(summary))) {
 a<-profiles$effect[profiles$sample==summary$sample[i] & profiles$K==summary$K[i]]
 b<-profiles$effect[profiles$sample==summary$sample[i] & profiles$K==12]
 summary$correlation_with_K12[i]<-cor(a,b)
 summary$max_difference_from_K12[i]<-max(abs(a-b))
}
complete_raw<-raw[raw$sample=="complete",]
regular<-data.frame(sample="complete",daily=mean(complete_raw$raw_did),
 afternoon=mean(complete_raw$raw_did[complete_raw$hour>=12 & complete_raw$hour<18]))
stopifnot(max(abs(summary$daily_fda-summary$positive_daily_contribution-summary$negative_daily_contribution))<1e-6)
write.csv(summary,file.path(DIRS$tables,"robustness_summary.csv"),row.names=FALSE)
write.csv(profiles,file.path(DIRS$tables,"robustness_curves.csv"),row.names=FALSE)
write.csv(raw,file.path(DIRS$tables,"robustness_hourly_coverage.csv"),row.names=FALSE)
write.csv(regular,file.path(DIRS$tables,"robustness_regular_complete.csv"),row.names=FALSE)
write.csv(do.call(rbind,tuning),file.path(DIRS$tables,"robustness_gcv.csv"),row.names=FALSE)
write.csv(data.frame(date=s$dates,D=s$D,complete=complete),file.path(DIRS$tables,"robustness_dates.csv"),row.names=FALSE)
saveRDS(list(summary=summary,curves=profiles,raw=raw,regular=regular,
 input_md5=unname(tools::md5sum(file.path(DIRS$processed,"daily_curves_fda.rds")))),file.path(DIRS$processed,"robustness.rds"))
png(file.path(DIRS$figures,"robustness_checks.png"),width=1800,height=1250,res=170)
par(mfrow=c(2,2),mar=c(4,4.5,3,1),oma=c(2,0,1,0))
ylim<-range(profiles$effect,raw$raw_did,finite=TRUE)
frame<-function(title) {plot(NA,xlim=c(0,24),ylim=ylim,xlab="Clock hour",ylab="SO2 DiD (ug/m3)",main=title);abline(h=0,lty=3,col="grey60")}
getcurve<-function(mode,K) profiles[profiles$sample==mode & profiles$K==K,]
frame("1. Representations on identical complete dates")
z<-getcurve("complete",12);lines(z$hour,z$effect,col="#007F7B",lwd=3)
points(complete_raw$hour,complete_raw$raw_did,pch=16,col="grey35",cex=.7)
abline(h=regular$daily,lty=2,col="#BB6B20",lwd=2)
legend("bottomleft",c("Functional","Hourly","Daily average"),col=c("#007F7B","grey35","#BB6B20"),lty=c(1,NA,2),pch=c(NA,16,NA),bty="n",cex=.8)
frame("2. Complete versus eligible dates: K = 12")
for(mode in names(samples)) {z<-getcurve(mode,12);lines(z$hour,z$effect,col=if(mode=="eligible")"#007F7B" else "#9B5A9A",lwd=3)}
legend("bottomleft",c("Eligible: 100 / 116 days","Complete: 55 / 110 days"),col=c("#007F7B","#9B5A9A"),lwd=3,bty="n",cex=.8)
colors<-c("#CE8528","#5266A5","#007F7B","#9B5A9A")
for(mode in names(samples)) {
 frame(paste("3. Spline dimension:",mode,"dates"))
 for(j in 1:4) {z<-getcurve(mode,c(8,10,12,14)[j]);lines(z$hour,z$effect,col=colors[j],lwd=2,lty=j)}
 legend("bottomleft",paste("K =",c(8,10,12,14)),col=colors,lwd=2,lty=1:4,bty="n",cex=.8)
}
mtext("Cumayani versus Trafik | February-May 2019 versus 2020 | Smoothing selected using operating-period data only",outer=TRUE,side=1,cex=.8)
dev.off()
print(summary,row.names=FALSE)
