



# Function to download and save NetCDF files for OISST
download_nc_OISST <- function(url="https://www.ncei.noaa.gov/thredds/fileServer/OisstBase/NetCDF/V2.1/AVHRR", start_date, end_date, dest_dir, mc.cores = 1) {

  # Helper function to download a single file
  download_nc_file <- function(date, base_url, dest_dir) {
    # Construct the URL based on the date
    file_url <- sprintf("%s/%s/oisst-avhrr-v02r01.%s.nc", base_url, substr(date, 1, 6), date)

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
    parallel::mclapply(dates, download_nc_file, base_url = url, dest_dir = dest_dir, mc.cores = mc.cores)
  } else {
    # Use lapply for single-core processing
    lapply(dates, download_nc_file, base_url = url, dest_dir = dest_dir)
  }
}
