# Data inputs (not committed)

The raw inputs for this analysis are not stored in this repository because ACLED
and GADM both restrict redistribution. To reproduce the analysis, place the two
files below into this `data/` folder, then render `conflict-network.qmd`.

## 1. ACLED events: `data/acled_afghanistan.csv`

Source: ACLED Data Export Tool, https://acleddata.com (free account required).

Filters used for this snapshot:
- Country: Afghanistan
- Date range: 1 January 2015 to 31 December 2025
- Event types: all
- Accessed: 2026-06-04

ACLED is a living dataset updated weekly, so a later export will differ slightly
from the snapshot used here. Cite ACLED with your own access date and filters.

## 2. GADM admin-2 boundaries: `data/gadm41_AFG_shp/gadm41_AFG_2.shp`

Source: GADM version 4.1, https://gadm.org. Download the Afghanistan shapefile
and unzip it so the level-2 file sits at `data/gadm41_AFG_shp/gadm41_AFG_2.shp`.

## Licensing

ACLED data may not be redistributed and require prominent attribution, including
on any visualization. GADM is free for non-commercial use and also restricts
redistribution. The figures and the aggregated metric tables in `outputs/` are
derived products and are published with attribution; the raw inputs are not.
