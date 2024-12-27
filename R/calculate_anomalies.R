#' @name calculate_anomalies
#' @title Calculate anomalies
#' @description
#' Function to calculate anomalies
#'
#' See vignette for further details
#'
#'
#' @param sst_file sst file
#' @param climatology daily climatology
#' @returns SST anomalies (terra::rast format)
#'
#' @export
calculate_anomalies <- function(sst_file, climatology) {

  anomaly <- sst_file - climatology

  anomaly <- terra::lapp(terra::sds(list(sst_file, climatology)),
       fun = function(r1, r2) { return( r1 - r2) })

  terra::varnames(anomaly) <- "SST Anomalies"
  terra::time(anomaly) <- terra::time(sst_file)
  names(anomaly) <- as.Date(terra::time(anomaly))

  return(anomaly)
}
