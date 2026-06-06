# Data sources, Subnational Fragility Index, Mexico (state level)

Unit of analysis: 32 entidades federativas. Window: 2018 to 2024 for violence, latest available vintage for the structural indicators. Raw inputs are not committed to this repository (see `.gitignore`); only the derived tables and figures in `outputs/` are published.

## 1. Violence, SESNSP (official reported crime)
Secretariado Ejecutivo del Sistema Nacional de Seguridad Publica, Incidencia Delictiva del Fuero Comun (nueva metodologia), state level.
Portal: https://www.gob.mx/sesnsp/acciones-y-programas/datos-abiertos-de-incidencia-delictiva
Download the state-level file (Estatal, nueva metodologia). One row per state, per month, per crime type.
Save as: `data/sesnsp_estatal.csv`
Indicator used: homicidio doloso (intentional homicide). Extorsion and secuestro optional as robustness.

## 2. Violence, ACLED (political and cartel violence)
https://acleddata.com, free Research-tier account.
Filter: Country = Mexico, all event types, 2018 to 2024 (confirm the exact coverage start when you pull).
Pull via the `acledR` client or the Data Export Tool.
Save as: `data/acled_mexico.csv`
Attribution is required on any figure that uses it. The raw export is not redistributed in this repo.

## 3. Socioeconomic deprivation, CONAPO marginalization
Consejo Nacional de Poblacion, Indice de marginacion por entidad federativa 2020 (latest, based on the 2020 Census).
State-level open data file:
https://conapo.segob.gob.mx/work/models/CONAPO/Datos_Abiertos/Entidad_Federativa/IME_2020.xls
Save as: `data/conapo_marginacion_2020.xls`
Indicator used: indice de marginacion normalizado (IMN_2020), 0 to 100.

## 4. Poverty, INEGI (formerly CONEVAL)
CONEVAL was dissolved by the November 2024 constitutional reform. Since July 2025 INEGI produces the official multidimensional poverty measurement; the 2024 results were published in August 2025 using the CONEVAL methodology.
INEGI, Medicion de la pobreza, results by entidad federativa, 2024.
Portal: https://www.inegi.org.mx (search "pobreza"). Historical 2016 to 2022 entity series at the preserved CONEVAL archive, https://www.coneval.org.mx
Download the state-level table (porcentaje de poblacion en situacion de pobreza, by entidad).
Save as: `data/inegi_pobreza_2024.xlsx`
Indicator used: porcentaje de poblacion en pobreza multidimensional.

## 5. Boundaries and population
Boundaries: GADM v4.1 Mexico, admin level 1.
https://gadm.org/download_country.html
Save as: `data/gadm41_MEX_shp/gadm41_MEX_1.shp`
Population, for per-100k rates: INEGI Censo 2020 population by state, or CONAPO projections.
Save as: `data/poblacion_estatal.csv` with columns `state,population`.

## State name matching
ACLED, SESNSP, CONAPO, INEGI, and GADM spell state names differently, for example "Ciudad de Mexico" vs "Distrito Federal" vs "CDMX", "Coahuila de Zaragoza" vs "Coahuila", "Michoacan de Ocampo" vs "Michoacan". The engine script builds a normalized key (lowercase, accents stripped) and a small crosswalk so the joins do not silently drop states. Always check the post-join row count is 32.
