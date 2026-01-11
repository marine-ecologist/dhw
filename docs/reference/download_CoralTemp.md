# Download CoralTemp data

Downloads and saves NOAA CoralTemp NetCDF files from the specified start
and end dates.

The CoralTemp dataset provides daily global 5km Sea Surface Temperature
(SST) data, including anomalies and degree heating weeks, spanning from
January 1, 1985.

URL links current 4th Jan:
https://www.ncei.noaa.gov/thredds-ocean/catalog/crw/5km/v3.1/nc/v1.0/daily/sst/1985/catalog.html?dataset=crw/5km/v3.1/nc/v1.0/daily/sst/1985/coraltemp_v3.1_19850101.nc
https://www.ncei.noaa.gov/thredds-ocean/fileServer/crw/5km/v3.1/nc/v1.0/daily/sst/1985/coraltemp_v3.1_19850101.nc

See: https://coralreefwatch.noaa.gov/product/5km/index_5km_sst.php

## Usage

``` r
download_CoralTemp(
  url = "https://www.ncei.noaa.gov/thredds-ocean/fileServer/crw/5km/v3.1/nc/v1.0/daily/",
  start_date = NULL,
  end_date = NULL,
  dates = NULL,
  dest_dir,
  variable = "sst",
  mc.cores = 1,
  quiet = TRUE
)
```

## Arguments

- url:

  NOAA THREDDS server URL. Default is the CoralTemp data server.

- start_date:

  Start date in "YYYY-MM-DD" format.

- end_date:

  End date in "YYYY-MM-DD" format.

- dates:

  Vector of dates as an alternative to start_date and end_date for non
  sequential timeseries

- dest_dir:

  Directory where NetCDF files should be saved.

- variable:

  Data type: 'sst', 'dhw', 'ssta', or 'hs'.

- mc.cores:

  Number of cores for parallel downloads.

- quiet:

  show verbose? TRUE by default

## Value

Saves NetCDF files in the specified destination folder.

## Examples

``` r
if (FALSE) { # \dontrun{

download_CoralTemp(url = "https://www.ncei.noaa.gov/thredds-ocean/fileServer/crw/5km/v3.1/nc/v1.0/daily/",
                   start_date = "1990-01-01",
                   end_date = "1990-01-02",
                   dest_dir = "/Volumes/Extreme_SSD/dhw/CRW/2024/",
                   variable = "sst",
                   mc.cores = 1)
} # }
```
