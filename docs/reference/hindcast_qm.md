# Hindcast Bias-Corrected Raster Time Series via Monthly Anomaly Quantile Mapping

Reconstructs (hindcasts) an extended raster time series by
bias-correcting a long model dataset against a shorter
observed/reference dataset using **monthly anomaly Quantile Mapping
(QM)** or **Quantile Delta Mapping (QDM)**.

## Usage

``` r
hindcast_qm(
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
  verbose = TRUE
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

  integer Number of quantiles used for mapping (default = 100). Typical
  values range from 50 to 200.

- method:

  character Bias-correction method. One of:

  "qm"

  :   Quantile Mapping on anomalies (distribution matching).

  "qdm"

  :   Quantile Delta Mapping; preserves model anomaly changes.

- overlap_period:

  character vector of length 2 or NULL Optional calibration window
  `c(start_date, end_date)` in `"YYYY-MM-DD"` format. If NULL (default),
  the full overlapping period is used.

- combine:

  logical If TRUE (default), returns a continuous raster combining the
  hindcast period with the original observed data, ordered by time. If
  FALSE, returns only the hindcast period.

- filename:

  character or NULL Output filename for the hindcast raster. If NULL,
  the raster is returned in memory without writing to disk.

- overwrite:

  logical Overwrite an existing file if TRUE (default).

- wopt:

  list Write options passed to
  [`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html).
  Defaults to floating-point storage with LZW compression.

- min_n:

  integer Minimum number of non-NA observations per month required
  during the calibration period to perform quantile mapping (default =
  10).

- verbose:

  logical If TRUE (default), prints progress and diagnostic information.

## Value

terra::SpatRaster Bias-corrected hindcast raster. If `combine = TRUE`,
the output spans from the earliest date in `input2` through the latest
date in `input1`.

## Details

This implementation operates **per grid cell**, applies corrections
**independently for each calendar month**, and performs all computations
**in memory** to avoid known I/O limitations in recent versions of
`terra` when using block-wise
[`writeStart()`](https://rspatial.github.io/terra/reference/readwrite.html)
workflows.

### Conceptual workflow

1.  Spatially aligns `input2` to `input1` if geometries differ.

2.  Identifies a calibration period from overlapping dates.

3.  Computes monthly climatologies from the calibration period.

4.  Converts both datasets to monthly anomalies.

5.  Applies QM or QDM to anomalies for each month and grid cell.

6.  Reconstructs absolute values using observed climatologies.

7.  Optionally concatenates the hindcast with observed data.

Working in anomaly space preserves the seasonal cycle and avoids the
variance inflation often seen in raw quantile mapping of absolute
values.

- Correction is applied independently to each grid cell.

- Monthly climatologies are computed only from the calibration overlap.

- Cells or months with insufficient calibration data remain NA.

- All raster values are read into memory; large domains may require
  substantial RAM.

## Note

- Both rasters must share a compatible CRS after alignment.

- Time vectors must be strictly increasing.

- For daily (DOY-based) correction, monthly binning would need to be
  replaced with day-of-year bins.

## References

Cannon, A. J., Sobie, S. R., & Murdock, T. Q. (2015). Bias correction of
GCM precipitation by quantile mapping: How well do methods preserve
changes in quantiles and extremes? *Journal of Climate*, 28(17),
6938–6959.

Cannon, A. J. (2015). Selecting GCM scenarios that span the range of
changes in a multimodel ensemble. *Journal of Climate*, 28(3),
1260–1267.
