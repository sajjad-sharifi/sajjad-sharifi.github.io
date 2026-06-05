# Project 1 Documentation: ACLED Conflict Hotspot Atlas, Afghanistan 2017 to 2025

A complete account of how this project was built, what we decided and why, what slowed us down, and the patterns that should carry forward to Projects 2 through 5.

Live deliverable: https://sajjad-sharifi.github.io/projects/acled-afghanistan/  
Source: `projects/acled-afghanistan/` under the main portfolio repo.  
Built over five working sessions in late May 2026.

---

## 1. Overview

### 1.1 What this is

Project 1 of five planned R-based spatial analytics projects, targeting the WBG Fragility Forum in Washington DC, June 2026. The project answers: where in Afghanistan has political violence concentrated between 2017 and 2025, where is it intensifying, and how did the August 2021 regime change reshape the spatial pattern?

The substantive findings, in three sentences:

1. The conflict footprint after August 2021 is not a smaller version of the pre-2021 one, it is structurally different in volume, geography, and category. Battles fell from 62% to 30% of events, violence against civilians rose from 4% to 34%, and the southern Pashtun war belt that dominated the insurgency collapsed almost entirely.

2. The only statistically clustered conflict region remaining in the country is the Panjshir-Andarab resistance belt. Six adjacent districts that were minor conflict areas before 2021 are now front-line zones of the National Resistance Front. Kabul has the highest absolute event count nationally but does not pass Getis-Ord Gi* clustering tests, its violence is a point phenomenon without spatial spread.

3. ARIMA forecasts find no trend signal in the post-2021 data and project the current ~120 events per month nationally as a stable equilibrium through mid-2027. Anything dramatically different would require a shock that the time series cannot anticipate.

### 1.2 What's in the document

The portfolio page contains six analytical sections, in order:

- District-level choropleth, events per district, pre and post August 2021
- Top-20 district ranking tables for each period
- Event type composition breakdown
- Kernel density estimate (KDE) continuous surface
- Getis-Ord Gi* statistical hotspot test with FDR correction
- ARIMA forecasts for three series (national total, Kabul, Panjsher)

Each section has prose, a code chunk, and an analytical interpretation.

### 1.3 Inputs

- ACLED political violence events: 68,034 records for Afghanistan, January 2017 to May 2025
- GADM v4.1 administrative boundaries: 328 admin-2 districts (Afghanistan)
- Tools: R 4.5.2 on aarch64-apple-darwin, renv 1.2.3, Quarto 1.9.38
- Key R packages: sf, dplyr, lubridate, ggplot2, tmap, spatstat, spdep, forecast, acledR, geodata

---

## 2. Project Setup, the Reusable Pattern

This is the part to copy verbatim for Projects 2 through 5.

### 2.1 Folder structure

```
projects/<project-name>/
├── R/                          # R scripts (we ended up using .qmd chunks instead)
├── data/
│   ├── raw/                    # downloaded sources, gitignored
│   └── processed/              # cleaned intermediates, gitignored
├── output/
│   ├── figures/                # saved plots, .png files
│   └── maps/                   # interactive HTML maps
├── docs/                       # methodology notes (this file lives here)
├── renv/                       # R package library, gitignored except lockfile
├── .gitignore
├── .Renviron                   # credentials, gitignored
├── .Rprofile                   # auto-created by renv
├── <project-name>.Rproj        # auto-created by RStudio
├── index.qmd                   # the analytical document
└── renv.lock                   # locked package versions, committed
```

### 2.2 The .gitignore at project level

```gitignore
# Data, never commit
data/raw/*
data/processed/*
!data/raw/.gitkeep
!data/processed/.gitkeep

# R project artifacts
.Rproj.user/
.Rhistory
.RData
.Ruserdata

# renv, keep lockfile but not the library
renv/library/
renv/local/
renv/cellar/
renv/staging/
renv/python/

# Outputs too large for Git
output/maps/*.html
*.tif
*.tiff

# Secrets
.Renviron
.env

# OS junk
.DS_Store
```

The `.gitkeep` files inside `data/raw/` and `data/processed/` exist so the empty folders track in Git. Touch them after creating the folders.

### 2.3 R project with renv

From R inside the project folder:

```r
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
renv::init(bare = TRUE)
# answer y when prompted about consent
```

After init, restart the R session so renv activates. Then install packages and snapshot:

```r
install.packages(c("acledR", "sf", "dplyr", "lubridate", "readr",
                   "here", "janitor", "ggplot2", "tmap"))
renv::snapshot(type = "all")
# answer y when prompted
```

Why `type = "all"`: renv's default `implicit` mode only locks packages that appear in `library()` calls in your code. At init time, before any code exists, this returns nothing. `type = "all"` locks everything installed in the project library, which is what we actually want.

For Projects 2 to 5, add the project-specific packages to the install list:

- Project 2 (Mexico Fragility Index): `FactoMineR`, `factoextra`, `psych`, plus base spatial stack
- Project 3 (Climate-Conflict, Central America): `terra`, `SPEI`, `lme4`, optionally `INLA`
- Project 4 (Displacement flows, Central America): `igraph`, `ggraph`, `gganimate`
- Project 5 (Walking-time accessibility): `osmdata`, `sfnetworks`, `dodgr`

### 2.4 .Renviron for credentials

Format:
```
ACLED_API_EMAIL=your.email@northeastern.edu
ACLED_API_PASSWORD=your_real_password
```

`chmod 600 .Renviron` after creation, restricts read access to owner only. Already in `.gitignore`.

**Known issue, unsolved:** In Project 1 the .Renviron file was never read successfully by R, even after multiple edits via nano, VS Code, and direct shell heredoc. We worked around it using interactive credential entry:

