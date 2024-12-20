#' @name download_CoralTemp
#' @title Download CoralTemp data
#' @description
#'
#' Function to download and save NetCDF files for CoralTemp
#' `download_CoralTemp()` is a function to download NOAA CRW data
#'
#' If the number of cores is set to >1, the function uses `mclapply` to parallel download datasets, else 1 = single downloads.
#'
#' Notes:
#' The NOAA Coral Reef Watch (CRW) daily global 5km Sea Surface Temperature (SST) product, also known as CoralTemp,
#' shows the nighttime ocean temperature measured at the surface. The CoralTemp SST data product was developed from
#' two, related reanalysis (reprocessed) SST products and a near real-time SST product. Spanning January 1, 1985
#' to the present, the CoralTemp SST is one of the best and most internally consistent daily global 5km SST products available.
#'
#` https://coralreefwatch.noaa.gov/product/5km/index_5km_sst.php
#'
#' @param url one of the NOAA thredds url
#' @param start_date end year
#' @param end_date end year
#' @param dest_dir save file location
#' @param variable one of 'sst', 'ssta', 'hs', 'dhw'
#' @param mc.cores set the number of cores
#' @returns downloaded nc files to specified location
#' @examples
#' \dontrun{
#' download_CoralTemp(1990, 2020, "/users/era5/", variable= "ssta", cores=10)
#'}
#' @export


download_CoralTemp <- function(url = "https://www.ncei.noaa.gov/thredds-ocean/catalog/crw/5km/v3.1/nc/v1.0/daily", start_date, end_date, dest_dir, variable = "hs", mc.cores = 1) {

  # Validate the variable argument
  valid_vars <- c("sst", "dhw", "ssta", "hs")
  if (!(variable %in% valid_vars)) {
    stop("Invalid variable. Choose from 'sst', 'dhw', 'ssta', 'hs'.")
  }

  # Helper function to download a single file
  download_nc_file <- function(date, base_url, dest_dir, var) {
    # Construct the URL based on the date and variable
    file_url <- sprintf("%s/%s/ct5km_%s_v3.1_%s.nc", base_url, substr(date, 1, 6), var, date)

    # Create the year directory if it doesn't exist
    year_dir <- file.path(dest_dir, substr(date, 1, 4))
    if (!dir.exists(year_dir)) {
      dir.create(year_dir, recursive = TRUE)
    }

    # Define the destination file path
    dest_file <- file.path(year_dir, paste0(date, ".nc"))

    # Download the file
    response <- httr::GET(file_url, httr::write_disk(dest_file, overwrite = TRUE))

    if (response$status_code == 200) {
      message(paste("Successfully downloaded:", dest_file))
    } else {
      message(paste("Failed to download:", dest_file))
    }
  }

  # Generate the list of dates in the required format
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  dates <- format(seq(start_date, end_date, by = "day"), "%Y%m%d")

  if (mc.cores > 1) {
    # Use mclapply for parallel processing
    parallel::mclapply(dates, download_nc_file, base_url = url, dest_dir = dest_dir, var = variable, mc.cores = mc.cores)
  } else {
    # Use lapply for single-core processing
    lapply(dates, download_nc_file, base_url = url, dest_dir = dest_dir, var = variable)
  }
}
