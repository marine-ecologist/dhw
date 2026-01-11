# Download GBR spatial data

function to download the GBR shape files (14.1mb in size, shp file
format) via eReefs

Notes: There are several versions of the GBR reefs shape file. This
version is downloaded via the eAtlas Website and includes reefs from the
Torres Strait. Default CRS is GDA94 (EPSG:4283)

## Usage

``` r
download_gbr_spatial(return = "base", crs = 4283)
```

## Arguments

- return:

  One of "combined", "hull", "outline", or "base"

- crs:

  change the CRS if needed (EPSG:4283 as default)

## Value

Simple feature collection with 9612 features and 35 fields

## Examples

``` r
if (FALSE) { # \dontrun{
eAtlas <- download_gbr_spatial(crs=4326)
} # }
```
