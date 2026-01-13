# Hindcast Bias-Corrected Raster Time Series via Monthly Anomaly Quantile Mapping (QM/QDM)

Reconstructs (hindcasts) an extended raster time series by
bias-correcting a long model dataset against a shorter
observed/reference dataset using **monthly anomaly Quantile Mapping
(QM)** or **Quantile Delta Mapping (QDM; Cannon-style)**.

## Usage

``` r
hindcast(
  input1,
  input2,
  n_quantiles = 100,
  method = c("qm", "qdm"),
  overlap_period = NULL,
  combine = TRUE,
  filename = NULL,
  overwrite = TRUE,
  wopt = list(datatype = "FLT4S", gdal = c("COMPRESS=LZW")),
  min_n = 10,
  verbose = TRUE,
  silent = TRUE
)
```

## Arguments

- input1:

  terra::SpatRaster Reference (observed) raster with the **shorter**
  time series. Must have a valid Date vector set via
  `terra::time(input1)`.

- input2:

  terra::SpatRaster Model raster with the **longer** time series
  extending earlier than `input1`. Must have a valid Date vector set via
  `terra::time(input2)`.

- n_quantiles:

  integer Number of quantiles used for mapping (default `100`). Typical
  range: `50` to `200`.

- method:

  character Bias-correction method, one of:

  "qm"

  :   Quantile Mapping on anomalies (distribution matching).

  "qdm"

  :   Quantile Delta Mapping (Cannon-style) on anomalies; preserves
      model anomaly changes.

- overlap_period:

  character vector of length 2 or `NULL` Optional calibration window
  `c(start_date, end_date)` in `"YYYY-MM-DD"` format. If `NULL`
  (default), the full overlap is used.

- combine:

  logical If `TRUE` (default), returns a continuous raster combining the
  hindcast period with the original observed data, ordered by time. If
  `FALSE`, returns only the hindcast period.

- filename:

  character or `NULL` Output filename for the raster. If `NULL`
  (default), returns a raster in memory.

- overwrite:

  logical Overwrite an existing file if `TRUE` (default).

- wopt:

  list Write options passed to
  [`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html).
  Defaults to float storage with LZW compression:
  `list(datatype = "FLT4S", gdal = c("COMPRESS=LZW"))`.

- min_n:

  integer Minimum number of non-`NA` observations per **month** and
  **cell** required during the calibration period to perform mapping
  (default `10`). Months/cells failing this remain `NA`.

- verbose:

  logical If `TRUE` (default), prints progress messages unless
  `silent = TRUE`.

- silent:

  logical If `TRUE` (default), suppresses messages regardless of
  `verbose`.

## Value

terra::SpatRaster Bias-corrected hindcast raster. If `combine = TRUE`,
spans from the earliest date in `input2` through the latest date in
`input1`. If `combine = FALSE`, spans only the hindcast period.

## Details

This implementation operates **per grid cell**, applies corrections
**independently for each calendar month**, and performs computations
**in memory** to avoid block-wise I/O workflows.

- Correction is independent for each grid cell and calendar month.

- Monthly climatologies are computed only from the calibration overlap.

- Cells/months with insufficient calibration data (`min_n`) remain `NA`.

- All raster values for calibration and hindcast periods are read into
  memory; large domains may require substantial RAM.

- The `filename` write uses a temporary file then renames, to avoid
  "source and target are the same" issues.

## Conceptual workflow

1.  Align `input2` to `input1` (resample) if geometries differ.

2.  Identify a calibration period from overlapping dates (optionally
    constrained by `overlap_period`).

3.  For each grid cell and month:

    1.  Compute monthly climatologies over the calibration overlap for
        observed and model.

    2.  Convert calibration series to monthly anomalies (value minus
        monthly climatology).

    3.  Convert hindcast (pre-observed) model values to anomalies (minus
        model monthly climatology).

    4.  Apply either:

        - **QM**: map model-historical anomaly distribution to observed
          anomaly distribution.

        - **QDM**: preserve model hindcast anomaly changes by adding the
          model delta at the same quantile: \$\$\hat{y} =
          F\_{obs}^{-1}(\tau) + \left(x -
          F\_{mod,hist}^{-1}(\tau)\right), \\\\ \tau =
          F\_{mod,proj}(x)\$\$

    5.  Reconstruct absolute values using observed monthly climatology.

4.  Optionally concatenate the hindcast with the original observed
    series.

Working in anomaly space preserves the seasonal cycle and reduces
variance inflation often seen when mapping absolute values directly.

## References

Cannon, A. J., Sobie, S. R., & Murdock, T. Q. (2015). Bias correction of
GCM precipitation by quantile mapping: How well do methods preserve
changes in quantiles and extremes? *Journal of Climate*, 28(17),
6938–6959.

Cannon, A. J. (2015). Selecting GCM scenarios that span the range of
changes in a multimodel ensemble. *Journal of Climate*, 28(3),
1260–1267.

## Examples

``` r
if (FALSE) { # \dontrun{
library(terra)

obs <- rast("GBR_OISST_SST.tif")  # observed shorter series
mod <- rast("GBR_ERA5_SST.tif")   # model longer series (extends earlier)

# QM hindcast (in memory)
out_qm <- hindcast_qm2(
  input1 = obs,
  input2 = mod,
  method = "qm",
  n_quantiles = 100,
  overlap_period = c("1982-01-01", "2025-12-31"),
  combine = TRUE,
  filename = NULL
)

# QDM hindcast (write to disk)
out_qdm <- hindcast_qm2(
  input1 = obs,
  input2 = mod,
  method = "qdm",
  n_quantiles = 100,
  overlap_period = c("1982-01-01", "2025-12-31"),
  combine = TRUE,
  filename = "GBR_OISST2_SST_anomQDM_month.tif",
  overwrite = TRUE
)
} # }
```
