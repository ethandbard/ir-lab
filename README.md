# IR Lab

A practice site for exploratory data analysis, statistics, and machine learning on higher-education data. Every lesson works one method on the IPEDS 2023-24 institution table with four fixed beats: an animation with controls, R and Python cells that run in the browser, graded exercises, and the same method in Excel formulas and Power BI DAX.

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
| `eda.qmd`, `stats.qmd`, `ml.qmd` | Track pages listing lessons. Live lessons link; planned ones are placeholders. |
| `eda-distributions.qmd` | Explore, lesson 1: histograms and skew. |
| `stats-regression.qmd` | Test, lesson 5: simple linear regression. |
| `ml-clustering.qmd` | Model, lesson 4: k-means peer groups. |
| `build_data.R` | Builds `data/` from `../ipeds/data/raw`. |
| `build_workbook.R` | Builds `data/ir-lab.xlsx` with one worked sheet per lesson. Called by `build_data.R`. |
| `_common.R` | Helpers for pre-rendered parts: `v()` variable chips, `fmt()`. |
| `styles.scss`, `header.html`, `lab.js` | Theme, web fonts, progress tracking. |
| `data/institutions.csv` | One row per institution, 44 columns. |
| `data/variables.csv` | Column dictionary with IPEDS sources. |

## Build

R is not on PATH on this machine; see the memory note on toolchain paths.

```sh
Rscript setup.R          # once: installs build packages
Rscript build_data.R     # rebuild data/ from the raw IPEDS files
quarto render            # builds _site/
quarto preview           # local preview with live reload
```

The first visit to a lesson downloads webR or Pyodide plus packages, which takes several seconds. Later visits are cached by the browser.

## Adding a lesson

1. Copy one of the three lesson files and keep the four `## ... {.beat data-beat="..."}` headings.
2. Give every exercise a unique id used in three places: `#| exercise:`, the `.hint`/`.solution` divs, and the `.lab-exercise` wrapper's `data-exercise`.
3. Add the exercise ids to the track card on `index.qmd` and the track page's `.lab-progress` element so completion counts include them.
4. Link the lesson from its track page and change its status to Live.

## Data notes

- Rates at institutions with small cohorts are noisy. `bach_cohort` and `grad_cohort` are in the table so lessons can filter.
- Net price is in-state for public institutions and a single figure for privates.
- Financial aid variables describe 2022-23; everything else describes 2023-24.
- Missing values are blank, never zero.

## Power BI project and lesson embeds

Open `powerbi/IR Lab.pbip` in Power BI Desktop. The project includes overview,
completion distribution, Pell regression, and peer-group pages based on the same CSV.
See [powerbi/README.md](powerbi/README.md) for import, refresh, publication, and embed setup;
see [powerbi/REVIEW.md](powerbi/REVIEW.md) for the project review and metric contracts.

The three lesson tabs use `powerbi-embed.json` and `powerbi-embed.js`. An empty embed URL
shows a download link. After publication, paste the **Website or portal** URL into
`embedUrl` and render the site. Each lesson opens its mapped report page. Report loading
is opt-in; Microsoft handles sign-in and report access.
