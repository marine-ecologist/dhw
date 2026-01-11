# Download nc files

Function to download and save NetCDF files

## Usage

``` r
download_nc_file_OISST(date, base_url, dest_dir)
```

## Arguments

- date:

  date in ""

- base_url:

  one of the NOAA thredds url

- dest_dir:

  destination dir

## Value

downloaded nc files to specified location

## Examples

``` r
if (FALSE) { # \dontrun{
download_nc_file(date = 20240101,
base_url = "https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/",
dest_dir = "/Users/rof011/Downloads")
} # }
```
