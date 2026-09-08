# IR Lab audit

Date: September 7, 2026. Scope: accuracy, understandability, interactivity, animation, style, prose, and consistency across the 18 lessons, the workbook, the Power BI recipes, and the data files.

This report continues the ChatGPT Codex audit that stopped at the ChatGPT usage limit at 18:15 before it could write up its findings. Every Codex finding was re-verified against the source, and the checks Codex had not reached were run. Nothing in the repository was changed; the only new file is this one.

How the checks were run:

- `python grade.py` on all 18 lessons (54 exercises) with local R 4.6.0 and Python 3.14.
- Every `#| check: true` chunk read for what a wrong answer can slip past.
- Every formula in `build_workbook.R` and every `dax` block in the lessons read against the R frames they claim to match.
- The 18 lessons opened in a browser at desktop width (Codex) and at a 375 px phone width (this session).
- Data files reconciled with pandas; the IPEDS dictionaries in `../ipeds/data/dict` quoted for definitions.
- Hard-coded numbers in the prose recomputed from `data/institutions.csv`.

## Summary

The core holds up. All 54 exercises grade correctly in the browser, all 18 animations render with populated readouts and no console errors, 3,154 internal links resolve, the data files reconcile to the student, and the constants the DAX blocks embed match the R fits to the rounding shown.

Seven items need a fix. Three affect the numbers a reader sees: the `distributions` sheet turns 845 blanks into zeros, the site says the headcount and completions describe 2023-24 when the dictionaries say 2022-23, and four columns labeled "degrees awarded" count students. The other four are recipes and checks that fail quietly: five DAX blocks cannot run as written, four R checks accept correct numbers attached to the wrong groups, two prose figures are wrong, and the local grader fails three correct solutions. Eight smaller items follow, then the list of what passed and the open decisions.

## Fix these

### 1. The distributions sheet turns blanks into zeros

The summary block on the `distributions` sheet filters with `IF(Institutions[level]="4-year", Institutions[grad_rate_bach_6yr])` inside `MEDIAN`, `STDEV.S`, `SKEW`, and both `PERCENTILE.INC` calls (`build_workbook.R` lines 83 to 88). Inside an array, a blank cell becomes 0. There are 845 four-year institutions with no six-year rate, so five of the nine statistics are wrong while `Count` and `Mean` stay right, because `COUNTIFS` and `AVERAGEIFS` skip blanks.

| Statistic | Correct | Sheet as built |
| --- | --- | --- |
| Median | 53.8 | 41.8 |
| Standard deviation | 21.0 | 30.2 |
| 25th percentile | 39.8 | 0.0 |
| 75th percentile | 67.8 | 61.5 |
| Skewness | −0.10 | +0.06 |

The lesson's own Excel table repeats the same formulas (`eda-distributions.qmd` lines 189 to 194), so a reader who types them gets the same wrong numbers. The `compare` sheet already solves this: its shared filter includes `(Institutions[grad_rate_bach_6yr]<>"")` and its note explains why (`build_workbook.R` line 535). The two lessons contradict each other on the point the compare lesson teaches.

The `missingness` sheet has the same defect on a smaller scale. `MEDIAN(IF((level="4-year")*(stu_fac_ratio=""), headcount))` (`build_workbook.R` line 173) includes the 12 four-year institutions that have neither a ratio nor a headcount as zeros, so the "Median headcount, ratio blank" cell reads 233 instead of the 242.5 the exercise reports.

Fix: multiply the condition by `(Institutions[grad_rate_bach_6yr]<>"")` in the five array formulas and by `(Institutions[headcount]<>"")` in the two median formulas, update the lesson table, and rebuild the workbook.

### 2. The reporting-year note is wrong for headcount and completions

The homepage says "Aid variables describe 2022-23; enrollment and completions describe 2023-24" (`index.qmd` line 177), and the README says "everything else describes 2023-24" (line 81). The IPEDS dictionaries disagree for two sources:

