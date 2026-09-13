# Saudi TRI — data and code

Data and analysis code for *"Are oil-exporting economies structurally disadvantaged
for decarbonization? Evidence from occupational transition risk in Saudi Arabia."*

## Running it

1. Install R (≥ 4.1).
2. Place `Saudi gosi 2018-22.dta` in `Data/` (see "Obtaining the data" below — it
   is too large for Git and is not in this repository).
3. Open `saudi-tri.Rproj` in RStudio and run `R/analysis.R`.

From a terminal instead:

```
cd saudi-tri
Rscript R/analysis.R
```

Paths are resolved from the project root by `here::here()`, so the script runs
from any working directory inside the project and on any machine. Missing
packages are installed on first run. `outputs/figures/` and `outputs/tables/` are
created automatically.

The region maps (6 MB) are downloaded on first run rather than redistributed
here, because the source repository is GPL-2.0 licensed. This is the script's only
network dependency.

A full run takes a few minutes, most of it reading the 891 MB `.dta`.

## Layout

```
saudi-tri.Rproj                marks the project root; sets the working directory
R/analysis.R                   the analysis script
Data/                          the inputs the script reads
outputs/figures/               figures, regenerated on every run
outputs/tables/                Table 2's values, regenerated on every run
```

## Data

Full provenance — source, vintage, licence and known gaps — is in
[`DATA_PROVENANCE.md`](DATA_PROVENANCE.md).

| File | Source | In Git? |
|---|---|---|
| `Data/Saudi gosi 2018-22.dta` | GOSI administrative employment records, 2018–2022 | **No** — storage TBD |
| `Data/saudi_emission_intensity_and_greenjob_potential.xlsx` | IMF emission intensity (sheet 1); Rutzer et al. green potential (sheet 3) | Yes |
| `Data/saudi_unemp_19_22_q4_orig.xlsx` | Saudi LFS regional unemployment, 2019Q4 / 2022Q4 (sheet 3) | Yes |
| `Data/ISCO.xlsx` | ISCO-08 code → label lookup (sheet `ISCO_08`) | Yes |
| `Data/saudi_geo/regions.geojson` | Region maps, from `homaily/Saudi-Arabia-Regions-Cities-and-Districts` | **No** — downloaded on first run |

### Obtaining the data

The GOSI microdata file is 891 MB and is not in this repository. Where it will be
stored is to be decided.

## Outputs

`outputs/` contains exactly the exhibits that appear in the manuscript and
nothing else. The script computes the numbers behind each figure but writes out
only the figures themselves and Table 2's values.

| Manuscript | File |
|---|---|
| Figure 3 — TRI distribution, 2019 & 2022 | `figures/01_index_baseline.png` |
| Figure 4 — TRI by region, 2022 | `figures/02_tri_map_2022.png` |
| Figure 5 — TRI by jobs, region & gender | `figures/03_TRI_index_map_gender.png` |
| Figure A1 — sector-heavy | `figures/04_index_sector_heavy.png`, `figures/04_tri_map_2022_sector_heavy.png` |
| Figure A2 — region-heavy | `figures/05_index_region_heavy.png`, `figures/05_tri_map_2022_region_heavy.png` |
| Figure A3 — occupation-heavy | `figures/06_index_occ_heavy.png`, `figures/06_tri_map_2022_occ_heavy.png` |
| Table 2 — underlying values | `tables/tri_illustration_tables.xlsx` |

Table 2 reproduces exactly: all 54 cells and all 9 row labels of
`tables/tri_illustration_tables.xlsx` match the published table.

The script also reports, to the console, every number the manuscript quotes
outside a figure: the national TRI means (§4.1), the gender means (§4.3), the
sample sizes before and after exclusions (footnote 4), the arithmetic-mean
robustness check (footnote 1), and the gender significance tests (footnote 7).

**Figures 1 and 2 are not here.** Both are Excel charts, not R output — Figure 1
is sourced from GAStat, Figure 2 is SSCO major group by gender. They come from a
co-author and will be added separately; no script in this repository produces them.
