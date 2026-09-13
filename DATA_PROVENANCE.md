# Data provenance

Every input to `R/analysis.R`: where it came from, what vintage it is, and what
the script does with it.

---

## Summary

| File | Pillar | Source | Vintage |
|---|---|---|---|
| `Saudi gosi 2018-22.dta` | employment weights | GOSI via Saudi National Labor Observatory (storage TBD) | 2019 & 2022 year-end |
| `saudi_emission_intensity_and_greenjob_potential.xlsx` (sheet 1) | sector carbon exposure | IMF Climate Change Indicators Dashboard | 2018 |
| `saudi_emission_intensity_and_greenjob_potential.xlsx` (sheet 3) | occupational adaptability | Rutzer, Niggli & Weder (2020) | n/a (task-based) |
| `saudi_unemp_19_22_q4_orig.xlsx` (sheet 3) | regional labour frictions | GASTAT Labour Force Survey | 2019Q4, 2022Q4 |
| `ISCO.xlsx` (sheet `ISCO_08`) | occupation labels | ILO ISCO-08 | ISCO-08 |
| `saudi_geo/regions.geojson` | region maps | `homaily/Saudi-Arabia-Regions-Cities-and-Districts` (downloaded on first run) | — |

---

## 1. GOSI employment microdata

- **File** `Data/Saudi gosi 2018-22.dta` (891 MB, not in this repository)
- **Source** General Organization for Social Insurance (GOSI), obtained via Saudi
  Arabia's National Labor Observatory (NLO).
- **Coverage** Private-sector employment. Occupation at 4-digit SSCO, economic
  activity at ISIC Rev. 4, plus gender, age, region and wages. Records are
  aggregated across individuals identical on all reported variables, with wages
  averaged.
- **Vintage** Filtered by the script to the 2019-12-31 and 2022-12-31 snapshots.
- **Used for** `numberofemployees`, the frequency weight behind every aggregate in
  the paper, and the ISCO3 × sector × region × gender cell structure.
- **Storage** To be decided; the file is not in this repository.
- **Manuscript citation** Described in §3.2; no formal data citation at present.

## 2. Sector emission intensity — IMF

- **File** `Data/saudi_emission_intensity_and_greenjob_potential.xlsx`, sheet 1
  (`Emission intensity SAUDI`), columns 12 (`economicactivity_en`) and 37 (`y2018`)
- **Source** IMF Climate Change Indicators Dashboard,
  <https://climatedata.imf.org/> — series **`ECNI`, "CO2 Emissions Intensities"**
  (full descriptor: *Environment, Climate Change, Economic Activity, CO2 Emissions
  Intensities*).
- **Unit** Metric tons of CO₂ per $1 million USD of output. This is the `tCO₂/$M`
  that appears in Table 2's bracketed values.
- **Vintage** 2018. The workbook carries a single year column, `y2018`; the script
  comment notes this was the most recent year available at the time.
- **Granularity** 44 industry rows, mapped in the workbook to 19 GOSI
  `economicactivity_en` values.
- **Transformation in script** The 44 industry rows are averaged to the 19 GOSI
  activities, then logged and min–max normalised across sectors to give
  `sector.score` ∈ [0, 1] (line 90 floors Real estate activities at 0.001 so the
  geometric mean stays defined).
- **Manuscript citation** Described in §3.1 and Appendix A.

## 3. Occupational green potential — Rutzer et al.

- **File** same workbook, sheet 3 (`Green potential scores (ISCO)`), columns 4–6
  from row 4: `ISCO3`, `minorgroup_description`, `Estimated Green Potential`
- **Source** Rutzer, C., Niggli, M., & Weder, R. (2020), *Estimating the green
  potential of occupations*; see also Niggli & Rutzer (2020).
- **Vintage** Not time-indexed — derived from occupational task content, so
  invariant across countries and years.
- **Transformation in script** Used as supplied. Enters the index inverted, as
  `1 - occupation.score`, so higher means less adaptable.
- **Manuscript citation** Present and correct (§3.1, Appendix A).

## 4. Regional unemployment — GASTAT

- **File** `Data/saudi_unemp_19_22_q4_orig.xlsx`, sheet 3 (`combined`)
- **Columns** `year`, `region_en`, `gender`, `rate`, `unemp.score` — 52 rows
  (13 regions × 2 genders × 2 years)
- **Source** Saudi General Authority for Statistics (GASTAT), Labour Force Survey.
- **Vintage** 2019Q4 and 2022Q4.
- **Normalisation** The script rebuilds `unemp.score` from the raw `rate`: a
  min–max rescaling **within each year × gender group** (13 regions per group).
  The workbook also ships a pre-computed `unemp.score`; the script asserts the two
  agree before using its own, so the column now serves as a cross-check rather
  than as an input. The two are identical bit-for-bit across all 52 rows.

  | year | gender | rate range | score range |
  |---|---|---|---|
  | 2019 | Female | 0.00 – 50.80 | 0 – 1 |
  | 2019 | Male | 2.07 – 17.50 | 0 – 1 |
  | 2022 | Female | 13.58 – 23.16 | 0 – 1 |
  | 2022 | Male | 2.99 – 8.25 | 0 – 1 |

  Zero scores are then lifted to 0.001 so the geometric mean stays defined. The
  `2019` and `2022` sheets in the same workbook hold the pre-combination data.
- **Manuscript citation** GASTAT is cited generally; the specific LFS table behind
  these rates is not identified.

## 5. ISCO-08 classification

- **File** `Data/ISCO.xlsx`, sheet `ISCO_08`
- **Columns** `major`, `major_label`, `sub_major`, `sub_major_label`, `minor`,
  `minor_label`, `unit`, `description`
- **Source** International Labour Organization, ISCO-08. The workbook also holds
  ISCO-88, ISCO-68, ISCO-58 and a skills sheet; the script reads only `ISCO_08`.
- **Used for** `ISCO3_label`, the occupation names in Table 2. Not used in any
  calculation — labels only.
- **Manuscript citation** SSCO/ISCO correspondence discussed in footnote 3.

## 6. Region boundaries

- **File** `Data/saudi_geo/regions.geojson`
- **Source** GitHub repository `homaily/Saudi-Arabia-Regions-Cities-and-Districts`
- **Licence** GNU GPL v2.0. The file is not redistributed here; the script
  downloads it on first run.
- **Used for** the region maps: Figure 4, Figure 5, and the Figure A1–A3 maps.
- **Manuscript citation** Missing — not cited anywhere in the draft.