```r
Sys.setenv(ACLED_API_EMAIL = "your.email@northeastern.edu")
Sys.setenv(ACLED_API_PASSWORD = rstudioapi::askForPassword("Enter password"))
```

The `askForPassword()` popup is secure (no console echo, no history) but inconvenient since it runs every session. Worth diagnosing properly in Project 2:

1. Check encoding: `file .Renviron` should report `ASCII text` or `UTF-8`, not `UTF-8 with BOM` or `ISO-8859`.
2. Check for trailing newline: `tail -c 1 .Renviron | xxd` should show `0a` (LF).
3. Check for spaces around `=`: there should be none.
4. Check file permissions: `ls -la .Renviron` should show `-rw-------` (mode 600).
5. Test with `readRenviron(".Renviron")` then `Sys.getenv("ACLED_API_EMAIL")`.

### 2.5 RStudio project file

Create the `.Rproj` once: File > New Project > Existing Directory, point at the project folder. RStudio creates `<project-name>.Rproj` and reopens with the project active. This makes the project re-openable via "Recent Projects" and ensures renv activates cleanly.

### 2.6 Integration with the parent Quarto site

The parent portfolio site at `~/UrbanProjects/sajjad-sharifi.github.io/` is a Quarto website project, with `_quarto.yml` at the root defining navbar, theme, and footer. Sub-projects in `projects/<name>/` inherit those settings automatically, IF the page YAML does not override them.

**Critical:** do not put a `format: html: ...` block in your page YAML. It breaks navbar inheritance. The minimal safe YAML for a sub-project page is:

```yaml
---
title: "Your project title"
author: "Sajjad Sharifi"
date: today
toc: true
toc-depth: 3
code-fold: true
code-summary: "Show code"
execute:
  warning: false
  message: false
---
```

Page-specific format options (`toc`, `code-fold`) go at top level. Site-wide format options (theme, CSS, code-copy) stay in the parent `_quarto.yml`. They merge correctly only when the page does not define its own `format:` block.

---

## 3. Data Acquisition

### 3.1 ACLED, the modern OAuth flow

ACLED retired API key authentication in September 2025. The current system uses myACLED email and password credentials with OAuth tokens, handled by the official `acledR` package.

Steps:

1. Register at https://acleddata.com/register/ using an institutional email (Northeastern, in our case). Institutional emails automatically get Research-tier access, which is the API-eligible level.
2. Confirm the account, log into myACLED at least once to verify the credentials work on the website. This is the diagnostic check that distinguishes "the password is wrong" from "the API is rejecting me for some other reason."
3. Install the `acledR` package from CRAN. It depends on `httr2` and internally handles the OAuth token handshake.

The API call for Project 1:

```r
library(acledR)
library(dplyr)
library(readr)
library(here)
library(janitor)

afg <- acled_api(
  email         = Sys.getenv("ACLED_API_EMAIL"),
  password      = Sys.getenv("ACLED_API_PASSWORD"),
  country       = "Afghanistan",
  start_date    = "2015-01-01",
  end_date      = "2025-12-31",
  inter_numeric = TRUE
) |>
  clean_names()

saveRDS(afg, here("data", "raw", "afg_acled_2015_2025.rds"))
write_csv(afg, here("data", "raw", "afg_acled_2015_2025.csv"))
```

A few things to know:

- ACLED returns data only for the date range it actually covers. For Afghanistan, coverage starts January 2017, so requesting from 2015 still returns 2017 onwards. Always validate your actual date range against your request, especially for countries with later coverage starts.
- The 68,034-event return for an eleven-year request completed in one call without pagination. For larger requests (e.g., all of Latin America for ten years), the `acledR` package handles it but you may want to chunk by year to avoid timeouts.
- The standard ACLED schema returns 31 columns. Key fields for spatial analysis: `event_date`, `event_type`, `sub_event_type`, `actor1`, `actor2`, `admin1`, `admin2`, `latitude`, `longitude`, `fatalities`.

### 3.2 GADM administrative boundaries

The `geodata` R package wraps GADM downloads cleanly:

```r
library(geodata)
library(sf)

afg_adm2 <- gadm(
  country = "AFG",
  level   = 2,
  path    = here("data", "raw")
) |>
  st_as_sf()
```

GADM v4.1 returned 328 districts for Afghanistan at admin-2. Country ISO3 codes are the input (`AFG`, `MEX`, `HND`, etc.). Level 0 is country, 1 is province/state, 2 is district/municipality, 3 is sub-district where available.

The `path` argument caches the download. Subsequent renders read from cache instead of re-downloading.

The `gadm()` function returns a `SpatVector` (from `terra`); `st_as_sf()` converts to the more widely-used `sf` format.

### 3.3 Validation routine

Always run a sanity check before analysis. The pattern we used:

```r
cat("Total events:", nrow(afg), "\n")
cat("Date range:",
    as.character(min(as.Date(afg$event_date))),
    "to",
    as.character(max(as.Date(afg$event_date))), "\n")
cat("Distinct provinces:", length(unique(afg$admin1)), "\n")

# Check missing coordinates
cat("Events with no lat/lng:",
    sum(is.na(afg$latitude) | is.na(afg$longitude)), "\n")

# Event type breakdown
afg |> count(event_type, sort = TRUE) |> print()
```

What you are looking for: total events in a plausible range for the country, the requested date range matches what came back, distinct admin1 count matches the official province count for that country (34 for Afghanistan), very few NAs on coordinates.

For Project 2 (Mexico), the validation should add: distinct admin2 count matches official municipio count (around 2,469), event count in tens or hundreds of thousands given Mexico's homicide volume.

---

## 4. Analytical Pipeline