- `EFFY2023`, the source of `headcount` and `undergrad`, is the 12-month enrollment for July 1, 2022 to June 30, 2023.
- `C2023_C`, the source of the four awards columns, counts awards conferred between July 1, 2022 and June 30, 2023.

`data/variables.csv` already labels the awards columns 2022-23, so the homepage contradicts its own dictionary. The outliers lesson repeats the error: "reported `r top1_hc` students in 2023-24" (`eda-outliers.qmd` line 101) describes a 2022-23 12-month headcount.

Suggested wording: "Directory attributes, fall enrollment, and retention describe 2023-24. Financial aid, 12-month headcount, and completions describe 2022-23. Completion rates describe the cohort that entered six years earlier."

### 3. The awards columns count students, not degrees

`associates_awarded`, `bachelors_awarded`, `masters_awarded`, and `doctorates_awarded` come from `CSTOTLT` in `C2023_C`. The dictionary defines that variable as "Number of students receiving awards/degrees conferred between July 1, 2022 and June 30, 2023". A student who earns two bachelor's degrees counts once. The labels in `data/variables.csv` say "degrees awarded", and the homepage says "degrees awarded from completions".

Fix: either relabel the four columns as students receiving awards, or rebuild them from `CTOTALT` in `C2023_A`, which counts awards.

### 4. Five DAX recipes cannot run as written

A DAX measure must return a scalar. Three lessons define a measure that returns a table and then use it inside other measures:

- `Completion Rows = FILTER (...)` in `eda-compare.qmd` line 663, used by four measures and a `CALCULATETABLE`.
- `Completion Rows = FILTER ( ALL ( institutions ), ...)` in `stats-anova.qmd` line 885, used by `SS Between`, `SS Within`, and `F Statistic`.
- `Test Rows = FILTER (...)` in `ml-classify.qmd` line 925, used by the four confusion-matrix measures and `AUC`.

Power BI rejects each with "The expression refers to multiple columns". `powerbi/REVIEW.md` item 1 records this exact problem and fixes it for the regression lesson only. The regression lesson shows the working pattern: keep the filtered table in a `VAR` inside each measure. `ml-predict-rate.qmd` line 915 shows `Line Fit = LINESTX (...)` in the same standalone form; the prose after it says it belongs in a `VAR`, so that block needs the presentation changed rather than the logic.

The ANOVA block has three further problems that survive inlining the table:

- `"n", COUNTROWS ( [Completion Rows] )` inside `SUMMARIZE` uses `ALL ( institutions )`, which removes the region filter, so every region gets the full count of 1,602 instead of its own.
- `SS Within` takes each row's group mean with `ALLEXCEPT ( institutions, institutions[region] )`, which averages every institution in the region, including the 275 four-year institutions with cohorts under 30 that the frame excludes.
- `F Statistic` sets `k = DISTINCTCOUNT ( institutions[region] )`, which is 10 in an unfiltered report; the frame has 8 regions.

One smaller case: the proportions block builds its grid from `VALUES ( institutions[locale] )` and `DISTINCTCOUNT`, both of which include the 3 institutions with a blank locale. Unless the visual filters those out, the grid has a blank column and `df` is 8 instead of 6.

### 5. Two hard-coded prose numbers are wrong

- `eda-distributions.qmd` line 141, solution text: "Roughly one in four four-year institutions computes its headline completion rate on fewer than 50 students." The share is 17.8%, about one in six. The check's own feedback prints 17.8%.
- `eda-compare.qmd` line 53: "Watch the US service schools: five institutions, all above 85%." The lowest of the five is 80.6%.

Every other hard-coded figure checked was right; the list is in the Verified section.

### 6. Four R checks accept mislabeled groups

The checks for `eda1_median`, `eda2_share`, `eda3_median`, and `eda4_group` compare `sort(.result$column)` against `sort(expected$column)`. A result with the right numbers attached to the wrong groups passes. Codex confirmed it in the browser: appending `ans$level <- rev(ans$level)` to the `eda2_share` solution still returns "Correct". `eda3_median` sorts `n` and `median_rate` separately, so even the pairing between the two columns is unchecked.

