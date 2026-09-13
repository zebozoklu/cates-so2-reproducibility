# Fixed cubic B-spline basis on [0,24]. Hourly averages are approximated
# by values at interval midpoints in this direct-observation sensitivity fit.
bspline_basis <- function(x, df = 12L) {
  if (length(df) != 1L || !is.finite(df) || df != as.integer(df) || df < 4L)
    stop("df must be an integer >= 4")
  if (any(!is.finite(x)) || any(x < 0 | x > 24)) stop("x must lie in [0,24]")
  knots <- seq(0, 24, length.out = df - 2L)
  knots <- knots[-c(1L, length(knots))]
  splines::bs(x, knots = knots, degree = 3L, intercept = TRUE,
              Boundary.knots = c(0, 24))
}

second_difference_penalty <- function(k) {
  crossprod(diff(diag(k), differences = 2L))
}

bspline_system <- function(y, x, df, lambda) {
  if (!is.numeric(y) || length(y) != length(x) || anyDuplicated(x))
    stop("y and unique x must have equal lengths")
  if (length(lambda) != 1L || !is.finite(lambda) || lambda < 0)
    stop("lambda must be finite and nonnegative")
  full_basis <- bspline_basis(x, df)
  ok <- is.finite(y)
  if (sum(ok) < 4L) stop("Too few observed points for spline fit")
  B <- full_basis[ok, , drop = FALSE]
  mapping <- tryCatch(solve(crossprod(B) + lambda * second_difference_penalty(df), t(B)),
                      error = function(e) stop("Singular spline fit; use positive lambda or fewer basis functions"))
  list(coefficients = drop(mapping %*% y[ok]), B = B, mapping = mapping,
       observed = y[ok], n = sum(ok))
}

fit_penalized_bspline <- function(y, x = KNOT_HOURS, grid = DENSE_GRID,
                                  df = 12L, lambda, return_coefficients = FALSE) {
  fit <- bspline_system(y, x, df, lambda)
  if (return_coefficients) return(fit$coefficients)
  drop(bspline_basis(grid, df) %*% fit$coefficients)
}

pooled_gcv <- function(Y, x = KNOT_HOURS, df = 12L, lambda) {
  if (!is.matrix(Y) || !nrow(Y) || ncol(Y) != length(x)) stop("Y must be a nonempty curve matrix")
  scores <- vapply(seq_len(nrow(Y)), function(i) {
    fit <- bspline_system(Y[i, ], x, df, lambda)
    edf <- sum(diag(fit$B %*% fit$mapping))
    if (fit$n - edf <= 1e-8) return(Inf)
    rss <- sum((fit$observed - fit$B %*% fit$coefficients)^2)
    # Standard per-curve GCV; the n factor matters with unequal coverage.
    fit$n * rss / (fit$n - edf)^2
  }, numeric(1))
  mean(scores)
}

choose_lambda <- function(Y, x = KNOT_HOURS, df = 12L,
                          lambda_grid = 10^seq(-4, 5, length.out = 60L)) {
  if (!length(lambda_grid) || any(!is.finite(lambda_grid)) || any(lambda_grid <= 0))
    stop("lambda_grid must contain positive finite values")
  gcv <- vapply(lambda_grid, function(lam) pooled_gcv(Y, x, df, lam), numeric(1))
  if (!any(is.finite(gcv))) stop("No finite GCV candidate")
  j <- which.min(gcv)
  if (j %in% c(1L, length(gcv))) warning("GCV minimum at search boundary; inspect lambda range")
  list(lambda = lambda_grid[j], grid = lambda_grid, gcv = gcv)
}

# x is required because source-label column order is 23.5,0.5,...,22.5.
# Runs are linear within a calendar day; no periodic wrapping is assumed.
max_linear_missing_run <- function(y, x = seq_along(y)) {
  if (length(x) != length(y) || any(!is.finite(x)) || anyDuplicated(x)) stop("Invalid hour ordering")
  r <- rle(!is.finite(y[order(x)]))
  max(c(0L, r$lengths[r$values]))
}
