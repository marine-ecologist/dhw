#' @name download_nc_file_OISST
#' @title Download nc files
#' @description
#'
#' Function to download and save NetCDF files
#'
#' @param base_url one of the NOAA thredds url
#' @param date date in ""
#' @param dest_dir destination dir
#' @keywords internal
#' @returns downloaded nc files to specified location
#' @examples
#' \dontrun{
#' download_nc_file(date = 20240101,
#' base_url = "https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/",
#' dest_dir = "/Users/rof011/Downloads")
#' }
#' @export



download_nc_file_OISST <- function(date, base_url, dest_dir) {

  # Construct the URL based on the date
  file_url <- sprintf("%s/%s/oisst-avhrr-v02r01.%s.nc", base_url, substr(date, 1, 6), date)
  nc_link <- sub(".*/", "/", file_url)
  nc_link <- sub("\\.nc$", "", nc_link)
  print(file_url)


  # Create the year directory if it doesn't exist
  year_dir <- file.path(dest_dir, substr(date, 1, 4))
  if (!dir.exists(year_dir)) {
    dir.create(year_dir, recursive = TRUE)
  }

  # Define the destination file path
  dest_file <- file.path(year_dir, paste0(nc_link, ".nc"))

  # Download the file
  response <- httr::GET(file_url, httr::write_disk(dest_file, overwrite = TRUE))

  # Check response status and return message
  if (response$status_code == 200) {
    message(paste("Successfully downloaded:", dest_file))
  } else {
    message(paste("Failed to download:", dest_file, "Status:", response$status_code))
  }
}
