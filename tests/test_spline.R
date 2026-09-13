source("R/config.R")
source("R/fda_bspline.R")
# Regression for the original data-dependent knot bug.
x <- KNOT_HOURS
B <- bspline_basis(x)
grid <- sort(unique(c(DENSE_GRID, x)))
stopifnot(max(abs(B - bspline_basis(grid)[match(x, grid), ])) < 1e-12)
keep <- seq_along(x) != 8L
stopifnot(max(abs(B[keep, ] - bspline_basis(x[keep]))) < 1e-12)
# Known coefficient curve, with genuinely missing observations.
c0 <- sin(seq_len(12)) + 10
y <- drop(B %*% c0)
y[c(5, 12)] <- NA_real_
est <- fit_penalized_bspline(y, lambda = 0, return_coefficients = TRUE)
stopifnot(max(abs(est - c0)) < 1e-8)
# Missing-run calculation must follow chronological times, not source labels.
y <- rep(1, 24); y[c(1, 23, 24)] <- NA_real_
stopifnot(max_linear_missing_run(y, x) == 3L)
y <- rep(1, 24); y[c(1, 2, 3)] <- NA_real_
stopifnot(max_linear_missing_run(y, x) == 2L)
# GCV matches the formula with unequal observation counts.
Y <- rbind(seq_len(24), (seq_len(24) - 12)^2)
Y[2, c(4, 9)] <- NA_real_
expected <- mean(vapply(1:2, function(i) {
  f <- bspline_system(Y[i, ], x, 12, 0.1)
  H <- f$B %*% f$mapping
  f$n * sum((f$observed - H %*% f$observed)^2) / (f$n - sum(diag(H)))^2
}, numeric(1)))
stopifnot(abs(pooled_gcv(Y, lambda = 0.1) - expected) < 1e-9)
stopifnot(inherits(try(fit_penalized_bspline(rep(NA_real_, 24), lambda=1), silent=TRUE), "try-error"))
stopifnot(inherits(try(choose_lambda(matrix(numeric(), 0, 24)), silent=TRUE), "try-error"))
cat("Synthetic spline tests passed.\n")
