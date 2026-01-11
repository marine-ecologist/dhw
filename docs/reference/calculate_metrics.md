# Calculate SST Variability Metrics

This function calculates various sea surface temperature (SST)
variability metrics from a `SpatRaster` object. The user can specify the
desired metric, which is then computed based on time series data.

## Usage

``` r
calculate_metrics(rast_obj, lyr, metric)
```

## Arguments

- rast_obj:

  A `SpatRaster` object containing SST data. The raster should include a
  time dimension.

- metric:

  A character string specifying the SST metric to compute. Options
  include:

  "SSTA"

  :   Sea Surface Temperature Anomaly (SST deviation from climatology).

  "SST_SD"

  :   Standard deviation of SST over time.

  "SST_Trend"

  :   Linear trend of SST over time.

  "SST_Variance"

  :   Variance of SST values.

  "SST_Seasonality"

  :   Annual range (max - min SST).

  "SST_Interannual_Amplitude"

  :   Difference between annual max and min SST.

  "SST_Skewness"

  :   Skewness of SST distribution.

## Value

A `SpatRaster` object with the computed metric.

## Details

- The function ensures that the input raster contains time information.

- If an invalid metric is supplied, an error is returned.

## Examples

``` r
if (FALSE) { # \dontrun{
library(terra)
sst_data <- rast("dhw_5km_12c5_a60a_4147_U1739222110146.nc")
ssta <- calculate_metrics(sst_data, "SSTA")
plot(ssta)
} # }
```
