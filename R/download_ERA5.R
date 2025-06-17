#' @name download_ERA5
#' @title Download ERA5 data
#' @description
#' Function to download and save NetCDF files for OISST
#' `download_ERA5()` is a function to download ERA5 SST data
#'
#' Notes:
#' ERA5 is the fifth generation ECMWF atmospheric reanalysis of the global climate covering the period from January 1940 to present.
# https://www.ecmwf.int/en/forecasts/dataset/ecmwf-reanalysis-v5

#'
#' @param start_year start year
#' @param end_year end year
#' @param ecmwfr_key required ecmfr key, see notes below
#' @param dest_dir save file location
#' @param timeout set a timeout for downloading (minutes)
#' @returns downloaded nc files to specified location
#' @examples
#' \dontrun{
#' download_ERA5(1990, 2020, key, 60, "/users/era5/")
#'}
#' @export


download_ERA5 <- function(start_year = 1981, end_year = 2022, region = c(-9, 142, -25, 153), ecmwfr_key, timeout, dest_dir) {
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
      area = region,
      target = paste0("ecmwfr-", i, ".nc")
    )

    file <- ecmwfr::wf_request(
      request  = request,
      transfer = TRUE,
      time_out = timeout, # time out (secs)
      path     = dest_dir
    )

    file
  }
}
