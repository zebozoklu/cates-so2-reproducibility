# Descriptive study-area map; coordinates are read from audited local metadata.
.local_script <- if (!is.null(sys.frames()[[1]]$ofile)) sys.frames()[[1]]$ofile else {
 sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)[1])
}
setwd(dirname(dirname(normalizePath(.local_script,mustWork=TRUE))))
suppressPackageStartupMessages(library(sf))
source("R/config.R")
station<-read.csv(file.path(DIRS$tables,"station_metadata.csv"))
plant<-read.csv(file.path(DIRS$tables,"facility_metadata.csv"))
other_plants<-plant[match(c("ZETES I","ZETES II","ZETES III"),plant$plant),]
plant<-plant[plant$plant=="CATES",]
station<-station[match(c("Catalagzi Cumayani","Trafik","Kozlu"),station$analysis_name),]
stopifnot(nrow(plant)==1,!anyNA(station$lon),!anyNA(station$lat))
points_table<-data.frame(name=c("ÇATES","Cumayanı","Trafik","Kozlu"),
 role=c("Coal-fired power plant","Near monitoring station","Comparison station","Additional comparison station"),
 lon=c(plant$lon,station$lon),lat=c(plant$lat,station$lat),
 source=c(plant$coordinate_source,station$coordinate_source))
points_table<-rbind(points_table,data.frame(name=other_plants$plant,
 role="Other coal-fired power plant",lon=other_plants$lon,lat=other_plants$lat,
 source=other_plants$coordinate_source))
stopifnot(nrow(points_table)==7,!anyNA(points_table))
locations<-st_as_sf(points_table,coords=c("lon","lat"),crs=4326,remove=FALSE)
xy<-st_coordinates(st_transform(locations,32636))
zip<-file.path(SOURCE_ROOT,"raw/cartography/ne_10m_land.zip")
if(!file.exists(zip)) stop("Missing cached Natural Earth land archive; see docs/DATA_REQUIREMENTS.md")
folder<-file.path(DIRS$processed,"cartography/ne_10m_land")
if(!dir.exists(folder)) unzip(zip,exdir=folder)
land<-st_read(file.path(folder,"ne_10m_land.shp"),quiet=TRUE)
# Crop before UTM projection: global polygons cannot be projected as a whole.
sf_use_s2(FALSE)
land<-suppressWarnings(st_crop(land,xmin=31.5,ymin=41.2,xmax=32.2,ymax=41.8))
stopifnot(nrow(land)>0)
land<-st_transform(land,32636)
# A local UTM map preserves the scale bar; north arrow shows true north locally.
center<-colMeans(xy[1:4,]);xlim<-center[1]+c(-12000,12000);ylim<-center[2]+c(-7000,8000)
box<-st_as_sfc(st_bbox(c(xmin=xlim[1],ymin=ylim[1],xmax=xlim[2],ymax=ylim[2]),crs=32636))
land<-suppressWarnings(st_intersection(land,box))
write.csv(points_table,file.path(DIRS$tables,"figure_x_coordinates.csv"),row.names=FALSE,fileEncoding="UTF-8")
draw<-function() {
 par(mar=c(.4,.4,.4,.4),family="sans",xaxs="i",yaxs="i")
 plot(NA,xlim=xlim,ylim=ylim,asp=1,axes=FALSE,xlab="",ylab="")
 u<-par("usr")
 rect(u[1],u[3],u[2],u[4],col="#E8F0F3",border=NA)
 plot(st_geometry(land),add=TRUE,col="#F5F3EC",border="#A7B5B7",lwd=.9)
 text(xlim[1]+4500,ylim[2]-3400,"BLACK SEA",col="#607E8A",cex=1.2,font=3)
 text(xlim[2]-1800,ylim[1]+2800,"Zonguldak",adj=1,cex=1.0,col="#7B7D74")
 text(xlim[2]-1800,ylim[1]+2000,"TÜRKİYE",adj=1,cex=.75,col="#7B7D74")
 points(xy[1,1],xy[1,2],pch=24,cex=2.0,bg="#B46D2D",col="#70451F",lwd=1)
 points(xy[2:3,1],xy[2:3,2],pch=21,cex=1.6,bg="#244E5C",col="white",lwd=1.2)
 points(xy[4,1],xy[4,2],pch=21,cex=1.4,bg="white",col="#697C81",lwd=1.4)
 label<-function(i,dx,dy,sub,adj=0) {
  x<-xy[i,1]+dx;y<-xy[i,2]+dy
  text(x,y,points_table$name[i],adj=c(adj,.5),cex=1.05,font=2,col="#243C43")
  text(x,y-520,sub,adj=c(adj,.5),cex=.70,col="#59696C")
 }
 points(xy[5:7,1],xy[5:7,2],pch=24,cex=1.1,bg="#939A99",col="#66716F",lwd=.8)
 # Short leader lines distinguish the tightly clustered facilities.
 segments(xy[1,1]+250,xy[1,2]+250,xy[1,1]+650,xy[1,2]+1500,col="#B46D2D",lwd=.8)
 label(1,800,1800,"")
 plant_label<-function(i,dx,dy,adj) {
  x<-xy[i,1]+dx;y<-xy[i,2]+dy
  segments(xy[i,1],xy[i,2],x+if(adj==1)150 else -150,y,col="#929B99",lwd=.7)
  text(x,y,points_table$name[i],adj=c(adj,.5),cex=.8,col="#66716F")
 }
 plant_label(5,-1700,350,1)
 plant_label(6,-2900,0,1)
 plant_label(7,1700,-150,0)
 label(2,650,-100,"Near monitoring station")
 label(3,650,-50,"Comparison station")
 label(4,650,-100,"Additional comparison")
 # Scale is in projected metres; understated 0–2–4 km bar.
 sx<-xlim[1]+1900;sy<-ylim[1]+1000
 rect(sx,sy,sx+2000,sy+130,col="#344C54",border=NA)
 rect(sx+2000,sy,sx+4000,sy+130,col="white",border="#344C54",lwd=.7)
 text(sx+c(0,2000,4000),sy-370,c("0","2","4 km"),cex=.7,col="#344C54")
 # True-north direction projected at the local map centre.
 north<-st_coordinates(st_transform(st_as_sf(data.frame(lon=31.9,lat=c(41.5,41.51)),coords=c("lon","lat"),crs=4326),32636))
 v<-north[2,]-north[1,];v<-v/sqrt(sum(v*v))*1200
 nx<-xlim[2]-1500;ny<-ylim[2]-2400
 arrows(nx,ny,nx+v[1],ny+v[2],length=.075,lwd=1.1,col="#344C54")
 text(nx+v[1],ny+v[2]+450,"N",cex=.85,col="#344C54")
 box(col="#C4CCCA",lwd=.6)
}
ragg::agg_png(file.path(DIRS$figures,"figure_x_study_area.png"),width=2400,height=1500,res=300)
draw();dev.off()
grDevices::cairo_pdf(filename=file.path(DIRS$figures,"figure_x_study_area.pdf"),width=8,height=5,family="Arial")
draw();dev.off()
svglite::svglite(file.path(DIRS$figures,"figure_x_study_area.svg"),width=8,height=5)
draw();dev.off()
cat("Figure X exported as PNG, PDF and SVG.\n")
