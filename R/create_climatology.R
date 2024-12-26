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
#' @param sst_file input
#' @param window number of days for the DHW sum (12 weeks = 84 days default)
#' @param quiet verbose - update with messages?
#' @returns output list (see above for details)
#' @examples
#' \dontrun{
#' output <- create_climatology("crw.nc")
#' }
#' @export

create_climatology <- function(sst_file, window = 84, quiet = FALSE, baa=FALSE){

  cat("--- create_climatology ---\n")

  start_time <- Sys.time()

  print_elapsed_time <- function(message) {
    elapsed <- Sys.time() - start_time
    cat(format(elapsed, digits = 2), " - ", message, "\n")
  }

  # Climatology calculation: Filter SST data for the period 1985-2012
  if (!quiet) {
    print_elapsed_time("Processing Monthly Mean Climatology")
  }


  # years <- base::as.numeric(base::format(base::as.Date(terra::time(sst_file)), "%Y"))
  # months <- base::as.numeric(base::format(base::as.Date(terra::time(sst_file)), "%m"))

  mm <- calculate_monthly_mean(sst_file)
  mmm <- calculate_maximum_monthly_mean(mm)

  if (!quiet) {
    print_elapsed_time("Processing Daily Climatology")
  }


  daily_climatology <- calculate_daily_climatology(sst_file, mm)

  if (!quiet) {
    print_elapsed_time("Processing SST Anomalies")
  }

  anomaly <- calculate_anomalies(sst_file, daily_climatology)

  if (!quiet) {
    print_elapsed_time("Processing HotSpots (HS)")
  }


  hotspots <- calculate_hotspots(mmm, sst_file)

  if (!quiet) {
    print_elapsed_time("Processing Degree Heating Weeks (DHW)")
  }

  dhw <- calculate_dhw(hotspots, window)

  if (!quiet) {
    print_elapsed_time("Processing Bleaching Alert Area (BAA)")
  }

  baa <- calculate_baa(hotspots, dhw)

  if (!quiet) {
    print_elapsed_time("Combining outputs")
  }


  names(sst_file) <- terra::time(sst_file)

  if (!quiet) {
  base::list(
    sst = sst_file,
    mm = mm,
    mmm = mmm,
    climatology = daily_climatology,
    anomaly = anomaly,
    hotspots = hotspots,
    dhw = dhw,
    baa = baa
    )

    } else {

      base::list(
      sst = sst_file,
      mm = mm,
      mmm = mmm,
      climatology = daily_climatology,
      anomaly = anomaly,
      hotspots = hotspots,
      dhw = dhw

    )
  }

    print_elapsed_time("Combining outputs")
}
