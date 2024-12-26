#' @name process_ERA5
#' @title Process ERA5 NetCDF Files
#' @description
#' Function to extract and combine SST data from NetCDF files in a specified folder.
#'
#' See vignette for further details.
#'
#' @param folder Folder containing NetCDF (.nc) files.
#' @param units Units for temperature: one of "celsius" or "kelvin". Default is "celsius".
#' @return A combined SpatRaster object in ERA5 format.
#' @examples
#' \dontrun{
#' folder <- "/Users/rof011/GBR-dhw/datasets/era5/"
#' process_ERA5(folder, units = "celsius")
#' }
#' @export

process_ERA5 <- function(folder, units = "celsius") {

  # List all NetCDF files in the folder
  files <- list.files(folder, pattern = "\\.nc$", full.names = TRUE)

  # Sort files by name to ensure correct order
  files <- sort(files)

  # Initialize combined raster
  ecmwfr_combined <- NULL

  # Loop through each file and process it
  for (file in files) {
    # Open NetCDF file
    nc <- ncdf4::nc_open(file)

    # Extract time variable
    time <- ncdf4::ncvar_get(nc, "valid_time")

    # Handle time conversion
    time_units <- ncdf4::ncatt_get(nc, "valid_time", "units")$value
    time_origin <- sub("days since ", "", time_units)
    time_origin <- as.Date(time_origin)
    time <- time_origin + time

    # Close the NetCDF file
    ncdf4::nc_close(nc)

    # Load raster data
    rastfile <- terra::rast(file)

    # Assign time to raster layers
    terra::time(rastfile) <- as.Date(time)
    names(rastfile) <- as.Date(time)

    # Convert units if required
    if (units == "celsius") {
      rastfile <- rastfile - 273.15  # Convert Kelvin to Celsius
    }

    # Combine raster data
    if (is.null(ecmwfr_combined)) {
      ecmwfr_combined <- rastfile
    } else {
      ecmwfr_combined <- c(ecmwfr_combined, rastfile)
    }
  }

  # Return the combined raster
  return(ecmwfr_combined)
}
