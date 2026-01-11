# Download nc files

Function to download and save NetCDF files

coraltemp_v3.1_19850101.nc ct5km_ssta_v3.1_19850101.nc
ct5km_dhw_v3.1_19850325.nc ct5km_baa_v3.1_19850325.nc
ct5km_hs_v3.1_19850101.nc

## Usage

``` r
download_nc_file_CRW(date, base_url, dest_dir, variable)
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
  variable = "ssta",
  dest_dir = "/Users/rof011/Downloads")
} # }
```
