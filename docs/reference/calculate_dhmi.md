# Calculate Degree Heating Month Index (DHMi)

This function calculates Degree Heating Month Index (DHMi) from Lough et
al (2018) and is calculated based on either monthly or daily SST data

Citation: Lough et al (2018) Increasing thermal stress for tropical
coral reefs: 1871–2017 Scientific Reports 8(6079)
https://www.nature.com/articles/s41598-018-24530-9

## Usage

``` r
calculate_dhmi(
  sst_raster,
  timeseries = c("daily", "monthly"),
  accumulation_window = 3,
  timespan = c(12, 5)
)
```

## Arguments

- sst_raster:

  A `SpatRaster` object containing SST data. The raster should include a
  time dimension.

- accumulation_window:

  time window for calculating DHMi (typically 3 or 4 months, see Table
  S1 in Mason et al 2024 Nature Geoscience)

- timespan:

  start and end months for summed DHMi calculations (for example in
  Austral summer - November to May = c(12,5)

## Value

A `SpatRaster` object with the computed metric.

## Examples

``` r
if (FALSE) { # \dontrun{
library(terra)
sst_data <- rast("dhw_5km_12c5_a60a_4147_U1739222110146.nc")
ssta <- calculate_dhmi(sst_data, timeseries="daily", timespan = c(12, 4))
plot(ssta)
} # }
```
