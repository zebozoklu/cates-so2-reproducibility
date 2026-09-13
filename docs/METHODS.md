# Implemented specification

The contrast is (Cumayanı shutdown − Cumayanı operating) − (Trafik shutdown −
Trafik operating), with equal weight for each retained date within a period.

## Classical sample

The continuous hourly series is reconstructed on its full timestamp grid.
Linear interpolation fills only missing runs of at most two hours, bounded
by observed values; it may cross midnight. Extrapolation is not allowed.
Each station-day needs at least 20 observed values, no missing hour in a
longer outage, and a complete profile after recovery. Both stations must
qualify. The reported sample is 98 operating and 115 shutdown dates.

Daily DiD is the difference in period means of daily station contrasts.
Hourly DiD is the same comparison for each of the 24 interval-start columns.
On this common completed sample, daily DiD equals the average hourly DiD.

## Functional sample

Each station-day needs at least 20 finite observed hours and no within-day
missing run longer than two hours, ordered chronologically. The run check
does not wrap midnight. No hourly values are filled before fitting. Both
stations must qualify: 100 operating and 116 shutdown dates.

Hourly averages are approximated by point values at interval midpoints.
Cubic B-splines use fixed boundary knots 0 and 24 and uniformly spaced
interior knots, giving K=12 basis functions. The fit minimizes observed-hour
squared residuals plus lambda times the squared second differences of
adjacent coefficients. The basis is identical when rows are missing and
when it is evaluated on a dense prediction grid. No periodic endpoint
constraint is imposed. Predictions at missing or boundary times remain
model-dependent; they are not recovered observations.

A single lambda is selected from 60 log-spaced candidates between 10^-4 and
10^5. For each candidate, the criterion is the arithmetic mean of per-curve
GCV scores n*RSS/(n−edf)^2, pooling both stations' eligible operating-period
curves only. The selected lambda, 0.0275853161762919, is then used for both
stations and both periods. Shutdown data never enter tuning.

The effect is computed both from mean station-contrast curves and from the
coefficient-space contrast; reconstruction must agree within 1e-8. It is
evaluated on a 0.05-hour grid (three minutes). The full-day summary integrates
the spline across its knot intervals and divides by 24; it is not the
unweighted mean of a grid that contains both endpoints. Reported extrema are
grid extrema. Zero crossings are numerically solved within sign-changing
adjacent grid intervals.

## Robustness and interpretation

K=8,10,12,14 each receives its own lambda chosen on the same eligible
operating-period training curves. The same fitted curves can also be
restricted to the 55 operating and 110 shutdown complete dates for a
common-sample comparison; tuning is not repeated on that restriction.

The classical and functional samples and missingness treatments differ.
The integrated spline contrast is therefore not constrained to equal the
classical daily mean. The high correlation is a descriptive comparison, not
a formal test that the estimands or samples are identical.

The distributed pipeline produces point estimates and sensitivity summaries.
It does not implement the referenced functional event-study inference
procedure, simultaneous confidence bands, meteorological adjustment, or a
parallel-trends test. Successful reproduction establishes computational
agreement with the local inputs, not causal identification or a mechanism.
