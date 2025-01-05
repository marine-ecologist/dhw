#' @name download_OISST
#' @title Download OISST data
#' @description
#'
#' Function to download and save NetCDF files for CoralTemp
#' `download_OISST()` is a function to download OISST v2.1
#'
#' If the number of cores is set to >1, the function uses `mclapply` to parallel download datasets, else 1 = single downloads.
#'
#' Notes:
#' The NOAA 1/4° Daily Optimum Interpolation Sea Surface Temperature (OISST) is a long term Climate Data Record that incorporates
#' observations from different platforms (satellites, ships, buoys and Argo floats) into a regular global grid. The dataset is
#' interpolated to fill gaps on the grid and create a spatially complete map of sea surface temperature. Satellite and ship observations
#' are referenced to buoys to compensate for platform differences and sensor biases.
#'
#` https://www.ncei.noaa.gov/products/optimum-interpolation-sst
#'
#' @param url one of the NOAA thredds url
#' @param start_date end year
#' @param end_date end year
#' @param dest_dir save file location
#' @param mc.cores set the number of cores
#' @returns downloaded nc files to specified location
#' @examples
#' \dontrun{
#'
#' download_OISST(url = "https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/",
#'   start_date = "1990-01-01",
#'   end_date = "1990-01-02",
#'   dest_dir = "/Volumes/Extreme_SSD/dhw/OISST/2024/",
#'   mc.cores = 1)
#'
#' }
#' @export



# Function to download and save NetCDF files for OISST
download_OISST <- function(url="https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/", start_date, end_date, dest_dir, mc.cores = 1) {

  # Generate list of dates
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  dates <- format(seq(start_date, end_date, by = "day"), "%Y%m%d")

  # Download files using parallel or sequential processing
  if (mc.cores > 1) {
    invisible(parallel::mclapply(dates, download_nc_file_OISST,
                       base_url = url, dest_dir = dest_dir, mc.cores = mc.cores))
  } else {
    invisible(lapply(dates, download_nc_file_OISST, base_url = url, dest_dir = dest_dir))
  }
}
