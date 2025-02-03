#' @name calculate_dhw
#' @title Calculate DHW
#' @description
#' Function to calculate hotspots
#'
#' The function computes the Degree Heating Weeks (DHW) metric, which accumulates heat stress over a specified rolling window (defaulting to 84 days). The function operates by applying a rolling sum on the input hotspots raster data. For each pixel, if the daily hotspot values are greater than or equal to 1, they are summed over the rolling window and divided by 7 to calculate weekly averages using zoo::rollapply. The function returns a raster object with the calculated DHW values, which represent accumulated heat stress.
#'
#' See vignette for further details
#'
#' @param hotspots hotspots
#' @param window number of days to sum hotspots, default = 84 (12 weeks)
#' @returns degree heating weeks (terra::rast format)
#'
#' @export
calculate_dhw <- function(hotspots, window=84) {

  # Internal function to compute rolling DHW
  calculate_dhw_internal <- function(hs_values) {
    if (all(is.na(hs_values))) {
      return(rep(NA, length(hs_values)))
    }

    # Use rollapply with handling for NA and empty vectors
    dhw_values <- zoo::rollapply(
      hs_values,
      width = window,
      FUN = function(x) {
        # Handle NA values and empty sums explicitly
        valid_values <- x[!is.na(x) & x >= 1]  # Filter valid values >= 1
        if (length(valid_values) == 0) {       # No valid values
          return(0)                            # Return 0 instead of NaN
        } else {
          return(sum(valid_values) / 7)        # Compute sum/7
        }
      },
      fill = NA,
      align = "right"
    )

    return(c(rep(NA, length(hs_values) - length(dhw_values)), dhw_values))
  }

  # Apply rolling DHW computation across raster layers
  dhw <- terra::app(hotspots, fun = function(x) {
    result <- calculate_dhw_internal(x)
    # Ensure output length matches input
    if (length(result) != length(x)) {
      result <- rep(NA, length(x))
    }
    return(result)
  })

  # Set time and layer names
  terra::time(dhw) <- as.Date(terra::time(hotspots), format = "%Y-%m-%d %H:%M:%S")
  names(dhw) <- as.Date(terra::time(hotspots), format = "%Y-%m-%d %H:%M:%S")
  terra::varnames(dhw) <- "Degree Heating Weeks"

  return(dhw)

}
