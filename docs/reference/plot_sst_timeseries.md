# Plot seasonal SST vs. MMM with bleaching status

Produce a seasonal plot (Nov of `targetyear-1` to Jul of `targetyear`)
showing SST relative to the site MMM and MMM+1°C threshold, with a
bottom bar indicating NOAA-style bleaching alert status derived from
`hotspots` and `dhw`.

## Usage

``` r
plot_sst_timeseries(input, targetyear)
```

## Arguments

- input:

  A list containing at least these
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  elements:

  - `sst` — daily sea-surface temperature (with time dimension)

  - `mmm` — maximum monthly mean (single-layer raster or single cell)

  - `hotspots` — daily hotspots (same time as `sst`)

  - `dhw` — daily Degree Heating Weeks (same time as `sst`)

  Typically this is the output from your climatology pipeline.

- targetyear:

  Integer target year for the season window (plots Nov of `targetyear-1`
  through Jul of `targetyear`).

## Value

A `ggplot2` object.

## Examples

``` r
if (FALSE) { # \dontrun{
p <- plot_year(ningaloo_climatology, targetyear = 2025)
print(p)
} # }
```