The Python versions align on the index with `sort_index()`, which is the fix for R too: `dplyr::arrange` both frames by the group column, then compare the columns in order. `ml1_py_fit` is looser still and accepts any array of 0, 1, 2 labels of the right length.

### 7. The local grader fails three correct solutions

`python grade.py` reports 51 of 54 exercises correct. The three failures are `eda1_median`, `eda2_share`, and `eda3_median`, all with `could not find function "summarise"`. In the browser these pass, because the first "Do it" cell on each page is an `autorun` cell that calls `library(dplyr)` at page load (`eda-distributions.qmd` line 207, `eda-missing.qmd` line 200, `eda-compare.qmd` line 244). The exercise setup chunks use `dplyr::filter`, so they survive without it; the reference solutions use bare `group_by` and `summarise`, so they do not.

Codex saw the same three failures and attributed them to missing packages in its sandbox. On this machine the packages are installed, and the cause is that `grade.py` runs neither the autorun cells nor a `library()` call for the page's `webr: packages` list. Attach those packages in `run_r`, and the harness matches the browser. Until then, the three errors hide any real regression on those exercises.

## Layout and interaction

### 8. Lessons with unbreakable formula tables overflow on phones

At a 375 px viewport, `eda-distributions.html` lays out at 697 px and the browser scales the whole page to 54%. The widest element is the Excel table in "In your stack": its formula column is 569 px because the formulas contain no spaces and the tab pane has `overflow-x: visible`. `stats-anova.html` and `ml-forecast.html` lay out at 375 px, because their formulas contain spaces and wrap. Expect every lesson whose Excel table uses unspaced structured references (`Institutions[level]`) to behave like the distributions lesson.

Fix in `styles.scss`: give tables inside `.tab-pane` a scrolling wrapper (`display: block; overflow-x: auto`) or set `overflow-wrap: anywhere` on `td code`.

A second, separate consideration: the animations draw into an 860-unit `viewBox`. In a 324 px phone column, labels drawn at 10 to 13 units render at 4 to 5 px whatever the tables do. Options are a minimum SVG width with horizontal scroll, or larger label sizes when the container is narrow.

### 9. Animations

All 18 animations rendered with populated readouts and no console errors at desktop width, including the clustering controls (Step, Run to convergence, New starting centers, Reset). Every lesson and the homepage honor `prefers-reduced-motion`. The regression and logistic readouts open with slope 0 and R² −0.06 by design, because the reader places the line first.

### 10. One exercise prints 1,448 rows

`ml1_scale` asks for the standardized matrix and prints all 1,448 rows of it when it runs. The check needs the matrix, so either ask for `head()` of it in the prompt or keep the matrix and print `dim()` in the solution.

## Consistency and prose

### 11. Stale README text

- Line 18: "Live lessons link; planned ones are placeholders." All 18 are live.
- Line 71: "Copy one of the three lesson files." There are 18.
- Line 93: "The three lesson tabs use `powerbi-embed.json`." Every lesson has the tab.

### 12. Sheet ranges cited in the regression lesson

`stats-regression.qmd` lines 192 to 195 say "The ranges below match the sheet" and cite `E2:E1800`. The `regression` sheet has 1,648 rows, so the last row is 1649, which is the number the logistic lesson uses for the same frame. The formulas still evaluate correctly because the extra cells are empty. The split and predict-rate lessons cite exact ranges, so the regression lesson is the odd one out.

### 13. Power BI tabs map 18 lessons onto 4 report pages

`data-powerbi-page` values: `regression` 7 lessons, `overview` 5, `distributions` 4, `peers` 2. The forecast, subtotals, and proportions lessons open report pages unrelated to their method. Until `embedUrl` is set in `powerbi-embed.json`, all 18 tabs show "Interactive report: not connected yet" with a download link to `data/ir-lab-powerbi.zip`, and that file is in `.gitignore`, so a fresh clone renders a dead link.

