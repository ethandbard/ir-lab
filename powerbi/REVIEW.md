# IR Lab review and dashboard brief

## Purpose and source

IR Lab is a static Quarto learning site with browser-based R and Python, Observable/D3
animations, and an Excel workbook. The audience is institutional research analysts
learning methods. The Power BI report should let them explore the same data in a familiar
reporting tool. Its primary use is analytical exploration, not institutional performance ranking.

Source of truth for this extension: `data/institutions.csv`, with definitions in
`data/variables.csv` and transformations in `build_data.R`. The builder assembles active,
non-administrative institutions from HD2023 and joins EFFY2023, EF2023D, GR2023, SFA2223,
and C2023_C by UNITID. The provided extract has 5,988 unique institutions and 44 columns.
Raw IPEDS collection files were not rebuilt during this task.

This is a cross-section with mixed reporting and cohort periods. Aid/net price and
awards are labeled 2022–23 in the source; retention spans fall 2022 to fall 2023. Six-year
completion concerns an earlier entering cohort. A trend chart would imply time coverage
the extract does not contain, so none is included.

## Review findings addressed

1. **Regression DAX did not compile as written.** The lesson claimed a measure could
   return a reusable table (`[Pell Fit]`). Measures must be scalar. Each regression
   measure now has a local filtered table and guards for small or constant-X selections.
2. **Completion bin edges mishandled 100%.** A plain FLOOR creates a 100–105 bin.
   The project and lesson use 20 bins from 0 to 100, with 100 included in 95–100.
3. **Power BI tabs were recipe-only.** Three lesson tabs now contain configurable
   report slots and a project download fallback. They retain the existing live exercises.
4. **Cluster membership needed a reproducible definition.** Power BI now displays
   the R lesson's five-feature, four-group snapshot. Cohort selection, scaling, seed,
   and label ordering are recorded. Built-in clustering recipes were replaced with
   instructions consistent with the saved model.
5. **Footer privacy wording would become inaccurate.** The footer now explains that
   selecting an embedded report loads Power BI from Microsoft.

## Metric and cohort contracts

| Scope | Eligibility / denominator | Behavior |
| --- | --- | --- |
| Overview institutions | Unique active institutions in current filters | COUNTROWS; UNITID is unique |
| Distributions | Four-year, nonblank six-year bachelor completion; initially all cohorts | 1,928 institutions; cohort, control, and state filters affect the page |
| Mean / median completion | Eligible institution rates, unweighted | Describes institutions; never presented as a pooled student probability |
| Completion SD | Sample standard deviation | Percentage points; blank if fewer than two observations |
| Completion skewness | Mean of cubed deviations divided by sample SD | Same definition as the Power BI lesson; not Excel's adjusted SKEW |
| Regression | Four-year, bachelor cohort ≥30, nonblank Pell and completion | 1,648 institutions; OLS refits with page filters |
| Peer groups | Four-year public/nonprofit, bachelor cohort ≥100, all five features complete | 1,448 institutions; fixed k=4 model, filters do not refit |
| Net price | Nonblank institution net prices | Median of institutional averages; public figures use in-state students |

Rates in the source are already 0–100. Formats append a literal percent sign; they
do not apply the usual 0–1 percentage multiplier. Blank values remain null through
Power Query and are not imputed or changed to zero. Regression slope units are
completion percentage points per Pell percentage point. This is an association
across institutions and does not estimate a student-level or causal effect.

Unfiltered OLS reference: slope -0.6706860037, intercept 77.8818948491,
R² 0.3264817937, residual standard error 16.0912961487 percentage points.
These were independently calculated from the CSV with Python's standard library.

## Chart map

| Page / question | Native visuals and grain | Interpretation / design |
| --- | --- | --- |
| Overview: what is in the extract? | Cards, sector bars, median-completion bars, institution table | Counts establish coverage; table retains source context |
| Distributions: what shape do reported rates have? | 20-bin column histogram, control medians, SD/skew cards | Numeric bin ordering; 0-baseline counts; full last bin |
| Regression: how do Pell share and completion vary together? | Institution scatter, OLS cards, detail table | One dot per UNITID; axes 0–100; association only |
| Peers: how do saved groups differ? | Institution scatter by group, group-size bars, profile table | 2D projection of 5D fit; medians in original units |

Report canvas: 1280×900, summary above charts and lookup. Palette follows IR Lab's
cobalt, orange, green, navy, and paper theme, with purple for a fourth peer group.
Legends and group labels accompany colors; the profile table supplies a non-color
comparison. All visuals are native Power BI types. The report includes no time series,
rankings, targets, or student-weighted outcome measures unsupported by this extract.

## Remaining considerations

- The site's clustering animation and introductory row count use a looser feature
  filter than the five-feature R/Python fit. The Power BI page explicitly states its
  stricter five-feature population; the animation was left as a two-dimensional lesson.
- R and Python use different standardization conventions and k-means implementations;
  exact memberships need not match. The report explicitly follows the worked R fit.
- Power BI Service publication and access depend on a workspace and account choice.
  No service deployment has been performed and no tenant access was inferred.
- The saved Codex workspace path was stale. The actual reviewed project is
  `C:/Users/ethan/Code/Data Science/ir-lab`.
