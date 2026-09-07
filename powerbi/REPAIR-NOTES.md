# Desktop repair — September 5, 2026

IR Lab was repaired, refreshed, visually checked on all four pages, and saved in Power BI Desktop.

- Corrected all 20 measure expressions: the generator had placed `formatString` at the DAX indentation level. Fixed the generator and the existing TMDL while preserving model lineage identifiers.
- Repaired garbled punctuation in labels, descriptions, and completion bins.
- Corrected the custom-theme resource reference, restored the theme, increased heading contrast, and removed duplicate card and slicer labels.
- Converted the bachelor cohort slicer to a numeric Between range. Verified its statistics update and restored the full range.
- Verified peer Group 1 filters cards, charts, and profiles to 388 institutions, then restored all four groups.
- Refreshed both local CSV imports and evaluated every measure. Institution counts, completion statistics, and OLS results agree with the source validation manifest within 1e-9.

Detailed results: `validation/desktop-repair-checks.json`. Older validation files describe the initial generated project; this record captures the subsequent live Desktop verification.

Backup before repair: `../powerbi-backup-20260905-before-repair/`.

Data remains the existing IPEDS cross-sectional extract and fixed R peer-group snapshot. This repair did not obtain a newer data release or publish to the Power BI service.

The TMDL repair follows Microsoft's expression indentation rules:
https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview
