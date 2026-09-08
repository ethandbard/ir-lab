# IR Lab

A practice site for exploratory data analysis, statistics, and machine learning on higher-education data. Every lesson works one method on IPEDS data, mostly the 2023-24 institution table, with four fixed beats: an animation with controls, R and Python cells that run in the browser, graded exercises, and the same method in Excel formulas and Power BI DAX.

## How it runs

- **Quarto website** with the [quarto-live](https://github.com/r-wasm/quarto-live) extension. R cells run through webR and Python cells through Pyodide, both in the visitor's browser. No server, no install for the reader.
- **Observable JS** (built into Quarto) draws the animations with D3.
- **Pre-rendered R** (knitr) only fills in prose numbers and the variable chips. It runs at build time.
- Progress is kept in the browser's localStorage by `lab.js`.

## Layout

| Path | What it is |
| --- | --- |
| `_quarto.yml` | Site config. Format is `live-html`; per-page `webr:` and `pyodide:` blocks list packages and data files. |
| `index.qmd` | Home: institution swarm, track cards, data dictionary. |
| `eda.qmd`, `stats.qmd`, `ml.qmd` | Track pages listing the six lessons of each track with a completion count. |
| `eda-distributions.qmd` | Explore, lesson 1: histograms and skew. |
| `eda-missing.qmd` | Explore, lesson 2: missingness patterns and complete-case bias. |
| `eda-compare.qmd` | Explore, lesson 3: boxplots, small multiples, and variance explained by a grouping. |
| `eda-relationships.qmd` | Explore, lesson 4: scatterplots, Pearson and Spearman correlation, association versus cause. |
| `eda-outliers.qmd` | Explore, lesson 5: IQR fences, robust z-scores, leverage, Cook's distance, and what to do about outliers. |
| `eda-subtotals.qmd` | Explore, lesson 6: IPEDS EFALEVEL, LINE, and SECTION codes, double counting, and building a clean grain. |
| `stats-sampling.qmd` | Test, lesson 1: bootstrap and confidence intervals. |
| `stats-two-groups.qmd` | Test, lesson 2: Welch's t-test, Cohen's d, and power. |
| `stats-anova.qmd` | Test, lesson 3: one-way ANOVA, eta squared, Tukey HSD, and multiple-comparison corrections. |
| `stats-proportions.qmd` | Test, lesson 4: contingency tables, chi-square, Cramér's V, Wilson intervals, two proportions, and Fisher's exact test. |
| `stats-regression.qmd` | Test, lesson 5: simple linear regression. |
| `stats-logistic.qmd` | Test, lesson 6: logistic regression and odds ratios. |
| `ml-split.qmd` | Model, lesson 1: train/test splits, cross-validation, and leakage. |
| `ml-predict-rate.qmd` | Model, lesson 2: lasso, regression trees, and random forests on held-out data. |
| `ml-classify.qmd` | Model, lesson 3: classification, thresholds, the confusion matrix, ROC and AUC, and calibration. |
| `ml-clustering.qmd` | Model, lesson 4: k-means peer groups. |
| `ml-pca.qmd` | Model, lesson 5: principal components. |
| `ml-forecast.qmd` | Model, lesson 6: one-year enrollment forecasts scored with rolling origins, error by size, and empirical intervals. |
| `fetch_history.R` | Downloads the fall enrollment files EF2013A to EF2022A into `../ipeds/data/raw`. |
| `build_data.R` | Builds `data/` from `../ipeds/data/raw`. |
| `build_workbook.R` | Builds `data/ir-lab.xlsx` with one worked sheet per lesson. Called by `build_data.R`. |
| `_common.R` | Helpers for pre-rendered parts: `v()` variable chips, `fmt()`. |
| `grade.py` | Local grader harness: runs each exercise's setup, solution, and check outside the browser. |
| `styles.scss`, `header.html`, `lab.js` | Theme, web fonts, progress tracking. |
| `data/institutions.csv` | One row per institution, 44 columns. |
| `data/variables.csv` | Column dictionary with IPEDS sources. |
| `data/fall_enrollment_2023.csv` | The 2023 fall enrollment file as shipped: one row per institution and EFALEVEL code, with LINE, SECTION, LSTUDY, and the headcount. |
| `data/fall_enrollment_codes.csv` | The 27 code combinations with their meaning and whether each is a detail line, a subtotal, or the grand total. |
| `data/enrollment_history.csv` | One row per institution and fall term, 2013 to 2023: total, undergraduate, and first-time headcount. |

## Build

`build_data.R` needs the raw IPEDS 2023 files in `../ipeds/data/raw` plus the fall enrollment files for 2013 to 2022, which `fetch_history.R` downloads from NCES (about 65 MB zipped). Without them, `build_workbook.R` can still be run on its own against the CSVs in `data/` (it needs the openxlsx package):

```sh
Rscript -e 'source("build_workbook.R"); i <- read.csv("data/institutions.csv", na.strings = c("", "NA")); v <- read.csv("data/variables.csv"); build_workbook(i, v, "data/ir-lab.xlsx")'
```

The pre-rendered numbers in `ml-predict-rate.qmd` and `ml-classify.qmd` need rpart, glmnet, and randomForest installed locally; `setup.R` installs them.

```sh
Rscript setup.R          # once: installs build packages
Rscript fetch_history.R  # once: downloads EF2013A to EF2022A
Rscript build_data.R     # rebuild data/ from the raw IPEDS files
quarto render            # builds _site/ (runs powerbi/scripts/package_project.py first, so Python is needed)
quarto preview           # local preview with live reload
python grade.py *.qmd    # grade every exercise's solution through its own check
```

The first visit to a lesson downloads webR or Pyodide plus packages, which takes several seconds. Later visits are cached by the browser.

## Adding a lesson

1. Copy an existing lesson file and keep the four `## ... {.beat data-beat="..."}` headings.
2. Give every exercise a unique id used in three places: `#| exercise:`, the `.hint`/`.solution` divs, and the `.lab-exercise` wrapper's `data-exercise`.
3. Add the exercise ids to the track card on `index.qmd` and the track page's `.lab-progress` element so completion counts include them.
4. Link the lesson from its track page and change its status to Live.
5. Run `python grade.py <lesson>.qmd` to grade every exercise's solution through its own check locally (needs Rscript on the path, or edit the path at the top of the script).

## Data notes

- Rates at institutions with small cohorts are noisy. `bach_cohort` and `grad_cohort` are in the table so lessons can filter.
- Net price is in-state for public institutions and a single figure for privates.
- The surveys describe different years. Directory attributes, retention, and the student-faculty ratio describe 2023-24; financial aid, the 12-month headcount, and completions describe 2022-23; completion rates describe cohorts that entered six years earlier.
- The four `*_awarded` columns count students receiving an award at that level (IPEDS `CSTOTLT`), not awards. A student who earns two bachelor's degrees counts once.
- Missing values are blank, never zero.
- `fall_enrollment_2023.csv` keeps every subtotal row on purpose; the codes file marks the ten detail lines that add to the reported total.
- `enrollment_history.csv` covers institutions in the 2023-24 directory only, so it is the survivors' history; 5,064 institutions have a headcount in all eleven years.

## Power BI project and lesson embeds

Open `powerbi/IR Lab.pbip` in Power BI Desktop. The project includes overview,
completion distribution, Pell regression, and peer-group pages based on the same CSV.
See [powerbi/README.md](powerbi/README.md) for import, refresh, publication, and embed setup;
see [powerbi/REVIEW.md](powerbi/REVIEW.md) for the project review and metric contracts.

Every lesson's Power BI tab uses `powerbi-embed.json` and `powerbi-embed.js`. An empty embed URL
shows a download link to `data/ir-lab-powerbi.zip`, which `powerbi/scripts/package_project.py`
builds from the tracked project as a Quarto pre-render step (the zip itself is not tracked).
After publication, paste the **Website or portal** URL into `embedUrl` and render the site.
Each lesson opens its mapped report page; the report has four pages, so several lessons
share one. Report loading is opt-in; Microsoft handles sign-in and report access.
