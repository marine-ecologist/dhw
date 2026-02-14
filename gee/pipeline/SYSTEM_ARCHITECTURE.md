# GBR Coral Heat Stress System — Architecture

## System Overview

```
╔══════════════════════════════════════════════════════════════════╗
║                        DATA SOURCES                             ║
║  Historical (R on local)          Daily (GEE Cloud Function)    ║
║  OISST 1981-09-01 → 2025-06-30   OISST yesterday, every day    ║
╚═══════════════╦═══════════════════════════╦══════════════════════╝
                ║                           ║
                ▼                           ▼
╔══════════════════════════════════════════════════════════════════╗
║                    GCS BUCKET: coral-dhw-gbr                    ║
║                                                                  ║
║  Gridded COGs (pixel-aligned, 63×49, 0.25°, EPSG:4326)         ║
║  ├── sst/{year}/{YYYYMMDD}.tif                                  ║
║  ├── sst_anomaly/{year}/{YYYYMMDD}.tif                          ║
║  ├── hotspot/{year}/{YYYYMMDD}.tif                              ║
║  └── dhw/{year}/{YYYYMMDD}.tif                                  ║
║                                                                  ║
║  Reef-level extractions                                          ║
║  └── reef_timeseries/                                            ║
║      ├── sst.parquet          (LABEL_ID, GBR_NAME, date, sst)   ║
║      ├── sst_anomaly.parquet                                     ║
║      ├── hotspot.parquet                                         ║
║      └── dhw.parquet                                             ║
║                                                                  ║
║  GBR-wide summary                                                ║
║  └── gbr_summary.csv          (date, var, mean, ci95_lo, ci95_hi)║
╚══════════════════════════════════════════════════════════════════╝
                ║                           ║
                ▼                           ▼
╔══════════════════════════════════════════════════════════════════╗
║                     BIGQUERY (optional)                          ║
║  coral_dhw.daily_summary       ← GBR-wide stats per day        ║
║  coral_dhw.reef_daily          ← per-reef stats per day        ║
╚══════════════════════════════════════════════════════════════════╝
                ║
                ▼
╔══════════════════════════════════════════════════════════════════╗
║                     FRONTEND (future)                            ║
║  MapLibre / Leaflet / Cesium                                     ║
║  ├── Raster tiles from COGs via TiTiler                         ║
║  ├── Reef polygons (GeoJSON) with click → time series           ║
║  └── GBR-wide time series chart (SST, SSTA, HS, DHW)           ║
╚══════════════════════════════════════════════════════════════════╝
```

## Components

### 1. Historical Processing (R, local machine)

You already have this working. The key output is multi-layer TIFs:

```r
# Your existing pipeline produces:
GBR_OISST_SST        # 63×49, 16009 layers, 1981-09-01 to 2025-06-30
GBR_OISST_SSTA       # matching grid
GBR_OISST_HS         # matching grid
GBR_OISST_DHW        # matching grid
```

**Action:** Convert to daily COGs and upload to GCS to fill the bucket
with the historical record. See `upload_historical.R` below.

### 2. Daily GEE Pipeline (Cloud Function, automated)

Already deployed. Produces one COG per product per day, on the same
63×49 grid. Runs at 12:00 UTC daily.

**Gap handling:** The first day GEE produces should be the day after
your last R-processed date. Set this in the scheduler or handle via
a "latest date" check.

### 3. Reef-Level Extraction (R or Python, triggered after each new day)

This replaces your current `extract_reefs()` function for the daily
updates. Two options:

**Option A: GEE `reduceRegions` (simplest)**
Upload the reef shapefile as an EE asset. The Cloud Function runs
reduceRegions on each product, appends results to BigQuery or
a GCS Parquet file.

**Option B: R script triggered by GCS notification (most consistent)**
A Cloud Function or Cloud Run job detects new COGs in GCS, downloads
them, runs `exactextractr::exact_extract` identically to your
historical process, and appends results. This guarantees exact
methodological consistency.

**Recommendation: Option B.** Your R code is already validated.
Wrap it in a small R script that runs on Cloud Run or even as
a cron job on your Mac.

### 4. GBR-Wide Summary

