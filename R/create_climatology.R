create_climatology <- function(sst_file, window = 84, quiet = FALSE) {

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


  years <- base::as.numeric(base::format(base::as.Date(terra::time(sst_file)), "%Y"))
  months <- base::as.numeric(base::format(base::as.Date(terra::time(sst_file)), "%m"))

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

  anomaly_mmm <- sst_file - mmm

  if (!quiet) {
    print_elapsed_time("Processing HotSpots (HS)")
  }


  hotspots <- calculate_hotspots(anomaly_mmm)

  if (!quiet) {
    print_elapsed_time("Processing Degree Heating Weeks (DHW)")
  }

  dhw <- calculate_dhw(hotspots, window)

  if (!quiet) {
    print_elapsed_time("Combining outputs")
  }

  names(sst_file) <- terra::time(sst_file)

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