### 14. A scikit-learn deprecation in the classification lesson

`ml-classify.qmd` lines 562, 670, and 846 call `LogisticRegression(penalty=None)`. scikit-learn deprecated `penalty` in 1.8 and removes it in 1.10; the local run already prints the warning. When Pyodide ships a version without it, three cells fail. `C=np.inf` gives the same unpenalized fit on both old and new versions.

### 15. Data facts worth a note on the homepage

- Three institutions report a negative average net price: Reid State Technical College (−187), Atlanta Technical College (−573), Trident Technical College (−1,475). The income bands have 53 more negatives. IPEDS reports them as such, and the lessons treat price as positive.
- 3 institutions have no locale, 21 no size, and 29 no headcount (13 of them four-year).
- 20 four-year institutions report a 100% six-year rate on a cohort of 5 or fewer, and 275 rates rest on cohorts under 30. The small-cohort caveat already covers this; the count would make it concrete.

## Verified and passing

- Links: 3,154 internal links and anchors, 0 broken (Codex).
- Exercise ids: 54 ids, consistent across the lesson wrappers, the homepage cards, and the track pages.
- Structure: every lesson has 4 beats, 3 exercises, a "Before you leave" section, and a "Lesson N of 6" label that matches its track order.
- Exercises: 51 of 54 pass locally; the 3 others pass in the browser (item 7). Codex also ran `eda1_median`, `eda1_py_median`, `eda2_share`, `eda2_dropped`, `eda2_py_share`, `eda3_py_median`, and the three clustering exercises in the browser, and the completion badge and progress counter updated.
- Data: 5,988 unique `unitid`. The fall enrollment detail rows sum to 19,703,000, equal to the grand-total rows for all 5,913 institutions, with 0 mismatches; summing every row gives 161,961,366. 5,064 institutions have a headcount in all 11 years with no zeros. No rate falls outside 0 to 100. No two-year institution carries a bachelor's rate. `efalevel` is unique in the codes file, as the subtotals lesson claims.
- Cross-tool constants: the logistic DAX uses 3.002 and −0.0735; R gives 3.0033 and −0.0735 on 1,648 rows. The classification DAX uses 7.111, 0.0633, −0.1343; R gives 7.1114, 0.0633, −0.1343 on 1,129 training rows. The PCA DAX means, standard deviations, and PC1 loadings match `prcomp` on 1,448 rows. The OLS reference in `powerbi/REVIEW.md` (slope −0.6707, intercept 77.8819, R² 0.3265) reproduces.
- Workbook: `data/ir-lab.xlsx` and `_site/data/ir-lab.xlsx` are identical.
- Prose figures that were right: locale medians 57.8, 58.0, 51.6, 44.6 with rural the smallest group; eta squared 5.0% for control and 12.1% for size; within-band median gaps 13.5 to 26.3 points against 7.8 overall; 83.5% of nonprofits and 36.5% of publics under 5,000 students; 64% of four-year retention blanks under 1,000 students; correlation by control 0.41, 0.54, 0.45 with nonprofits strongest; gap in medians 7.8; r 0.49; bootstrap SE 3.09; interval 50.0 to 62.5 around a population mean of 54.8; d 0.36; odds ratio 1.157 per point and 4.3 per ten; test RMSE 14.42 and cross-validated 13.33; 74.1% of variance in two components.

## Open items for consideration

1. Phone layout: scrolling tables alone, or also a minimum chart width or larger labels (item 8).
2. Power BI: connect an embed URL, or replace the per-lesson report tab with one link to the project until then; decide whether the zip should be tracked (item 13).
3. Completions: relabel as students receiving awards, or rebuild from the awards file (item 3).
4. Grading strictness: whether order-independent checks should stay order-independent but align on the group column (item 6).
5. The `penalty=None` calls (item 14).
6. Whether to add the negative net price and blank-count facts to "Things to know" (item 15).
7. `../ir-lab-audit-notes` holds Codex's scratch files (narrative excerpts and `exercise-cases.json`) and can be deleted.

