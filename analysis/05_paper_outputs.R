# Reconstruct the two paper plots that previously had no saved plotting script,
# and export the exact numerical quantities reported in the manuscript.
source("R/config.R")
source("R/fdid.R")
source("R/fda_bspline.R")
h <- read.csv(file.path(DIRS$tables,"hourly_did.csv"))
r <- read.csv(file.path(DIRS$tables,"robustness_summary.csv"))
z <- read.csv(file.path(DIRS$tables,"robustness_curves.csv"))
f <- readRDS(file.path(DIRS$processed,"bspline_functional_did_fit.rds"))
s <- readRDS(file.path(DIRS$processed,"daily_curves_fda.rds"))
cls <- readRDS(file.path(DIRS$processed,"classical_sample.rds"))
clock_axis <- function() axis(1,at=seq(0,24,4),labels=sprintf("%02d:00",seq(0,24,4)))
cols <- c("#195C75","#007F7B","#B77630","#945889")
profiles <- as.matrix(h[,c("near_operating","near_shutdown","control_operating","control_shutdown")])
png(file.path(DIRS$figures,"station_period_profiles.png"),width=1600,height=1000,res=180)
par(mar=c(5.2,5.6,1.2,1.2),las=1)
matplot(h$interval_midpoint_hour,profiles,type="l",lty=c(1,2,1,2),lwd=2.5,col=cols,
 xlim=c(0,24),xaxt="n",xlab="Time of day",ylab=expression(SO[2]~(mu*g/m^3)))
clock_axis()
legend("topleft",c("Cumayani: operating","Cumayani: shutdown","Trafik: operating","Trafik: shutdown"),
 col=cols,lty=c(1,2,1,2),lwd=2.5,bty="n",cex=.85)
dev.off()
png(file.path(DIRS$figures,"fda_basis_sensitivity.png"),width=1600,height=1000,res=180)
par(mar=c(5.2,5.6,1.2,1.2),las=1)
p <- z[z$sample=="eligible",]
plot(NA,xlim=c(0,24),ylim=range(p$effect),xaxt="n",xlab="Time of day",
 ylab=expression("Functional DiD estimate ("*mu*"g/m"^3*")"))
clock_axis();abline(h=0,lty=2,col="grey50")
for(j in 1:4) {a<-p[p$K==c(8,10,12,14)[j],];lines(a$hour,a$effect,col=cols[j],lty=j,lwd=2.5)}
legend("bottomleft",paste("K =",c(8,10,12,14)),col=cols,lty=1:4,lwd=2.5,bty="n")
dev.off()
b <- r[r$sample=="eligible",c("K","lambda","min_effect","min_hour","daily_fda")]
b$max_effect <- b$max_hour <- NA_real_
for(i in seq_len(nrow(b))) {a<-p[p$K==b$K[i],];j<-which.max(a$effect);b$max_effect[i]<-a$effect[j];b$max_hour[i]<-a$hour[j]}
write.csv(b,file.path(DIRS$tables,"paper_basis_sensitivity.csv"),row.names=FALSE)
complete <- rowSums(is.finite(s$near_raw))==24 & rowSums(is.finite(s$control_raw))==24
counts <- data.frame(period=c("operating","shutdown"),calendar=c(120,121),
 complete=sapply(0:1,function(d)sum(complete & s$D==d)),
 classical=sapply(0:1,function(d)sum(cls$calendar$off==d)),
 functional=sapply(0:1,function(d)sum(s$D==d)))
write.csv(counts,file.path(DIRS$tables,"paper_sample_counts.csv"),row.names=FALSE)
beta <- f$fit$beta
a <- read.csv(file.path(DIRS$tables,"hourly_vs_bspline.csv"))
crossings <- which(beta[-length(beta)]*beta[-1]<0)
roots <- vapply(crossings,function(i) uniroot(function(t)
 drop(bspline_basis(t,s$basis$df)%*%f$coefficient_fit$beta),s$grid[c(i,i+1)])$root,numeric(1))
metrics <- c(daily_did=mean(h$estimate),functional_average=f$average_effect,
 hourly_min=min(h$estimate),hourly_min_start=h$interval_start_hour[which.min(h$estimate)],
 hourly_max=max(h$estimate),hourly_max_start=h$interval_start_hour[which.max(h$estimate)],
 functional_min=min(beta),functional_min_hour=s$grid[which.min(beta)],
 functional_max=max(beta),functional_max_hour=s$grid[which.max(beta)],
 hourly_functional_correlation=cor(a$hourly_did,a$functional_did),
 lambda=s$basis$lambda,near_operating_15_16=h$near_operating[h$interval_start_hour==15],
 near_shutdown_15_16=h$near_shutdown[h$interval_start_hour==15])
metrics <- c(metrics,setNames(roots,paste0("zero_crossing_",seq_along(roots))))
write.csv(data.frame(quantity=names(metrics),value=unname(metrics)),file.path(DIRS$tables,"paper_metrics.csv"),row.names=FALSE)
print(counts,row.names=FALSE);print(metrics);print(b,row.names=FALSE)