For each analytical section: what question it answers, the code, why we made specific choices, and what its limitations are.

### 4.1 Spatial join, events to districts

**Question it answers:** which district did each event occur in?

**Why we need this:** ACLED events have lat/lon coordinates but most analytical units (rankings, choropleths, statistical tests) operate on districts.

**Code:**

```r
library(tidyr)

afg_pts <- afg |>
  filter(!is.na(latitude), !is.na(longitude)) |>
  mutate(event_date = as.Date(event_date)) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

afg_adm2 <- st_transform(afg_adm2, 4326)

afg_pts <- st_join(
  afg_pts,
  afg_adm2[, c("GID_2", "NAME_1", "NAME_2")],
  join = st_within
)

afg_pts <- afg_pts |>
  mutate(period = if_else(event_date < as.Date("2021-08-15"),
                          "pre_Aug2021", "post_Aug2021"))

district_counts <- afg_pts |>
  st_drop_geometry() |>
  filter(!is.na(GID_2)) |>
  count(GID_2, NAME_1, NAME_2, period, name = "events") |>
  pivot_wider(names_from = period, values_from = events, values_fill = 0)
```

**Why CRS 4326:** WGS84 is the standard for lat/lon data, including ACLED's coordinates and GADM's boundaries. Both have to match for `st_join` to work correctly.

