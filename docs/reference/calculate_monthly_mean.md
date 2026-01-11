# Create Monthly Mean (MMM)

Function to calculate maximum monthly mean or trends.

See vignette for further details.

## Usage

``` r
calculate_monthly_mean(sst_file, midpoint = 1988.2857, return = "predict")
```

## Arguments

- sst_file:

  SpatRaster of SST data.

- midpoint:

  recentered date, see vignette

- return:

  Type of output: "predict", "slope", or "intercept".

## Value

Climatology as a terra::rast object.
