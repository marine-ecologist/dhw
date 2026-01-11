# Calculate DHW

Function to calculate Degree Heating Weeks (DHW).

The function computes the Degree Heating Weeks (DHW) metric, which
accumulates heat stress over a specified rolling window (defaulting to
84 days). If `anomaly >= 1`, only daily hotspot values greater than or
equal to that threshold are included. If `anomaly < 1`, *all* non-NA
hotspot values are included without thresholding.

## Usage

``` r
calculate_dhw(hs, anomaly = 1, window = 84)
```

## Arguments

- hs:

  SpatRaster of hotspots.

- anomaly:

  numeric threshold for hotspots (default = 1). If \<1, no thresholding
  is applied.

- window:

  number of days to sum hotspots, default = 84 (12 weeks).

## Value

SpatRaster of Degree Heating Weeks.