**Why `st_within` not `st_intersects`:** `st_within` is unambiguous for points (a point is either inside a polygon or it isn't). `st_intersects` would return matches for points exactly on a polygon boundary, which can produce duplicate assignments.

**Match rate:** 68,029 of 68,034 events matched (99.99%). Five events fell outside any GADM polygon, likely due to small GADM coordinate imprecisions at the country border. Acceptable.

**Why split at August 15, 2021:** That is the day Kabul fell to the Taliban. The conflict regime, reporting environment, and event categorization all changed on that date. Pre-2021 events are a different phenomenon from post-2021 events; treating them as one continuous series is misleading.

### 4.2 Choropleth at admin-2

**Question it answers:** what is the spatial pattern of conflict, at administrative units?

**Code:**

```r
library(ggplot2)
library(scales)

afg_adm2_counts <- afg_adm2 |>
  left_join(district_counts, by = c("GID_2", "NAME_1", "NAME_2")) |>
  mutate(
    pre_Aug2021  = replace_na(pre_Aug2021, 0),
    post_Aug2021 = replace_na(post_Aug2021, 0)
  )

afg_long <- afg_adm2_counts |>
  pivot_longer(
    cols      = c(pre_Aug2021, post_Aug2021),
    names_to  = "period",
    values_to = "events"
  ) |>
  mutate(period = factor(period,
                         levels = c("pre_Aug2021", "post_Aug2021"),
                         labels = c("Before 15 Aug 2021", "After 15 Aug 2021")))

ggplot(afg_long) +
  geom_sf(aes(fill = events), color = "white", linewidth = 0.1) +
  scale_fill_viridis_c(
    option = "rocket", direction = -1, trans = "sqrt",
    name = "ACLED events", labels = label_comma(),
    breaks = c(0, 100, 500, 1500, 3000, 5000)
  ) +
  facet_wrap(~ period) +
  theme_void()
```

**Why `trans = "sqrt"`:** conflict counts are heavily right-skewed. A handful of districts have thousands of events, most have zero or single digits. Linear scale washes out the middle of the distribution. Log scale handles zeros poorly. Square root is the compromise: zero stays zero, large values are visually compressed, small differences in low-count districts remain visible.

**Why `viridis` `rocket` palette:** sequential warm palette appropriate for conflict data, colorblind-safe, prints in greyscale. The `direction = -1` reverses it so high counts are dark (intuitive for "more conflict").

**Why facet by period:** comparing two maps side by side reveals the spatial reorganization more clearly than two separate plots or a difference map.

**Limitations:** districts are administrative units with arbitrary boundaries. The choropleth implies discontinuous breaks at district lines that do not exist in the underlying phenomenon. This is what KDE corrects for.

**Note on period length asymmetry:** the pre-period is ~4.6 years, the post-period is ~3.8 years. Raw event counts are therefore not directly comparable in magnitude. The spatial reorganization (which districts are red vs. which are pale) is the analytical point, but for a more rigorous version, normalize by period length to get events-per-year rates.

### 4.3 District ranking, top 20

**Question it answers:** what are the specific places, not just the colored regions?

**Code:**

```r
pre_ranks <- district_counts |>
  mutate(pre_rank = dense_rank(desc(pre_Aug2021))) |>
  select(GID_2, pre_rank)

district_counts_ranked <- district_counts |>
  left_join(pre_ranks, by = "GID_2")

top_pre <- district_counts_ranked |>
  arrange(desc(pre_Aug2021)) |>
  head(20) |>
  transmute(
    Rank = row_number(),
    Province = NAME_1,
    District = NAME_2,
    `Pre-Aug 2021 events` = pre_Aug2021,
    `Post-Aug 2021 events` = post_Aug2021,
    `% change` = paste0(round((post_Aug2021 / pre_Aug2021 - 1) * 100), "%")
  )

knitr::kable(top_pre)
```

**Gotcha worth remembering:** join on `GID_2`, not `NAME_2`. Several Afghan districts share names (e.g., "Kohistan" exists in Kapisa, Faryab, and Badakhshan). Joining by name produces duplicate matches and silently inflates downstream counts. GADM's `GID_2` is unique by design.

**Why `dense_rank` not `rank`:** `dense_rank` gives consecutive integer ranks even when ties exist. `rank` produces fractional ranks for ties, which read awkwardly.

**The analytical payoff:** the top-20 tables surfaced two findings that no choropleth would: Kabul went from rank 10 to rank 1, the only district in the pre-period top 20 that gained events post-2021. And the Panjshir region went from ranks in the 200s and 300s (essentially peaceful) to ranks 2, 8, 11, 12, 16, 19 (front-line resistance zones).

### 4.4 Event type composition

**Question it answers:** did the kind of conflict change, or just the volume?

**Code:**

```r
event_type_breakdown <- afg_pts |>
  st_drop_geometry() |>
  count(period, event_type, name = "events") |>
  group_by(period) |>
  mutate(
    share = events / sum(events) * 100,
    period_total = sum(events)
  ) |>
  ungroup() |>
  mutate(period = factor(period,
                         levels = c("pre_Aug2021", "post_Aug2021"),
                         labels = c("Before 15 Aug 2021", "After 15 Aug 2021")))

ggplot(event_type_breakdown,
       aes(x = reorder(event_type, share, FUN = max),
           y = share, fill = period)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.65) +
  coord_flip() +
  scale_fill_manual(values = c("Before 15 Aug 2021" = "#7a1d1d",
                               "After 15 Aug 2021"  = "#1a5490")) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  theme_minimal()
```

**Why within-period percentages (not absolute counts):** the two periods have very different denominators (about 60,000 vs about 8,000 events). Comparing absolute counts would obscure the shift in composition; comparing shares makes the periods comparable on their own terms.

**The substantive finding:** battles went from 64.7% to 27.3%, violence against civilians went from 3.87% to 34.5%, strategic developments went from 2.63% to 16.4%. This is not "the same conflict at lower intensity," it is a different category of activity. The Forum-relevant framing: this is what regime consolidation looks like, not insurgency reduction.

### 4.5 Kernel density estimate (KDE)

**Question it answers:** where is conflict concentrated when we ignore administrative boundaries entirely?

**Code:**

```r
library(spatstat)

afg_adm2_proj <- st_transform(afg_adm2, 32642)   # UTM 42N, meters
afg_pts_proj  <- st_transform(afg_pts, 32642)

afg_outline <- st_union(afg_adm2_proj)
W <- as.owin(afg_outline)

build_density <- function(pts_sf, win, sigma_m = 15000) {
  coords <- st_coordinates(pts_sf)
  pp <- ppp(x = coords[, "X"], y = coords[, "Y"],
            window = win, check = FALSE)
  density(pp, sigma = sigma_m, edge = TRUE)
}

pre_pts  <- afg_pts_proj |> filter(period == "pre_Aug2021")
post_pts <- afg_pts_proj |> filter(period == "post_Aug2021")

pre_density  <- build_density(pre_pts,  W, sigma_m = 15000)
post_density <- build_density(post_pts, W, sigma_m = 15000)
```

**Why project to UTM zone 42N:** `spatstat` operates in planar Euclidean space. Lat/lon coordinates produce distortion that grows with latitude. UTM zone 42N (EPSG:32642) covers central Afghanistan and uses meters as the unit, which makes bandwidth interpretation intuitive (15000 = 15 km).

**Why 15 km bandwidth:** large enough to smooth across district-to-province scale patterns, small enough to preserve the structural geography. Smaller bandwidth (5-10 km) gives more local detail but also more noise. Larger bandwidth (25-30 km) smooths so aggressively that the spatial pattern blurs. Could also use `bw.scott(pp)` for automatic bandwidth selection; we used a fixed value for consistency across the two periods.

**Why `edge = TRUE`:** corrects for edge effects at the country boundary, where the smoothing kernel would otherwise be partially outside the observation window.

**Why density() and not density.ppp() or KernSmooth::bkde2D:** `spatstat`'s `density()` properly clips the smoother to the observation window (`W` from `as.owin`), so the density surface respects the country outline. `bkde2D` produces a rectangular grid that bleeds outside the country, which looks wrong on a map.

**Visualization note:** convert the `spatstat im` (image) object to a data frame via `as.data.frame(d)` for ggplot. Multiply by 1e6 to convert events per m² to events per km² for legend readability. Combine with `geom_sf` for the country outline using `coord_sf(crs = 32642)` so projections align.

**Limitations:** edge effects at narrow country segments (the Wakhan corridor in northeast Afghanistan) produce blocky artifacts. These are not conflict signals, they are KDE behaving as it should where the observation window is narrow and few events fall there.

### 4.6 Getis-Ord Gi*, statistical hotspot test

**Question it answers:** which districts are statistically high relative to their neighbors, not just visually red?

**Code:**

```r
library(spdep)

nb <- poly2nb(afg_adm2_counts, queen = TRUE)
W  <- nb2listw(nb, style = "W", zero.policy = TRUE)

gi_pre  <- localG(afg_adm2_counts$pre_Aug2021,  W, zero.policy = TRUE)
gi_post <- localG(afg_adm2_counts$post_Aug2021, W, zero.policy = TRUE)

afg_adm2_counts <- afg_adm2_counts |>
  mutate(
    gi_pre_z     = as.numeric(gi_pre),
    gi_post_z    = as.numeric(gi_post),
    gi_pre_p     = 2 * (1 - pnorm(abs(gi_pre_z))),
    gi_post_p    = 2 * (1 - pnorm(abs(gi_post_z))),
    gi_pre_pfdr  = p.adjust(gi_pre_p,  method = "BH"),
    gi_post_pfdr = p.adjust(gi_post_p, method = "BH")
  )

classify_gi <- function(z, p) {
  dplyr::case_when(
    z > 0 & p <= 0.01 ~ "Hotspot p<0.01",
    z > 0 & p <= 0.05 ~ "Hotspot p<0.05",
    z < 0 & p <= 0.01 ~ "Coldspot p<0.01",
    z < 0 & p <= 0.05 ~ "Coldspot p<0.05",
    TRUE              ~ "Not significant"
  )
}
```

**Why queen contiguity:** standard for administrative polygons. Two districts are neighbors if they share any boundary point (corner-touching counts). Rook contiguity (sharing a boundary line, not just a corner) is more restrictive and would isolate some peripheral districts.

**Why row-standardized weights (`style = "W"`):** each district's spatial lag becomes a weighted mean of neighbors, regardless of how many neighbors it has. This is the standard choice for Gi*.

**Why FDR correction (`p.adjust(..., method = "BH")`):** we are running 328 simultaneous hypothesis tests (one per district). Without correction, even random data would produce roughly 16 significant results at p<0.05. Benjamini-Hochberg FDR controls the false discovery rate while preserving power better than full Bonferroni.

**Critical methodological point: Gi* detects spatial clusters, not point outliers.** Kabul City is the highest-event district in the post-2021 period but does NOT pass the Gi* test, because its immediate neighbors (other Kabul province districts) have low counts. Panjshir districts DO pass because adjacent districts also have elevated counts. The reading: Kabul violence is a point phenomenon (ISKP attacks, civil society repression), while Panjshir is a spatially organized resistance region.

**Why this matters:** if you want to flag "high outliers" separately from "high clusters," use Anselin's Local Moran's I in addition to Gi*. LISA distinguishes High-High clusters (Gi* hotspots) from High-Low outliers (single high district surrounded by lows). Project 2 (Mexico) should probably include both, since both phenomena are present in criminal violence data.

**Result:** only two clusters passed FDR pre-2021 (southern war belt, Kabul-Logar), and only one cluster passed FDR post-2021 (Panjshir-Andarab). This is the cleanest analytical finding in the document.

### 4.7 ARIMA forecasts

**Question it answers:** where is this going over the next 24 months?

**Code:**

```r
library(forecast)
library(lubridate)

monthly_data <- afg_pts |>
  st_drop_geometry() |>
  filter(event_date >= as.Date("2021-08-15"),
         !is.na(GID_2)) |>
  mutate(year_month = floor_date(event_date, "month"))

last_month <- max(monthly_data$year_month)
monthly_data <- monthly_data |> filter(year_month < last_month)

nat_monthly      <- monthly_data |> count(year_month, name = "events")
kabul_monthly    <- monthly_data |> filter(NAME_2 == "Kabul City") |>
                                    count(year_month, name = "events")
panjsher_monthly <- monthly_data |> filter(NAME_2 == "Panjsher") |>
                                    count(year_month, name = "events")

fit_and_forecast <- function(df, h = 24) {
  all_months <- seq(min(df$year_month), max(df$year_month), by = "month")
  d_full <- tibble(year_month = all_months) |>
    left_join(df, by = "year_month") |>
    mutate(events = replace_na(events, 0))

  ts_obj <- ts(d_full$events,
               start = c(year(min(d_full$year_month)),
                         month(min(d_full$year_month))),
               frequency = 12)

  m  <- auto.arima(ts_obj)
  fc <- forecast(m, h = h)

  list(
    observed = d_full,
    forecast = tibble(
      year_month = seq(max(d_full$year_month) + months(1),
                       by = "month", length.out = h),
      events   = as.numeric(fc$mean),
      lower_80 = as.numeric(fc$lower[, 1]),
      upper_80 = as.numeric(fc$upper[, 1]),
      lower_95 = as.numeric(fc$lower[, 2]),
      upper_95 = as.numeric(fc$upper[, 2])
    ),
    model = m
  )
}
```

**Why post-Aug 2021 only:** the pre-2021 data is a structurally different conflict regime. Including it in the training data would let the disappeared insurgency dominate the model's parameter estimates and produce nonsensical forecasts for the current regime.

**Why drop the last partial month:** if data ends mid-month (May 27, 2025), the May 2025 count is artificially low compared to full months. Including it pulls the recent trend downward.

**Why fill missing months with zero:** `auto.arima` requires a regular time series. If a district had no events in some month, that month is absent from `count()` output. Padding with zero is the correct interpretation (zero events) and required for the time series to be well-defined.

**Why frequency = 12:** monthly data with potential annual seasonality. `auto.arima` will test for seasonal terms; if none are present (as was the case for all three series), the seasonal components drop out.

**What auto.arima selected:**
- National total: ARIMA(0,1,0), random walk with no drift
- Kabul City: ARIMA(1,1,0), random walk with one autoregressive lag on differences
- Panjsher: ARIMA(0,1,1), random walk with one moving-average term on differences

All three differenced once, none with seasonal terms, none with drift. The substantive interpretation: the system has stabilized to the point where the model cannot find any directional signal. The "best guess" for next month is roughly the current level.

**Honest limitations to flag in any prose interpretation:**

1. ARIMA assumes stationarity. Afghan conflict has demonstrably not been stationary. The forecast is what the recent dynamics imply, not what will happen.

2. 95% prediction intervals dip below zero in all three panels. Event counts cannot be negative. This is the standard weakness of Gaussian ARIMA on count data. The proper fix is count-data state-space models (Poisson AR, negative binomial INGARCH, or a Bayesian formulation via Stan/INLA). The current model is adequate for showing "no signal of trend," but it overstates downside uncertainty.

3. The model cannot anticipate shocks: regime changes, attack campaigns, foreign re-engagement. The flat forecast is a "no surprises" baseline.

---

## 5. Document Structure

### 5.1 Quarto YAML

The final, parent-site-friendly YAML:

```yaml
---
title: "ACLED Conflict Hotspot Atlas, Afghanistan 2017 to 2025"
author: "Sajjad Sharifi"
date: today
toc: true
toc-depth: 3
code-fold: true
code-summary: "Show code"
execute:
  warning: false
  message: false
---
```

This is minimal by design. The site's `_quarto.yml` provides theme, CSS, code-copy, link styling, navbar, and footer. The page YAML only adds page-specific options (toc, code-fold).

### 5.2 Section flow

```
## Question
## Headline finding         ← written last, after all analysis settles
## Data
## Setup                    ← libraries
## Load and validate        ← sanity check chunk, visible to reader
## District boundaries      ← GADM download and outline plot
## Events by district, pre and post August 2021   ← spatial join + choropleth
## Most affected districts                         ← top 20 tables
## Event type composition shifted, not just volume ← composition bar chart
## Kernel density surface                          ← KDE
## Statistically significant hotspots, Getis-Ord Gi*  ← Gi* with FDR
## Forecasts to mid-2027                           ← ARIMA
## Limitations                                     ← honest caveats
```

The order matters. Each section reuses objects built by the previous one (`afg`, `afg_adm2_counts`, `afg_pts`, `district_counts`). Quarto runs chunks top-to-bottom regardless of section headings, but readability suffers if the prose order does not match the analytical dependency order.

### 5.3 Chunk options

- `fig.width` and `fig.height` for plot dimensions
- `code-fold: true` (set at document level) collapses code chunks behind "Show code" buttons in HTML output
- `execute: warning: false, message: false` (document level) suppresses package-attach noise from rendered output

### 5.4 Prose conventions

- Each analysis section: brief intro paragraph + code chunk + analytical interpretation paragraph
- Lead with what the chart or test shows, follow with what mechanism explains it, end with what it does not show
- Use structured signposts ("Three patterns stand out," "Two things become clearer") to make the prose scannable
- Acknowledge limitations within each section, not only at the end
- Phrase like "None of this is causal evidence" or "The forecast is a baseline expectation under no surprises, not a prediction" is what separates analytical writing from journalism

---

## 6. Publishing Workflow

### 6.1 Local render

```bash
cd ~/UrbanProjects/sajjad-sharifi.github.io
quarto render
```

Rebuilds the entire site to `_site/`. Takes 30 to 120 seconds depending on which chunks need re-execution. Quarto caches chunk outputs; only changed chunks re-run.

### 6.2 Publish to GitHub Pages

```bash
quarto publish gh-pages
```

Pushes `_site/` to the `gh-pages` branch on GitHub. Prompts for confirmation. GitHub Pages serves from this branch. Live updates appear in 2 to 5 minutes after publish.

### 6.3 Site integration

The portfolio's `projects.qmd` at the root is the listings page. To add a new project:

```markdown
## Conflict & Fragility Studies

A series of R-based spatial statistics projects on fragile-state contexts ...

### [Afghanistan, 2017 to 2025](projects/acled-afghanistan/index.html)

ACLED political violence events analyzed before and after the August 2021 regime break ...
```

Link target: `projects/<name>/index.html` (relative path from the site root).

### 6.4 The navbar inheritance pitfall, with fix

If the navbar disappears on your project page, the cause is almost certainly a `format: html: ...` block in the page YAML. The fix is to remove that block and promote any page-specific keys (`toc`, `code-fold`) to top-level YAML. See section 5.1 above for the safe minimal YAML.

---

## 7. Lessons Learned

### 7.1 What worked

- **Incremental development across small sessions** built momentum without exhausting the cognitive budget. Day 1 was just folder + data pull. Day 5 was just forecasts. Trying to do all of this in one sitting would have produced worse work.

- **renv from day one.** Locking 130 packages at project start meant no "it works on my machine" surprises. Adding new packages later (`geodata`, `spatstat`, `spdep`, `forecast`) was a one-line install plus `renv::snapshot()`.

- **Quarto document as the build target.** Writing prose alongside code, with the same document re-renderable at any time, kept the analytical narrative coherent. The final HTML is what the reader sees; the chunks are reproducibility infrastructure.

- **Cumulative narrative structure.** Each section builds on the previous: choropleth (broad spatial), rankings (specific places), composition (qualitative shift), KDE (continuous surface), Gi* (statistical clusters), forecast (where it is heading). The reader can follow the thread.

- **"Headline finding" up front.** A 200-word paragraph at the top that lands the three main findings in plain English makes the document Forum-skimmable. Anyone clicking through has the punchline in 30 seconds.

### 7.2 What slowed us down

- **ACLED authentication.** Three rounds: first assumed API keys (deprecated September 2025), then OAuth via the package, then password typos that we did not catch until we verified credentials worked on the website. Lesson for Project 2: verify credentials on the data provider's website BEFORE trying to use them in R.

- **.Renviron file never read by R.** Burned an hour on nano, VS Code edits, file mode changes, none of which fixed it. Workaround was `Sys.setenv()` plus `askForPassword()`. Worth properly diagnosing in Project 2 with the steps in section 2.4.

- **One chunk got interpreted as bash.** A single chunk header was missing its `{r}` tag, so the setup chunk ran as shell and threw "library(dplyr): command not found." Easy to fix once spotted; the diagnostic is `/bin/sh:` in the error message.

- **Section ordering at the end.** When we replaced placeholder `## Method` with the KDE content but kept the heading, we ended up with `## Method` followed by `## Kernel density surface` at the bottom of the document, after Limitations. Required a manual cut-paste reorder.

- **Quarto YAML override broke navbar inheritance.** The original `format: html: theme: cosmo ...` block in the page YAML cut off the parent site's navbar. The fix was small (delete the block, promote keys); the diagnosis took longer than the fix.

### 7.3 Decisions that turned out well in retrospect

- **Splitting at August 15, 2021.** Confirmed by the event-type composition analysis, the Gi* result, and the ARIMA models (all of which independently picked up the regime break). Treating pre and post 2021 as one series would have produced misleading results in every method.

- **15 km KDE bandwidth.** Reasonable for the country scale. `bw.scott()` would have produced very similar results. The bandwidth choice is methodological transparency, not a black-box parameter.

- **FDR correction on Gi*.** Conservative, but appropriate for a portfolio piece that needs to defend findings under scrutiny. Without correction we would have flagged 30 to 40 districts as "significant" pre-2021, many of which are likely false positives.

- **Post-2021-only training data for ARIMA.** The model results would be useless if pre-2021 dynamics dominated the parameter estimates. The flat forecasts honestly reflect "no signal in the post-takeover regime."

---

## 8. Future Refinements for Project 1

These are polish items, in rough order of effort to value.

### 8.1 Quick polish (under 30 minutes each)

- Wrap the Gi* count tables in `knitr::kable()` so they render as proper HTML tables instead of raw R console output.
- Add a methodology appendix listing all R packages used with versions from `renv.lock`.
- Add download buttons for the figures (`download` link with `download="filename.png"` attribute) so readers can grab high-res versions.
- Hyperlink district names in the ranking tables to their ACLED dashboard pages.

### 8.2 Methodological extensions (a few hours each)

- **Normalize event counts by period length** to produce events-per-year rates. Makes the two periods directly comparable in magnitude, not just spatial pattern. Adds a third map facet ("rate of change") that highlights persistent vs emerging hotspots.

- **Local Moran's I (LISA) in addition to Gi*.** Distinguishes High-High clusters (which Gi* catches) from High-Low outliers (which Gi* misses but which describe Kabul). Together they give a fuller statistical map.

- **Count-data forecast models.** Replace `auto.arima` with one of: `tscount::tsglm` (negative binomial INGARCH), `bsts::AddLocalLevel` plus a Poisson observation model, or a Stan/INLA Bayesian formulation. The current Gaussian ARIMA produces prediction intervals that include negative event counts, which is silly. Count-data models constrain the lower bound to zero and produce more interpretable intervals.

- **Province-level rollup as an alternative analytical unit.** Some analyses (especially Gi*) behave differently at coarser spatial units. Doing it at admin-1 (34 provinces) as a robustness check would strengthen the document.

### 8.3 Visual upgrades

- Interactive Leaflet versions of the choropleths, so readers can hover over a district and see its name and counts.
- `DT::datatable` for the ranking tables, enabling sort and filter in the rendered HTML.
- `gganimate` time-series of monthly events by district, played as a video. Useful for showing the August 2021 transition viscerally.
- A summary infographic at the top (alongside the headline finding) with three numbers: percent battle reduction, number of Gi*-significant clusters in each period, forecast level for 2027.

### 8.4 The .Renviron diagnostic

Worth solving once and for all, because Projects 2 through 5 will all need it. Steps:

```bash
# Check encoding
file projects/<name>/.Renviron

# Check for BOM and other invisible chars
od -c projects/<name>/.Renviron | head

# Check for trailing newline (should end with 0a)
xxd projects/<name>/.Renviron | tail -1

# Check Unix line endings (no \r\n)
cat -A projects/<name>/.Renviron
```

If everything looks clean and R still does not read it, the issue may be the renv `.Rprofile` ordering. Try `readRenviron(".Renviron")` explicitly inside R as a forced load, and see whether the values populate.

---

## 9. Patterns for Projects 2 through 5

### 9.1 What carries over verbatim

- Folder structure (section 2.1)
- .gitignore (section 2.2)
- renv setup (section 2.3)
- .Renviron format (section 2.4)
- RStudio project creation (section 2.5)
- Parent-site YAML pattern (section 2.6 and 5.1)
- Spatial join code pattern (section 4.1)
- ggplot choropleth pattern (section 4.2)
- District ranking pattern (section 4.3)
- Quarto chunk options and prose conventions (section 5.3, 5.4)
- Publishing workflow (section 6)

### 9.2 What changes per project

| Project | Data sources | Spatial unit | New methods | New R packages |
|---------|--------------|--------------|-------------|----------------|
| 2: Mexico Fragility Index | INEGI census, ACLED, CONEVAL, SESNSP, WB governance | Admin-2 (~2,469 munis) | PCA, min-max normalization, sensitivity analysis, LISA | `FactoMineR`, `factoextra`, `psych` |
| 3: Climate-Conflict Central America | CHIRPS, ERA5, USDA drought, ACLED, EM-DAT | Admin-2, 3 countries | SPI/SPEI, spatial regression, lag analysis | `terra`, `SPEI`, `lme4`, optional `INLA` |
| 4: Displacement flows | IOM DTM, UNHCR, US CBP, IDMC | Origin-destination | Network analysis, flow maps, animated time-series | `igraph`, `ggraph`, `gganimate`, `flowmapblue` |
| 5: Walking-time accessibility | OSM roads + facilities, WorldPop | Street network | Isochrones, walking-distance accessibility, ArcGIS comparison | `osmdata`, `sfnetworks`, `dodgr` |

### 9.3 A starting template for a new project

When you start Project 2:

1. **Copy the folder structure.** `cp -r projects/acled-afghanistan/{.gitignore,data,docs,output,R} projects/mexico-fragility-index/`.

2. **Create new RStudio project.** File > New Project > Existing Directory.

3. **Initialize renv from scratch.** Each project gets its own library to avoid version drift. `renv::init(bare = TRUE)` then install packages.

4. **Create .Renviron** if new credentials needed. INEGI does not require auth, but ACLED does. Reuse the ACLED credentials.

5. **Create `index.qmd`** using the parent-site-friendly YAML in section 5.1. Pre-populate with `## Question`, `## Headline finding`, `## Data`, `## Setup`, `## Load and validate`, `## Limitations` section stubs.

6. **Add a listing entry to `projects.qmd`** at the portfolio root, in the "Conflict & Fragility Studies" section.

7. **Develop incrementally.** Each session, one analytical section plus its prose. Commit at the end of each session.

8. **Render and publish** at logical milestones (after data pull, after first map, at completion).

### 9.4 Specifically for Project 2, Mexico Subnational Fragility Index

This is the heaviest of the five (5 to 7 day build per the original brief) because index construction is methodologically debated. A few additional considerations:

- **Index construction is not neutral.** PCA, min-max scaling, geometric vs arithmetic aggregation, weighting choices, they all produce different rankings. Document every choice and run sensitivity analysis on the top three or four most consequential ones.

- **Data joining is the bottleneck.** INEGI, CONEVAL, SESNSP, WB indicators, ACLED, all have different keys, different reporting years, different spatial units. Spend the first day building the joining schema, before any analysis.

- **Time-series tracking adds a dimension.** A single cross-sectional index is fine for a snapshot. A panel of annual indices reveals which munis are deteriorating, which are recovering, which are stable. The Forum reading is about trajectories, not levels.

- **Spillover analysis (LISA) is the natural finale.** Once you have an index per muni per year, LISA shows which high-fragility munis are adjacent to other high-fragility munis (cluster) versus isolated high-fragility munis (outlier). This mirrors the Gi* / Local Moran's I pairing recommended for Project 1.

---

## 10. Appendices

### Appendix A. Final file structure

```
~/UrbanProjects/sajjad-sharifi.github.io/projects/acled-afghanistan/
├── .gitignore                                  374 B
├── .Renviron                                   84 B   (gitignored)
├── .Rprofile                                   26 B   (auto-created)
├── acled-afghanistan.Rproj                     205 B
├── data/
│   ├── raw/                                    (downloaded files, gitignored)
│   │   ├── afg_acled_2015_2025.rds
│   │   ├── afg_acled_2015_2025.csv
│   │   └── gadm/                               (cached GADM files)
│   └── processed/                              (empty, for future use)
├── docs/
│   └── project-documentation.md                (this file)
├── index.qmd                                   28.3 KB  (the analytical document)
├── output/
│   └── figures/
│       ├── events_per_district_prepost_2021.png
│       ├── event_type_composition.png
│       ├── kde_density.png
│       ├── getis_ord_gi.png
│       └── forecasts.png
├── R/                                          (empty; we used .qmd chunks)
├── renv/                                       (project library, gitignored)
│   └── activate.R
└── renv.lock                                   100.6 KB  (committed)
```

### Appendix B. Key R packages with versions

From `renv.lock` snapshot:

```
acledR        1.0.1   # official ACLED OAuth client
dplyr         1.2.1   # data wrangling
forecast      8.23    # auto.arima and forecasting
geodata       0.6     # GADM and other global datasets
ggplot2       4.0.3   # plotting
here          1.0.2   # path management
janitor       2.2.1   # column name cleaning
knitr         1.51    # kable for tables
lubridate     1.9.5   # date handling
readr         2.2.0   # fast CSV I/O
renv          1.2.3   # project library management
sf            1.1-1   # spatial vector data
spatstat      3.x     # point pattern analysis, KDE
spdep         1.x     # spatial autocorrelation, Gi*
tidyr         1.3.2   # pivot_longer, pivot_wider
tmap          4.3     # thematic mapping
```

Total: 130 packages locked across the project library.

### Appendix C. Useful commands

**R session, daily workflow:**
```r
# Open RStudio project, renv auto-activates
# Open index.qmd
# Run individual chunks: Cmd+Shift+Enter inside chunk
# Render whole document: Cmd+Shift+K
```

**Bash, daily workflow:**
```bash
cd ~/UrbanProjects/sajjad-sharifi.github.io
git status
git add projects/<name>/index.qmd \
        projects/<name>/output/figures/ \
        projects/<name>/renv.lock
git commit -m "Project N day X, brief description"
git push

# When ready to publish:
quarto render
quarto publish gh-pages
```

**Diagnostics:**
```bash
# Check ACLED credentials are set in R
Rscript -e 'cat("Email length:", nchar(Sys.getenv("ACLED_API_EMAIL")), "\n")'

# Check .Renviron for hidden characters
od -c projects/<name>/.Renviron | head

# Verify a new project rendered into site
ls _site/projects/<name>/

# Verify projects.qmd lists the new project (avoid grep on & due to HTML encoding)
grep -o "<name>" _site/projects.html
```

### Appendix D. References

- ACLED methodology: https://acleddata.com/knowledge-base/
- ACLED API documentation: https://acleddata.com/api-documentation/getting-started
- acledR package: https://github.com/ACLED/acledR
- GADM: https://gadm.org/
- Getis and Ord (1992), "The Analysis of Spatial Association by Use of Distance Statistics," Geographical Analysis 24(3): 189-206
- Benjamini and Hochberg (1995), "Controlling the False Discovery Rate," Journal of the Royal Statistical Society B 57(1): 289-300
- Hyndman and Khandakar (2008), "Automatic Time Series Forecasting: The forecast Package for R," Journal of Statistical Software 27(3)
- Pebesma (2018), "Simple Features for R: Standardized Support for Spatial Vector Data," The R Journal 10(1): 439-446
- Quarto documentation: https://quarto.org/docs/

---

End of document. Drop into `projects/acled-afghanistan/docs/`.
