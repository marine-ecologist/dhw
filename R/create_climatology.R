#' @name create_climatology
#' @title Create climatology
#' @description
#' Function to calculate climatology from datasets
#'
#' See vignette for further details
#' outputs:
#'
#' - output$sst
#' - output$anomalies
#' - output$mm
#' - output$mmm
#' - output$dailyclimatology
#' - output$hs
#' - output$dhw
#'
#' note - calculating BAA is slow
#'
#' @param sst_file input
#' @param window number of days for the DHW sum (12 weeks = 84 days default)
#' @param quiet verbose - update with messages?
#' @param return return output TRUE/FALSE
#' @param baa return baa? TRUE/FALSE (speeds up processing)
#' @param save_output save output? "folder/filename" format where "folder/filename_sst.tif", "folder/filename_dhw.tif" etc
#' @param climatology replace mmm with external climatology? link to .nc, explicit for CRW (i.e. "GBR_ct5km_climatology_v3.1.nc")
#' @returns output list (see above for details)
#' @examples
#' \dontrun{
#' output <- create_climatology("crw.nc")
#' }
#' @export
create_climatology <- function(sst_file, anomaly=1, window = 84, quiet = FALSE, return=FALSE, baa = FALSE, save_output=NULL, climatology=NULL, ...) {
  if (!quiet) {
  cat("--- create_climatology ---\n")
  }

  start_time <- Sys.time()

  if (!quiet) {
  print_elapsed_time <- function(message) {
    elapsed <- Sys.time() - start_time
    cat(format(elapsed, digits = 2), " - ", message, "\n")
  }
  }
  # Climatology calculation: Filter SST data for the period 1985-2012
  if (!quiet) {
    print_elapsed_time("Processing Monthly Mean Climatology")
  }


  # years <- base::as.numeric(base::format(base::as.Date(terra::time(sst_file)), "%Y"))
  # months <- base::as.numeric(base::format(base::as.Date(terra::time(sst_file)), "%m"))

  mm_rast <- calculate_monthly_mean(sst_file)
  mmm_rast <- calculate_maximum_monthly_mean(mm_rast)

  if (!quiet) {
    print_elapsed_time("Processing Daily Climatology")
  }

    daily_climatology_rast <- calculate_daily_climatology(sst_file, mm_rast)

  if (!quiet) {
    print_elapsed_time("Processing SST Anomalies")
  }

  anomaly_rast <- calculate_anomalies(sst_file, daily_climatology_rast)

  if (!quiet) {
    print_elapsed_time("Processing HotSpots (HS)")
  }

  if (!is.null(climatology)){

    mmm2 <- terra::rast(climatology)
    mmm2 <- crop(mmm2, mmm_rast)
    print(mmm2_rast)
    hotspots_rast <- calculate_hotspots(mmm=mmm2, sst_file=sst_file, anomaly)

  } else {

    hotspots_rast <- calculate_hotspots(mmm=mmm_rast, sst_file=sst_file, anomaly)

  }

  if (!quiet) {
    print_elapsed_time("Processing Degree Heating Weeks (DHW)")
  }

  dhw_rast <- calculate_dhw(hotspots_rast, anomaly = anomaly, window = window)

  if (baa) {
    if (!quiet) {
      print_elapsed_time("Processing Bleaching Alert Area (BAA)")
    }

    baa_rast <- calculate_baa(hotspots_rast, dhw_rast)
  }

  if (!quiet) {
    print_elapsed_time("Combining outputs")
  }

  names(sst_file) <- terra::time(sst_file)

    if (isTRUE(baa)) {

      output <- base::list(
        sst = sst_file,
        mm = mm_rast,
        mmm = mmm_rast,
        climatology = daily_climatology_rast,
        anomaly = anomaly_rast,
        hotspots = hotspots_rast,
        dhw = dhw_rast,
        baa = baa_rast
      )

    } else {

      output <-
        base::list(
          sst = sst_file,
          mm = mm_rast,
          mmm = mmm_rast,
          climatology = daily_climatology_rast,
          anomaly = anomaly_rast,
          hotspots = hotspots_rast,
          dhw = dhw_rast
        )

    }


  if (!is.null(save_output)){
    terra::writeRaster(sst_file, paste0(save_output, "_sst.tif"), overwrite=TRUE)
    terra::writeRaster(mm_rast, paste0(save_output, "_mm.tif"), overwrite=TRUE)
    terra::writeRaster(mmm_rast, paste0(save_output, "_mmm.tif"), overwrite=TRUE)
    terra::writeRaster(daily_climatology_rast, paste0(save_output, "_climatology.tif"), overwrite=TRUE)
    terra::writeRaster(anomaly_rast, paste0(save_output, "_anomaly.tif"), overwrite=TRUE)
    terra::writeRaster(hotspots_rast, paste0(save_output, "_hotspots.tif"), overwrite=TRUE)
    terra::writeRaster(dhw_rast, paste0(save_output, "_dhw.tif"), overwrite=TRUE)
    if (isTRUE(baa)){
      terra::writeRaster(baa_rast, paste0(save_output, "_baa.tif"))
    }

  }
  if (!quiet) {
  print_elapsed_time("Writing files")
  }

  return(output)
}
