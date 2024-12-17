calculate_maximum_monthly_mean <- function(mm) {
  mmm <- terra::app(mm, fun = function(x) base::max(x, na.rm = TRUE))
  terra::varnames(mmm) <- "mmm_anom"
  return(mmm)
}
