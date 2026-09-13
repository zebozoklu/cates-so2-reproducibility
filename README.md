# ÇATES shutdown and intraday SO₂: reproducibility appendix

Code accompanying the paper's comparison of daily, hourly and functional
Difference-in-Differences estimates for Cumayanı versus Trafik, February–May
2019 versus February–May 2020.

**No research data or generated results are included.** Supply the original
source extracts locally before reproducing the empirical results. This folder
is prepared for GitHub; a public repository URL has not yet been assigned.

## Quick start

Install R 4.4.3 (the verified version). The main analysis uses base R and its
recommended `splines` package; no additional packages or downloads are needed.
From this repository's root:

```sh
Rscript tests/test_spline.R
Rscript tests/test_inputs.R
Rscript tests/test_recovery.R
```

These tests generate artificial inputs and run without research data.

Place the four required pollution extracts in `data/raw/pollution/`, following
[the input specification](docs/DATA_REQUIREMENTS.md), then run:

```sh
Rscript run_analysis.R main
```

Alternatively, leave all inputs outside the repository:

```sh
FDID_SOURCE_ROOT=/absolute/path/to/local/data Rscript run_analysis.R main
```

`FDID_SOURCE_ROOT` must point to the directory **containing `raw/`**. It is
read as input only. Processed objects, tables, figures and checksums are written
locally under this repository's `data/processed/` and `output/` directories.
The scripts never read old processed objects from the original project.

The main run rebuilds both samples, fits the spline model, creates the five
results figures, re-estimates four basis dimensions, and checks the reported
sample counts and headline estimates. Result assertions intentionally fail
if revised source data no longer reproduce the paper; investigate those
changes rather than silently accepting a different sample.

## Additional paper material

```sh
Rscript run_analysis.R sources  # Verify CATES generation and hourly coverage
Rscript run_analysis.R map      # Rebuild the study-area map and geography audit
Rscript run_analysis.R all      # Run main + sources + map
```

These modes require additional inputs listed in the input specification.
Map rendering also requires `sf`, `ragg` and `svglite`, plus an R build with
Cairo support. The map uses Cairo PDF instead of the original Mac-only Quartz
device; font rendering can differ across systems. Install optional packages:

```r
install.packages(c("sf", "ragg", "svglite"))
```

## Folder guide

| Folder/file | Purpose |
|---|---|
| `run_analysis.R` | Ordered run, failure handling, local checksums and session record |
| `R/` | Shared configuration, validated input readers, interpolation support, spline and DiD helpers |
| `analysis/01_build_classical.R` | Continuous-series short-gap recovery and classical sample |
| `analysis/02b_build_fda_curves.R` | Direct observed-hour spline fitting and operating-period tuning |
| `analysis/04b_estimate_fda.R` | Functional contrast, coefficient check and integration |
| `analysis/04c_main_did_figures.R` | Daily/hourly comparison and main three figures |
| `analysis/04e_robustness.R` | Basis dimensions 8/10/12/14 and common complete-date comparison |
| `analysis/05_paper_outputs.R` | Station profiles, basis figure and exact paper tables/metrics |
| `analysis/06_generation_check.R` | Shutdown status and complete generation timestamp coverage |
| `analysis/00*.R` | Optional geography checks and study-area map |
| `tests/` | Artificial-input tests and empirical replication assertions |
| `docs/` | Input contract, methods, paper mapping and verification record |

Start with [the paper-to-code mapping](docs/PAPER_TO_CODE.md) and
[verification record](docs/VERIFICATION.md). The earlier project's periodic
spline/bootstrap, monthly, weather and alternative-control explorations are
not the current paper's main method and are not bundled here.

## Sharing

Only upload this folder's code and documentation. `.gitignore` excludes
research data, outputs, environment files and common data formats, but it does
not remove anything already tracked in an existing Git repository. This is a
new standalone folder with no inherited Git history. The included GitHub
workflow parses the R files and runs the three artificial-input tests;
empirical checks require the privately supplied inputs.

