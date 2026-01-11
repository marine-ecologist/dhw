# Process CoralTemp NetCDF files into a combined raster

This function reads, crops, masks, and (optionally) downsamples
CoralTemp NetCDF (.nc) files, then combines them into a single raster
stack. Processing can be done sequentially with `lapply` or in parallel
with
[`future.apply::future_lapply`](https://future.apply.futureverse.org/reference/future_lapply.html).

## Usage

``` r
process_CoralTemp(
  input,
  polygon,
  crop = TRUE,
  mask = TRUE,
  downsample = FALSE,
  res = 0.1,
  variable = "sst",
  crs = "EPSG:7844",
  combinedfilename = NULL,
  mc.cores = 1,
  silent = TRUE
)
```

## Arguments

- input:

  Character. Path to directory containing .nc files.

- polygon:

  `sf` polygon object used for cropping/masking.

- crop:

  Logical. If TRUE, crop rasters to polygon extent. Default TRUE.

- mask:

  Logical. If TRUE, mask rasters by polygon. Default TRUE.

- downsample:

  Logical. If TRUE, resample rasters to coarser resolution. Default
  FALSE.

- res:

  Numeric. Resolution for downsampling. Default 0.1.

- variable:

  Character. Variable name (currently unused placeholder). Default
  "sst".

- crs:

  Character. Target CRS for final raster (e.g., "EPSG:7844").

- combinedfilename:

  Character. Output file path (.tif or .rds).

- mc.cores:

  Integer or NULL. Number of cores for parallel processing. If NULL,
  sequential [`base::lapply`](https://rdrr.io/r/base/lapply.html) is
  used. Default 1.

- silent:

  Logical. If FALSE, print messages when files are processed.

## Value

Writes a combined raster file to `combinedfilename`. Invisibly returns
`TRUE`.

## Examples

``` r
if (FALSE) { # \dontrun{
process_CoralTemp(
  input = "data/CoralTemp/",
  polygon = sf::st_read("gbr_polygon.shp"),
  combinedfilename = "outputs/CoralTemp_combined.tif",
  mc.cores = 4,
  silent = FALSE
)
} # }
```
