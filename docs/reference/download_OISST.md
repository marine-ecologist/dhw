# Download OISST data

Function to download and save NetCDF files for CoralTemp
`download_OISST()` is a function to download OISST v2.1

If the number of cores is set to \>1, the function uses `mclapply` to
parallel download datasets, else 1 = single downloads.

Notes: The NOAA 1/4° Daily Optimum Interpolation Sea Surface Temperature
(OISST) is a long term Climate Data Record that incorporates
observations from different platforms (satellites, ships, buoys and Argo
floats) into a regular global grid. The dataset is interpolated to fill
gaps on the grid and create a spatially complete map of sea surface
temperature. Satellite and ship observations are referenced to buoys to
compensate for platform differences and sensor biases.

## Usage

``` r
download_OISST(
  url =
    "https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/",
  start_date = NULL,
  end_date = NULL,
  dates = NULL,
  dest_dir,
  mc.cores = 1
)
```

## Arguments

- url:

  one of the NOAA thredds url

- start_date:

  end year

- end_date:

  end year

- dates:

  Vector of dates as an alternative to start_date and end_date for non
  sequential timeseries

- dest_dir:

  save file location

- mc.cores:

  set the number of cores

## Value

downloaded nc files to specified location

## Examples
