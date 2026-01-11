# Flatten climatology outputs (list of SpatRaster) to a tidy data.frame

Flatten climatology outputs (list of SpatRaster) to a tidy data.frame

## Usage

``` r
as_climatology_df(input, vars = NULL, xy = TRUE, rename_xy = TRUE)
```

## Arguments

- vars:

  character vector of element names to extract and join (defaults to
  c("sst","climatology","anomaly","hotspots","dhw") present in x)

- x:

  list with SpatRaster elements (e.g., x\$sst, x\$climatology,
  x\$anomaly, x\$hotspots, x\$dhw)

## Value

tibble with columns: lon, lat, time, and one column per var in `vars`
