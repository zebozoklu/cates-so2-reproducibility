fit_functional_did <- function(Y, D) {
  stopifnot(is.matrix(Y), length(D) == nrow(Y), setequal(unique(D), 0:1))
  mean_on <- colMeans(Y[D == 0L, , drop = FALSE])
  mean_off <- colMeans(Y[D == 1L, , drop = FALSE])
  beta <- mean_off - mean_on
  fitted <- matrix(mean_on, nrow(Y), ncol(Y), byrow = TRUE) + D *
    matrix(beta, nrow(Y), ncol(Y), byrow = TRUE)
  residuals <- Y - fitted

  beta_lm <- apply(Y, 2L, function(y) unname(stats::coef(stats::lm(y ~ D))[2]))
  if (max(abs(beta - beta_lm)) > 1e-10) {
    stop("Direct functional contrast and pointwise regressions disagree")
  }

  list(
    beta = beta,
    mean_on = mean_on,
    mean_off = mean_off,
    residuals = residuals,
    D = D,
    n_on = sum(D == 0L),
    n_off = sum(D == 1L)
  )
}

trapezoid_weights <- function(grid, lower, upper, average = TRUE) {
  idx <- which(grid >= lower & grid <= upper)
  if (grid[min(idx)] != lower || grid[max(idx)] != upper) {
    stop("Summary endpoints must lie on the evaluation grid")
  }
  g <- grid[idx]
  w_local <- numeric(length(g))
  dx <- diff(g)
  w_local[-length(g)] <- w_local[-length(g)] + dx / 2
  w_local[-1L] <- w_local[-1L] + dx / 2
  if (average) w_local <- w_local / (upper - lower)
  w <- numeric(length(grid))
  w[idx] <- w_local
  w
}

