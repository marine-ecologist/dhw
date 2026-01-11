# Download ERA5 data

Function to download and save NetCDF files for OISST `download_ERA5()`
is a function to download ERA5 SST data

Notes: ERA5 is the fifth generation ECMWF atmospheric reanalysis of the
global climate covering the period from January 1940 to present.

## Usage

``` r
download_ERA5(
  start_year = 1981,
  end_year = 2022,
  region = c(-9, 142, -25, 153),
  ecmwfr_key,
  timeout,
  dest_dir
)
```

## Arguments

- start_year:

  start year

- end_year:

  end year

- ecmwfr_key:

  required ecmfr key, see notes below

- timeout:

  set a timeout for downloading (minutes)

- dest_dir:

  save file location

## Value

downloaded nc files to specified location

## Examples

``` r
if (FALSE) { # \dontrun{
download_ERA5(1990, 2020, key, 60, "/users/era5/")
} # }
```
