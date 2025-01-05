#' @name check_missing_dates
#' @title Check missing dates
#' @description
#' Function to check missing files by date in a folder
#'
#' @param folder input folder
#' @param start_date start date (YYYY-MM-DD)
#' @param end_date end date (YYYY-MM-DD)
#' @return Vector of filenames that are missing or "No missing dates"
#' @examples
#' \dontrun{
#'
#' check_missing_dates(start_date="1981-09-01", end_date="2024-04-30",  "/Volumes/Extreme_SSD/dhw/OISST/gbr")
#' check_missing_dates(start_date="1981-09-01", end_date="2024-04-30",  "/Volumes/Extreme_SSD/dhw/OISST/global" )
#' check_missing_dates(start_date="1985-06-01", end_date="2024-04-30",  "/Volumes/Extreme_SSD/dhw/CRW/global/CRW_SST")
#' check_missing_dates(start_date="1985-06-01", end_date="2024-04-30",  "/Volumes/Extreme_SSD/dhw/CRW/global/CRW_SSTA")
#'
#' }
#' @export
check_missing_dates <- function(folder, start_date, end_date) {
  # Ensure start_date and end_date are in Date format
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)

  # Generate all expected dates
  all_dates <- seq.Date(from = start_date, to = end_date, by = "day")

  # Function to extract dates from filenames
  extract_date_from_filename <- function(filename) {
    match <- regmatches(filename, regexpr("\\d{8}(?=\\.nc$)", filename, perl = TRUE))
    if (length(match) > 0) {
      return(as.Date(match, format = "%Y%m%d")) # Convert to Date object
    }
    return(NA)
  }

  # List all files recursively
  files <- list.files(folder, recursive = TRUE, full.names = TRUE)

  # Extract dates from filenames
  available_dates <- na.omit(sapply(basename(files), extract_date_from_filename))

  # Find missing dates
  missing_dates <- setdiff(all_dates, available_dates)

  # Return result as filenames
  if (length(missing_dates) == 0) {
    return("No missing dates") # Return message if no dates are missing
  } else {
    # Ensure dates are formatted correctly
    missing_files <- sprintf(
      "%s/GBR_oisst-avhrr-v02r01.%s.nc",
      folder,
      format(as.Date(missing_dates), "%Y%m%d") # Correctly format dates
    )
    return(missing_files) # Return filenames
  }
}
