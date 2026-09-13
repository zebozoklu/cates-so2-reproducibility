# Paper-to-code mapping

The reference is the current UC3M paper draft (the template folder ending
in `(2)`), audited on 13 September 2026. Paths below are generated locally;
none of these output files are distributed.

| Paper item | Implementation | Generated result |
|---|---|---|
| Table: construction of analysis samples | `01_build_classical.R`, `02b_build_fda_curves.R`, `05_paper_outputs.R` | `output/tables/paper_sample_counts.csv` |
| Daily estimate, hourly minimum/maximum | `04c_main_did_figures.R` | `output/tables/hourly_did.csv`, `paper_metrics.csv` |
| Hour-by-hour DiD figure | `04c_main_did_figures.R` | `output/figures/hourly_did.png` |
| Functional estimate, extrema and daily integral | `04b_estimate_fda.R`, `05_paper_outputs.R` | `output/tables/bspline_functional_did.csv`, `paper_metrics.csv` |
| Functional DiD figure | `04c_main_did_figures.R` | `output/figures/bspline_functional_did.png` |
| Hourly/functional comparison and correlation | `04c_main_did_figures.R` | `output/tables/hourly_vs_bspline.csv`, `output/figures/hourly_vs_bspline.png` |
| Four station-period profiles | `05_paper_outputs.R` | `output/figures/station_period_profiles.png`; underlying columns in `hourly_did.csv` |
| Basis-dimension sensitivity table and figure | `04e_robustness.R`, `05_paper_outputs.R` | `output/tables/paper_basis_sensitivity.csv`, `output/figures/fda_basis_sensitivity.png` |
| Complete-date representation comparison | `04e_robustness.R` | `output/tables/robustness_summary.csv`, `robustness_hourly_coverage.csv` |
| Zero generation February–May 2020 | `06_generation_check.R` | `output/tables/paper_generation_check.csv` |
| Study-area map | `00_verify_geography.R`, `00b_figure_x.R` | `output/figures/figure_x_study_area.png` |

Script names in the table are relative to `analysis/`. Bare output filenames
in a cell share the preceding directory. The two additional results plots
have newly saved plotting scripts using the verified estimates; styling may
differ from the original hand-produced graphics.

## Reading the automated checks

- `test_spline.R`: fixed knots, known-coefficient recovery with missing values,
  chronological gaps, unequal-coverage GCV and invalid fit inputs.
- `test_inputs.R`: end-label calendar assignment, malformed/non-hourly labels,
  station mismatch, non-finite values, duplicates and a known DiD contrast.
- `test_recovery.R`: actual sample builder on artificial annual files, including
  a two-hour gap across midnight and exclusion of a three-hour outage.
- `test_results.R`: retained missing values, coefficient reconstruction, paper
  counts, smoothing parameter and headline rounded estimates.
- `test_robustness.R`: common-sample scalar identity, signed integration and
  reproduction of the original K=12 fit.

Only the first three tests are suitable for a public CI run without inputs.