Already computed by the Cloud Function for daily data.
For historical: compute from the reef-level extractions:

```r
gbr_summary <- reef_data %>%
  group_by(date) %>%
  summarise(
    mean = mean(value),
    sd = sd(value),
    n = n(),
    ci95_lower = mean - 1.96 * sd / sqrt(n),
    ci95_upper = mean + 1.96 * sd / sqrt(n)
  )
```

### 5. Frontend Data Serving (future)

| Layer | Source | Served via |
|-------|--------|-----------|
| Raster tiles (SST, DHW, etc.) | COGs in GCS | TiTiler → XYZ tiles |
| Reef polygons + latest values | GeoJSON in GCS | Static fetch |
| Reef time series on click | Parquet in GCS or BigQuery | API query |
| GBR-wide chart | CSV in GCS or BigQuery | Static fetch |

## File Formats — Why These Choices

| Format | Used for | Why |
|--------|----------|-----|
| **COG (GeoTIFF)** | Gridded rasters | HTTP range reads, universal GIS support, tile serving |
| **Parquet** | Reef time series | Columnar, fast filtering by reef/date, small file size |
| **CSV** | GBR summary | Simple, any tool can read it |
| **GeoJSON** | Reef polygons + latest snapshot | Frontend-native, no server needed |

## Data Flow for a Typical Day

```
12:00 UTC  Cloud Scheduler fires
           │
12:00:02   Cloud Function starts
           ├── Loads OISST for yesterday
           ├── Computes SST, SSTA, HS, DHW
           ├── Kicks off 4 async COG exports → GCS
           └── Computes GBR summary → BigQuery
           │
12:05      COGs appear in GCS
           │
12:06      Reef extraction triggers (Option B):
           ├── Downloads 4 new COGs
           ├── Runs exact_extract against reef shapefile
           ├── Appends rows to reef_timeseries/*.parquet
           ├── Updates gbr_summary.csv
           └── Regenerates reef snapshot GeoJSON (latest values)
           │
12:10      Frontend picks up new data on next page load
```

## Bucket Structure (Final)

```
gs://coral-dhw-gbr/
│
├── sst/
│   ├── 1981/
│   │   ├── 19810901.tif      ← from R historical upload
│   │   ├── 19810902.tif
│   │   └── ...
│   ├── 2025/
│   │   ├── 20250701.tif      ← first day from GEE daily
│   │   └── ...
│   └── 2026/
│       ├── 20260213.tif      ← yesterday, from GEE daily
│       └── ...
│
├── sst_anomaly/               ← same structure
├── hotspot/                   ← same structure
├── dhw/                       ← same structure
│
├── reef_timeseries/
│   ├── sst.parquet            ← all reefs × all dates
│   ├── sst_anomaly.parquet
│   ├── hotspot.parquet
│   └── dhw.parquet
│
├── reef_polygons/
│   └── reefs_latest.geojson   ← reef shapes + most recent values
│
├── gbr_summary/
│   └── gbr_daily.csv          ← date, sst_mean, sst_ci95_lo, ...
│
└── annual_max_dhw/
    ├── 1982/
    └── ...
```

## Action Items (in order)

### Done
- [x] GEE scripts 01–05 (interactive)
- [x] Cloud Function deployed
- [x] GBR polygon uploaded as EE asset
- [x] Grid alignment matched to R (63×49, 0.25°, EPSG:4326)
- [x] Cloud Scheduler created

### Next: Historical upload
- [ ] Convert R multi-layer TIFs to daily COGs
- [ ] Upload to GCS bucket
- [ ] Verify grid alignment with GEE outputs

### Next: Reef extraction
- [ ] Upload reef shapefile to GCS (for R extraction script)
- [ ] Write `extract_daily.R` — triggered by new COGs
- [ ] Backfill reef time series from historical TIFs
- [ ] Generate `reefs_latest.geojson` snapshot

### Next: Frontend
- [ ] Deploy TiTiler for raster tile serving
- [ ] Build MapLibre/Leaflet map with reef polygons
- [ ] Time series chart component (click reef → show trajectory)
- [ ] GBR-wide summary chart