## Resolution

Applied September 7, 2026, after the report above. Every item was re-verified before and after the change: `python grade.py` on all 18 lessons (54 of 54 pass), formula readback of the rebuilt workbook, a full `quarto render` with no errors, and the phone layout measured in a 375 px viewport.

| Item | Status | What changed |
| --- | --- | --- |
| 1 Distributions sheet | Fixed | The five array formulas on `distributions` and both medians on `missingness` test the aggregated column against `""`; the sheet notes say why; `eda-distributions.qmd` and `eda-missing.qmd` show the corrected formulas and the distributions lesson now states the wrong median a reader would get without the test (41.8 against 53.8). Workbook rebuilt. |
| 2 Reporting years | Fixed | Homepage, README, and the outliers lesson say directory, retention, and student-faculty ratio describe 2023-24; aid, 12-month headcount, and completions describe 2022-23. The two headcount labels in `variables.csv` carry the year. |
| 3 Awards columns | Fixed by relabeling | The four `*_awarded` labels read "Students receiving ... degrees, 2022-23" in `variables.csv`, `build_data.R`, the Power BI model descriptions, and the workbook read-me; the homepage says "students receiving degrees from completions"; the README notes the `CSTOTLT` definition. Column names are unchanged. |
| 4 DAX recipes | Fixed | Compare, ANOVA, and classification use a TRUE/FALSE calculated column plus `CALCULATE` instead of a table-valued measure. ANOVA counts `n` per region and `k` from the frame and takes within-group variance with `GROUPBY`/`CURRENTGROUP`. Predict-rate shows `LINESTX` inside a `Line Test RMSE` measure. Proportions drop blank locales from `Observed`, the grid, and `df`. |
| 5 Prose figures | Fixed | "one in six" (eda-distributions), "all above 80%" (eda-compare). |
| 6 Mislabeled groups | Fixed | `eda1_median`, `eda2_share`, `eda3_median`, `eda4_group` align on the group column with `match()`; reversed labels now fail and reordered rows still pass. `ml1_py_fit` compares the partition with the reference fit (adjusted Rand index). |
| 7 Local grader | Fixed | `grade.py` attaches the page `webr: packages:` list before each R exercise. 54 of 54. |
| 8 Phone layout | Fixed | `td code, th code { overflow-wrap: anywhere }`; charts keep a 560 px minimum width inside a sideways-scrolling box below 600 px; `#quarto-content { overflow-x: clip }` stops the invisible variable-chip tooltip from widening the homepage (it laid out at 570 px), and the data dictionary table scrolls sideways on its own below 600 px. Measured at 375 px: distributions, compare, and index all lay out at 375 px, and the distributions chart scrolls inside its panel with 9 px axis text. |
| 9 Animations | No change | Verified the subtotals and distributions readouts on the rebuilt site. |
| 10 `ml1_scale` | Fixed | The exercise asks for `head()` of the scaled matrix; the check accepts the head or the full matrix and rejects `scale(head())`. |
| 11 README | Fixed | Track-page, lesson-count, and Power BI tab sentences updated; build section lists the grader and the pre-render step. |
| 12 Regression ranges | Fixed | Ranges are computed from the frame (`E2:E1649`). |
| 13 Power BI tabs | Partly | `_quarto.yml` runs `powerbi/scripts/package_project.py` as a pre-render step, so a fresh clone builds `data/ir-lab-powerbi.zip` and the link resolves; the zip stays untracked. The 18-to-4 page mapping and the embed URL are unchanged. |
| 14 `penalty=None` | Fixed | `C=np.inf` in the three cells, with the prose updated. |
| 15 Data facts | Fixed | The homepage callout states the negative net prices, the blank counts, and the small-cohort counts, all computed at render time. |

Open items 1 to 3 and 5 to 7 in the list above are addressed as noted; item 4 (grading strictness) was resolved by aligning on the group column. The `../ir-lab-audit-notes` scratch folder was left alone.
