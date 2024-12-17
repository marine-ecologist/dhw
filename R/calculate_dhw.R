calculate_dhw <- function(hotspots, window=84) {

  calculate_dhw_internal <- function(hs_values) {
    if (all(is.na(hs_values))) {
      return(rep(NA, length(hs_values)))
    }

    dhw_values <- zoo::rollapply(hs_values, width = window, FUN = function(x) {
      sum(x[x >= 1]) / 7
    }, fill = NA, align = "right")

    return(c(rep(NA, length(hs_values) - length(dhw_values)), dhw_values))
  }

  dhw <- terra::app(hotspots, fun = function(x) {
    result <- calculate_dhw_internal(x)
    if (length(result) != length(x)) {
      result <- rep(NA, length(x))
    }
    return(result)
  })

  terra::time(dhw) <- as.Date(terra::time(hotspots), format = "%Y-%m-%d %H:%M:%S")
  names(dhw) <- as.Date(terra::time(hotspots), format = "%Y-%m-%d %H:%M:%S")
  terra::varnames(dhw) <- "Degree Heating Weeks"

  return(dhw)
}
