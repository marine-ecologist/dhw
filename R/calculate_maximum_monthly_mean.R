#' @name calculate_maximum_monthly_mean
#' @title Create Maximum Monthly Mean (MMM)
#' @description
#' Function to calculate maximum monthly mean from datasets
#'
#' @param mm monthly mean
#' @returns output list (see above for details)
#' @export
calculate_maximum_monthly_mean <- function(mm) {
  mmm <- terra::app(mm, fun = function(x) {
    # Return NA if all values are NA
    if (all(is.na(x))) {
      return(NA)
    }
    # Otherwise, calculate max ignoring NA
    return(base::max(x, na.rm = TRUE))
  })
  terra::varnames(mmm) <- "mmm_anom"
  return(mmm)
}
