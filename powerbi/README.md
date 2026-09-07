# IR Lab Power BI project

Four native report pages extend the existing IPEDS lessons. The source model imports
the same 5,988-institution extract used by R, Python, and Excel. No Microsoft account
credentials or service identifiers are saved in this project.

## Open and refresh

1. Open **IR Lab.pbip** in the current Power BI Desktop. Enable the Power BI Project
   and enhanced report format (PBIR) preview options if Desktop requests them.
2. In **Transform data → Manage parameters**, set `ProjectRoot` to the IR Lab root
   folder containing `data/` and `powerbi/`. This machine's default is
   `C:/Users/ethan/Code/Data Science/ir-lab`. Use forward slashes, without a trailing slash.
3. Choose **Refresh**, then check the four report pages. PBIP stores definitions;
   the data cache is created locally during refresh.
4. Compare the initial, unfiltered cards with `validation/source-checks.json`.

The semantic model uses TMDL; report visuals use PBIR. Microsoft's installed Power BI
Modeling MCP successfully parsed the model offline (2 tables, 20 measures, 94 columns).
The generated `validation/model-definition.json` is an audit representation, not an
additional active model. The two tables are intentionally unrelated:
`institutions` powers overview/distributions/regression, and the frozen `peers` snapshot
powers the peer page. Filters are page-local. Cross-page slicer synchronization is not enabled.

## Report pages

| Page | Internal page name | Site destination |
| --- | --- | --- |
| Institution overview | ReportSectionOverview | Available for a future home/data embed |
| Completion distributions | ReportSectionDistributions | eda-distributions.qmd, Power BI tab |
| Pell and completion | ReportSectionRegression | stats-regression.qmd, Power BI tab |
| Peer groups | ReportSectionPeers | ml-clustering.qmd, Power BI tab |

The report uses standard cards, slicers, bars, scatterplots, and tables. It requires
no custom visuals, R visuals, Python visuals, or browser-side access tokens.

## Connect the lesson embeds

1. Publish the refreshed report from Desktop to your chosen Power BI workspace.
2. Open it in Power BI Service and select **File → Embed report → Website or portal**.
3. Copy the URL into `embedUrl` in the site's `powerbi-embed.json`. Keep the four page
   mappings; if Service changes the internal names, update those mappings from its URLs.
4. Grant viewers access to the report and the required Power BI license or capacity.
5. Run `quarto render` and deploy the site's `_site/` output using your normal process.

The site initially shows an accessible download fallback. Once configured, it offers
a load button and a new-tab link. Clicking loads Microsoft Power BI and may require
sign-in and pop-ups. Host the finished site over HTTPS. Microsoft controls authentication
inside the iframe; the host cannot inspect whether a viewer signed in successfully.

This integration uses authenticated **Website or portal** embedding. If the teaching
site needs anonymous access, choose a public publication strategy explicitly: Power BI
**Publish to web** makes the report and underlying model data public, whereas an
app-owns-data solution needs a server-side token service and appropriate capacity.
The current loader deliberately accepts only secure `app.powerbi.com/reportEmbed` URLs.

## Updating data and maintaining the report

From the IR Lab directory:

```powershell
Rscript build_data.R
Rscript powerbi/scripts/build_peers.R
python powerbi/scripts/build_project.py
python powerbi/scripts/package_project.py
```

Then refresh and publish in Power BI Desktop. For a different installation path, use
`python powerbi/scripts/build_project.py --project-root C:/path/to/ir-lab`.

`build_project.py` regenerates **all authored model and report definitions**. It is useful
while developing this starter; once you edit visuals in Desktop, preserve those changes
and update the CSV/peer extract plus Refresh instead of regenerating the report.
Repackage the download after saving changes. Never include `.pbi/` caches or credentials.

The peer snapshot follows the worked R example: sample-standardized five features,
seed 2023, k=4, nstart=25. Slicers filter saved memberships; they do not refit. Rebuild
peers whenever the source changes because the standardization population may change.
`build_project.py` checks membership eligibility and all five feature values against the
current institution extract. `data/scaling.csv` and `data/peer-profiles.csv` document the fit.

Local CSV imports require an on-premises data gateway for scheduled Service refresh.
For this fixed teaching snapshot, manual Desktop refresh and republish is a reasonable
starting workflow. Moving imports to a durable hosted source is a separate deployment step.

## Verification

- `validation/source-checks.json`: source hash, row counts, missingness, regression
  reference values, and histogram counts. Source modification time is file metadata,
  not a claim about the collection's publication date.
- `validation/report-checks.json`: Microsoft schema checks, model field references,
  visual canvas bounds, and embed page mappings.
- `node powerbi/scripts/test_embed.cjs`: URL validation, unset state, page mapping,
  and removal of token-like query parameters.
- Power BI Desktop refresh, visual rendering, and authenticated Service embedding
  must be checked separately; passing JSON schemas does not execute DAX or Power Query.

## Microsoft references

- [Power BI projects](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview)
- [Semantic model folder and TMSL](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset)
- [PBIR format](https://learn.microsoft.com/en-us/power-bi/developer/embedded/projects-enhanced-report-format)
- [Secure website embedding, page names, licensing, and HTTPS](https://learn.microsoft.com/en-us/power-bi/collaborate-share/service-embed-secure)
- [LINESTX](https://learn.microsoft.com/en-us/dax/linestx-function-dax)
