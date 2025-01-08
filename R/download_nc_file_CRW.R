#' @name download_nc_file_CRW
#' @title Download nc files
#' @description
#'
#' Function to download and save NetCDF files
#'
#'
#'   coraltemp_v3.1_19850101.nc
#'   ct5km_ssta_v3.1_19850101.nc
#'   ct5km_dhw_v3.1_19850325.nc
#'   ct5km_baa_v3.1_19850325.nc
#'   ct5km_hs_v3.1_19850101.nc
#'
#' @param base_url one of the NOAA thredds url
#' @param date date in ""
#' @param dest_dir destination dir
#' @returns downloaded nc files to specified location
#' @keywords internal
#' @examples
#' \dontrun{
#' download_nc_file(date = 20240101,
#'   base_url = "https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/",
#'   variable = "ssta",
#'   dest_dir = "/Users/rof011/Downloads")
#' }
#' @export


# Helper function to download a single file
download_nc_file_CRW <- function(date, base_url, dest_dir, variable) {
  # Format date
  date <- gsub("-", "", date)
  year <- substr(date, 1, 4)
  month <- substr(date, 1, 6) # YYYYMM

  # Construct the URL dynamically based on the variable
  if (variable == "sst") {
    file_url <- sprintf("%s/%s/%s/coraltemp_v3.1_%s.nc",
                        base_url, variable, year, date)
  } else if (variable %in% c("hs", "dhw", "ssta", "baa")){
    file_url <- sprintf("%s/%s/%s/ct5km_%s_v3.1_%s.nc",
                        base_url, variable, year, variable, date)
  }
  nc_link <- sub(".*/", "/", file_url)
  nc_link <- sub("\\.nc$", "", nc_link)
  print(nc_link)

  # Define destination path
  year_dir <- file.path(dest_dir, year)
  if (!dir.exists(year_dir)) {
    dir.create(year_dir, recursive = TRUE)
  }

  dest_file <- file.path(year_dir, paste0(nc_link, ".nc"))

  # Download the file
  response <- httr::GET(file_url, httr::write_disk(dest_file, overwrite = TRUE))

  # Check response status
  if (response$status_code == 200) {
    message(paste("Successfully downloaded:", dest_file))
  } else {
    message(paste("Failed to download:", dest_file, "Status:", response$status_code))
  }
}
