#' @name download_CoralTemp
#' @title Download CoralTemp data
#' @description
#' Downloads and saves NOAA CoralTemp NetCDF files from the specified start and end dates.
#'
#' The CoralTemp dataset provides daily global 5km Sea Surface Temperature (SST) data,
#' including anomalies and degree heating weeks, spanning from January 1, 1985.
#'
#' URL links current 4th Jan:
#' https://www.ncei.noaa.gov/thredds-ocean/catalog/crw/5km/v3.1/nc/v1.0/daily/sst/1985/catalog.html?dataset=crw/5km/v3.1/nc/v1.0/daily/sst/1985/coraltemp_v3.1_19850101.nc
#' https://www.ncei.noaa.gov/thredds-ocean/fileServer/crw/5km/v3.1/nc/v1.0/daily/sst/1985/coraltemp_v3.1_19850101.nc
#'
#' See: https://coralreefwatch.noaa.gov/product/5km/index_5km_sst.php
#'
#' @param url NOAA THREDDS server URL. Default is the CoralTemp data server.
#' @param start_date Start date in "YYYY-MM-DD" format.
#' @param end_date End date in "YYYY-MM-DD" format.
#' @param dest_dir Directory where NetCDF files should be saved.
#' @param variable Data type: 'sst', 'dhw', 'ssta', or 'hs'.
#' @param mc.cores Number of cores for parallel downloads.
#' @returns Saves NetCDF files in the specified destination folder.
#' @examples
#' \dontrun{
#'
#' download_CoralTemp(url = "https://www.ncei.noaa.gov/thredds-ocean/fileServer/crw/5km/v3.1/nc/v1.0/daily/",
#'                    start_date = "1990-01-01",
#'                    end_date = "1990-01-02",
#'                    dest_dir = "/Volumes/Extreme_SSD/dhw/CRW/2024/",
#'                    variable = "sst",
#'                    mc.cores = 1)
#'}
#' @export

download_CoralTemp <- function(
    url = "https://www.ncei.noaa.gov/thredds-ocean/fileServer/crw/5km/v3.1/nc/v1.0/daily/",
    start_date,
    end_date,
    dest_dir,
    variable = "sst",
    mc.cores = 1
) {

  # Validate the variable argument
  valid_vars <- c("sst", "dhw", "ssta", "hs")
  if (!(variable %in% valid_vars)) {
    stop("Invalid variable. Choose from 'sst', 'dhw', 'ssta', 'hs'.")
  }

  # Ensure destination directory exists
  if (!dir.exists(dest_dir)) {
    dir.create(dest_dir, recursive = TRUE)
  }


  # Generate the list of dates in the required format
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  dates <- format(seq(start_date, end_date, by = "day"), "%Y%m%d")

  # Parallel or sequential processing
  if (mc.cores > 1) {
    invisible(parallel::mclapply(dates, download_nc_file_CRW,
                       base_url = url, dest_dir = dest_dir, var = variable,
                       mc.cores = mc.cores))
  } else {
    invisible(lapply(dates, download_nc_file_CRW,
           base_url = url, dest_dir = dest_dir, var = variable))
  }
}
