# Download GBR spatial data

function to download the GBR shape files (14.1mb in size, shp file
format) via eReefs

Notes: There are several versions of the GBR reefs shape file. This
version is downloaded via the eAtlas Website and includes reefs from the
Torres Strait. Default CRS is GDA94 (EPSG:4283)

## Usage

``` r
process_OISST(
  input,
  polygon,
  crop = TRUE,
  mask = TRUE,
  downsample = FALSE,
  res = 0.1,
  variable = "sst",
  crs = "EPSG:7844",
  preliminary = TRUE,
  combinedfilename = NULL,
  mc.cores = 1,
  ...
)
```

## Arguments

- input:

  input folder

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

- variable:

  redundant?

- crs:

  change the CRS if needed (EPSG:4283 as default)

- preliminary:

  set to TRUE, strip \_preliminary from filename

- combinedfilename:

  output file path, should be .rds

- mc.cores:

  number of cores, defaults to 1

- ...:

  pass arguments to internal function

## Value

terra::rast

## Examples

``` r
if (FALSE) { # \dontrun{

GBR_hull <- download_gbr_spatial(return="hull", crs = "EPSG:7844")

process_OISST(input = "/Volumes/Extreme_SSD/dhw/global",
                  polygon = GBR_hull, crs = "EPSG:7844",
                  combinedfilename = "/Volumes/Extreme_SSD/dhw/GBR_OISST_full.rds",
                  crop=TRUE, mask=TRUE, downsample=FALSE)


rast(unwrap("/Volumes/Extreme_SSD/dhw/GBR_CoralTemp_full.rds"))
rast(unwrap("/Volumes/Extreme_SSD/dhw/GBR_CoralTemp_full.rds"))[[1]] |> plot()

} # }

if (FALSE) { # \dontrun{

process_CoralTemp(input = "/Volumes/Extreme_SSD/dhw/coraltempdhw",
                  polygon = GBR_hull, crs = "EPSG:7844",
                  combinedfilename = "/Volumes/Extreme_SSD/dhw/GBR_CoralTempDHW_full.rds",
                  crop=TRUE, mask=TRUE, downsample=FALSE)


rast(unwrap("/Volumes/Extreme_SSD/dhw/GBR_CoralTempDHW_full.rds"))[[1]] |> plot()
rast(unwrap("/Volumes/Extreme_SSD/dhw/GBR_CoralTempDHW_full.rds"))

} # }
```
