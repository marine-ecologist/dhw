


# ERA5 is the fifth generation ECMWF atmospheric reanalysis of the global climate covering the period from January 1940 to present.
# ERA5 is produced by the Copernicus Climate Change Service (C3S) at ECMWF.
# ERA5 provides hourly estimates of a large number of atmospheric, land and oceanic climate variables.
# The data cover the Earth on a 31km grid and resolve the atmosphere using 137 levels from the surface up to a height of 80km.
# ERA5 includes information about uncertainties for all variables at reduced spatial and temporal resolutions.

# https://www.ecmwf.int/en/forecasts/dataset/ecmwf-reanalysis-v5

# Function to download and save NetCDF files for OISST
download_ERA5 <- function(start_year = 1981, end_year = 2022, ecmwfr_key, timeout, output_dir) {
  ecmwfr::wf_set_key(key = ecmwfr_key)


  for (i in start_year:end_year) {
    request <- list(
      dataset_short_name = "derived-era5-single-levels-daily-statistics",
      product_type = "reanalysis",
      variable = "sea_surface_temperature",
      year = i,
      month = c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"),
      day = c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31"),
      daily_statistic = "daily_mean",
      time_zone = "utc+10:00",
      frequency = "1_hourly",
      area = c(-9, 142, -25, 153),
      target = paste0("ecmwfr-", i, ".nc")
    )

    file <- ecmwfr::wf_request(
      request  = request,
      transfer = TRUE,
      time_out = timeout, # time out (secs)
      path     = output_dir
    )
  }
}
