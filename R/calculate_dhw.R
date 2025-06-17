#' @name calculate_dhw
#' @title Calculate DHW
#' @description
#' Function to calculate Degree Heating Weeks (DHW).
#'
#' The function computes the Degree Heating Weeks (DHW) metric, which accumulates
#' heat stress over a specified rolling window (defaulting to 84 days). If
#' `anomaly >= 1`, only daily hotspot values greater than or equal to that
#' threshold are included. If `anomaly < 1`, *all* non-NA hotspot values are
#' included without thresholding.
#'
#' @param hs SpatRaster of hotspots.
#' @param anomaly numeric threshold for hotspots (default = 1). If <1, no thresholding is applied.
#' @param window number of days to sum hotspots, default = 84 (12 weeks).
#' @returns SpatRaster of Degree Heating Weeks.
#'
#' @export
calculate_dhw <- function(hs, anomaly = 1, window = 84) {

  # Internal function to compute rolling DHW
  calculate_dhw_internal <- function(hs_values) {
    if (all(is.na(hs_values))) {
      return(rep(NA, length(hs_values)))
    }

    dhw_values <- zoo::rollapply(
      hs_values,
      width = window,
      FUN = function(x) {
        if (anomaly < 1) {
          valid_values <- x[!is.na(x)]                # take all non-NA values
        } else {
          valid_values <- x[!is.na(x) & x >= anomaly] # only values >= threshold
        }

        if (length(valid_values) == 0) {
          return(0)
        } else {
          return(sum(valid_values) / 7)
        }
      },
      fill = NA,
      align = "right"
    )

    return(c(rep(NA, length(hs_values) - length(dhw_values)), dhw_values))
  }

  # Apply rolling DHW computation across raster layers
  dhw <- terra::app(hs, fun = function(x) {
    result <- calculate_dhw_internal(x)
    if (length(result) != length(x)) {
      result <- rep(NA, length(x))
    }
    return(result)
  })

  # Preserve time dimension and names
  terra::time(dhw) <- as.Date(terra::time(hs), format = "%Y-%m-%d %H:%M:%S")
  names(dhw) <- as.Date(terra::time(hs), format = "%Y-%m-%d %H:%M:%S")
  terra::varnames(dhw) <- "Degree Heating Weeks"

  return(dhw)
}
