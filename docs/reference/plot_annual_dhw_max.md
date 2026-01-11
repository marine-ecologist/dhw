# Plot annual maximum DHW time series

Compute annual maxima from a DHW `SpatRaster` and return a wide
data.frame with columns `year` and `maxdhw`, plus a ggplot showing bars
for each year.

## Usage

``` r
plot_max_dhw(dhw_rast)
```

## Arguments

- dhw_rast:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  of Degree Heating Weeks with a valid time vector.

- pad_years_left:

  Integer, years to extend the left x-axis beyond min year (default 1).

- pad_years_right:

  Integer, years to extend the right x-axis beyond max year (default 1).

- x_break_by:

  Integer, spacing between x-axis breaks in years (default 2).

- fill_limits:

  Numeric length-2, limits for the fill gradient (default `c(0, 26)`).

- fill_midpoint:

  Numeric, midpoint for
  [`ggplot2::scale_fill_gradient2`](https://ggplot2.tidyverse.org/reference/scale_gradient.html)
  (default 3).

## Value

A list with:

- `data`: `tibble` with columns `year` (integer) and `maxdhw` (double)

- `plot`: `ggplot` object of the annual maxima bar chart

## Examples

``` r
if (FALSE) { # \dontrun{
out <- plot_annual_dhw_max(ningaloo_climatology$dhw)
out$data
print(out$plot)
} # }
```
