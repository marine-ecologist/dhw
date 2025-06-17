#' @name calculate_hotspots
#' @title Calculate hotspots
#' @description
#' Function to calculate hotspots
#'
#' See vignette for further details
#'
#' @param mmm maximum monthly mean
#' @param sst_file sst file
#' @returns daily hotpsots (terra::rast format)
#'
#'
#' @export
calculate_hotspots <- function(mmm, sst_file, anomaly=1) {

  set_hs_zero <- function(x) {
    x[x < 0] <- 0
    return(x)
  }

  set_hs <- function(x) {
    x[x < as.numeric(anomaly)] <- 0
    return(x)
  }

  anomaly_mmm <- sst_file - mmm
  names(anomaly_mmm) <- terra::time(anomaly_mmm)
  terra::varnames(anomaly_mmm) <- "mmm_anom"

  hotspots_unset <- terra::app(anomaly_mmm, fun = set_hs_zero)
  terra::time(hotspots_unset) <- as.Date(terra::time(hotspots_unset), format = "%Y-%m-%d %H:%M:%S")
  names(hotspots_unset) <- terra::time(hotspots_unset)
  terra::varnames(hotspots_unset) <- "hs_unset"

  hotspots <- terra::app(anomaly_mmm, fun = set_hs)
  terra::time(hotspots) <- as.Date(terra::time(anomaly_mmm), format = "%Y-%m-%d %H:%M:%S")
  names(hotspots) <- as.Date(terra::time(anomaly_mmm), format = "%Y-%m-%d %H:%M:%S")
  terra::varnames(hotspots) <- "Hotspots"

  return(hotspots)
}
