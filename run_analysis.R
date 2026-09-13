# Run from any working directory. Raw inputs may live outside this repository.
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)[1])
setwd(dirname(normalizePath(script, mustWork=TRUE)))
args <- commandArgs(TRUE)
mode <- if(length(args)) args[1] else "main"
if(!mode %in% c("main","sources","map","all")) stop("Use main, sources, map, or all")
source("R/config.R")
# Resolve the external input directory before child scripts change directory.
Sys.setenv(FDID_SOURCE_ROOT=normalizePath(SOURCE_ROOT, mustWork=TRUE))
required <- unlist(lapply(c(NEAR_STATION,CONTROL_STATION), function(s)
 file.path(POLLUTION_DIR,sprintf("%s_%d.csv",gsub(" ","_",s),PERIODS$year))))
missing <- required[!file.exists(required)]
if(length(missing)) stop("Supply the raw inputs described in docs/DATA_REQUIREMENTS.md:\n",paste(missing,collapse="\n"))
run <- function(f) {
 cat("\nRunning ",f,"\n",sep="")
 status <- system2(file.path(R.home("bin"),"Rscript"),shQuote(f))
 if(status!=0L) stop("Analysis stopped in ",f)
}
if(mode %in% c("main","all")) {
 for(f in c("tests/test_spline.R","tests/test_inputs.R","tests/test_recovery.R","analysis/01_build_classical.R",
            "analysis/02b_build_fda_curves.R","analysis/04b_estimate_fda.R",
            "analysis/04c_main_did_figures.R","analysis/04e_robustness.R",
            "analysis/05_paper_outputs.R","tests/test_results.R","tests/test_robustness.R")) run(f)
}
if(mode %in% c("sources","all")) run("analysis/06_generation_check.R")
if(mode %in% c("map","all")) {
 for(p in c("sf","ragg","svglite")) if(!requireNamespace(p,quietly=TRUE)) stop("Install optional map package: ",p)
 run("analysis/00_verify_geography.R")
 run("analysis/00b_figure_x.R")
}
writeLines(capture.output(sessionInfo()),"output/session-info.txt")
# Record only hashes and relative names of consumed pollution extracts, locally.
all_inputs <- unique(c(required,unlist(lapply(c(NEAR_STATION,CONTROL_STATION),function(s)
 file.path(POLLUTION_DIR,sprintf("%s_%d.csv",gsub(" ","_",s),2018:2021))))))
all_inputs <- all_inputs[file.exists(all_inputs)]
write.csv(data.frame(file=basename(all_inputs),md5=unname(tools::md5sum(all_inputs))),
 "output/tables/input_checksums.csv",row.names=FALSE)
cat("\nReproduction completed. Results are in output/; all generated files stay local.\n")
