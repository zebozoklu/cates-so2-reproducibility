.local_script <- if (!is.null(sys.frames()[[1]]$ofile)) sys.frames()[[1]]$ofile else {
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
}
setwd(dirname(dirname(normalizePath(.local_script, mustWork = TRUE))))
source("R/config.R")
source("R/fda_bspline.R")
source("R/fdid.R")
path <- file.path(DIRS$processed, "daily_curves_fda.rds")
if (!file.exists(path)) stop("Run analysis/02b_build_fda_curves.R first")
curves <- readRDS(path)
fit <- fit_functional_did(curves$contrast, curves$D)
coefficient_fit <- fit_functional_did(
  curves$near_coefficients - curves$control_coefficients, curves$D)
stopifnot(max(abs(drop(bspline_basis(curves$grid, curves$basis$df) %*%
                          coefficient_fit$beta) - fit$beta)) < 1e-8)
out <- data.frame(hour = curves$grid, operating_mean = fit$mean_on,
                  shutdown_mean = fit$mean_off, functional_did = fit$beta)
write.csv(out, file.path(DIRS$tables, "bspline_functional_did.csv"), row.names = FALSE)
# Integrate the fitted function; mean(grid values) overweights endpoints.
knots <- c(0, curves$basis$knots, 24)
average_effect <- sum(vapply(seq_len(length(knots) - 1L), function(j) {
  integrate(function(s) drop(bspline_basis(s, curves$basis$df) %*%
                              coefficient_fit$beta), knots[j], knots[j + 1L])$value
}, numeric(1))) / 24
saveRDS(list(fit = fit, coefficient_fit = coefficient_fit, basis = curves$basis,
             dates = curves$dates, average_effect = average_effect),
        file.path(DIRS$processed, "bspline_functional_did_fit.rds"))
png(file.path(DIRS$figures, "bspline_functional_did.png"), width = 1200, height = 760, res = 150)
plot(curves$grid, fit$beta, type = "l", lwd = 2.5, col = "#007F7B",
     xlim = c(0, 24), xlab = "Hour of day",
     ylab = expression("Functional DiD on " ~ SO[2] ~ (mu*g/m^3)),
     main = "Cumayani versus Trafik: direct observed-hour spline fits")
abline(h = 0, lty = 3)
dev.off()
cat("Functional curves:", fit$n_on, "operating,", fit$n_off, "shutdown\n")
cat("Integrated average functional effect:", average_effect, "\n")
