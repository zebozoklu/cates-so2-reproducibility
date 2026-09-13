# Verification record — 13 September 2026

## Executed checks

The new repository was run from a newly created output state, reading the
existing raw inputs from an external directory. No processed RDS object or
saved estimate from the original project was copied into the repository.

- `Rscript run_analysis.R main`: passed, including all four spline dimensions,
  coefficient reconstruction, numerical integration and empirical assertions.
- `Rscript tests/test_recovery.R`: passed independently on artificial inputs.
- `Rscript run_analysis.R sources`: passed. The 2020 window contains exactly
  2,904 hourly records, all zero; 2019 contains 2,880 records with positive
  production in the window.
- `Rscript run_analysis.R map`: completed, including geography/identity checks.
- All 22 distributed R files parsed successfully.
- The final code-only ZIP was extracted into a separate temporary folder;
  all three artificial-input test suites passed there without research data.

The main run also executed the spline, input, saved-result and robustness
tests. The public CI workflow runs only the artificial-input tests, so it
requires no research data. The workflow itself has not run on GitHub yet.

## Agreement with the paper

| Quantity | Regenerated value | Paper |
|---|---:|---:|
| Complete dates, operating / shutdown | 55 / 110 | 55 / 110 |
| Classical dates, operating / shutdown | 98 / 115 | 98 / 115 |
| Functional dates, operating / shutdown | 100 / 116 | 100 / 116 |
| Classical daily DiD | 2.911931 | approximately 2.9 |
| Functional daily average | 2.963529 | approximately 3.0 |
| Hourly minimum, 15:00–16:00 | −27.598812 | approximately −27.6 |
| Hourly maximum, 22:00–23:00 | 20.583222 | approximately 20.6 |
| Functional minimum, 15:00 | −23.904017 | approximately −23.9 |
| Functional maximum | 21.183979 | approximately 21.2 |
| Hourly/functional correlation | 0.992144 | 0.992 |
| Cumayanı operating mean, 15:00–16:00 | 37.198980 | approximately 37.2 |
| Cumayanı shutdown mean, 15:00–16:00 | 9.081130 | approximately 9.1 |

Concentrations and contrasts are in micrograms per cubic metre. The entire
K=8/10/12/14 sensitivity table also agrees with the paper at its reported
precision. No change to the paper's headline estimates was required.

## Repairs made in this standalone package

1. The older `run_all.R` and online-appendix instructions reproduced a
   different complete-case periodic-spline analysis. The new runner follows
   the current paper's recovered-classical and direct observed-hour models.
2. The main plotting script read a legacy `applied_paper/data/processed/sample.rds`
   even though the current sample builder wrote a different location. The
   package now generates and consumes `data/processed/classical_sample.rds`
   in a single ordered pipeline.
3. Station-period and paper-style basis-sensitivity figures had image files
   but no saved matching plotting script. The package now reconstructs these
   figures and exports their numerical inputs from the verified estimates.
4. Raw-input validation now rejects malformed/non-hourly timestamps and wrong
   station names, and consistently treats non-finite values as missing.
5. The map's Mac-only Quartz PDF call was replaced by Cairo. The map run
   completed, but graphics devices/fonts can issue Turkish glyph warnings;
   exact typography across platforms is not established by this code audit.

The scientific spline fit, operating-period GCV rule, DiD sign convention,
calendar assignment and sample thresholds are preserved.

## Limits

This is a computational audit with cached local sources. It does not certify
fresh download availability, legal/permit chronology, or the content of cited
external papers. The original Ministry extraction timestamps remain unknown.
The map uses supplied registry snapshots and descriptive facility coordinates.
The core analysis is deterministic; no bootstrap or event-study inference is
claimed. Successful computation does not establish parallel trends, isolate
pandemic-period changes, or identify atmospheric mechanisms.

## Software

Verified with R 4.4.3 on macOS, using base/recommended packages for the main
analysis. Optional map versions: sf 1.0-19, ragg 1.3.3, svglite 2.1.3.
Each run writes its actual `sessionInfo()` locally to `output/session-info.txt`.

## Pollution snapshot fingerprints

These are file hashes, not observations. Matching them allows an authorised
holder of the extracts to identify the local snapshot used in verification.
The four required 2019/2020 files were byte-identical in the original root
and applied-paper input folders.

| File | MD5 |
|---|---|
| Catalagzi_Cumayani_2019.csv | f9522916c6d331a54a12a4df5e07683f |
| Catalagzi_Cumayani_2020.csv | 38413a96dac5147732739dcee0afd615 |
| Trafik_2019.csv | fd9bf0beac81cd20fb05e41e7f4166a9 |
| Trafik_2020.csv | 5ec5b892c2b86c4571aab8990aa099d4 |
| Catalagzi_Cumayani_2021.csv (optional boundary input present) | ae8cf5490cc2cfbe154c6dff0c133a1f |
| Trafik_2021.csv (optional boundary input present) | c25aebd2b91fe99c8515377667e11282 |
