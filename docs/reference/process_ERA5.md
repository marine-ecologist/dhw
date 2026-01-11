# Process ERA5 NetCDF Files

Function to extract and combine SST data from NetCDF files in a
specified folder.

See vignette for further details.

## Usage

``` r
process_ERA5(
  input,
  polygon,
  crop = TRUE,
  mask = TRUE,
  downsample = FALSE,
  res = 0.1,
  crs = "EPSG:7844",
  combinedfilename = NULL,
  silent = TRUE,
  units = "celsius"
)
```

## Arguments

- input:

  Folder containing NetCDF (.nc) files.

- polygon:

  polygon for crop/masl

- crop:

  TRUE/FALSE

- mask:

  TRUE/FALSE

- downsample:

  TRUE/FALSE

- res:

  resolution for downsamlpling

- crs:

  change the CRS if needed (EPSG:4283 as default)

- combinedfilename:

  output file path, should be .rds

- silent:

  = TRUE

- units:

  Units for temperature: one of "celsius" or "kelvin". Default is
  "celsius".

- variable:

  redundant?

## Value

A combined SpatRaster object in ERA5 format.

## Examples

``` r
if (FALSE) { # \dontrun{
folder <- "/Users/rof011/GBR-dhw/datasets/era5/"
process_ERA5(folder, units = "celsius")
} # }
```
