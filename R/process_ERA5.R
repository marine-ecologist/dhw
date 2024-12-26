
#' @name extract_reefs
#' @title Extract reef
#' @description
#' Function to extract sst data for shp file overlay
#'
#' See vignette for further details
#'
#' @param folder folder with nc files
#' @param units one of "celsius", "kelvin"
#' @returns combined ERA5 rast format
#' @examples
#' \dontrun{
#'
# folder = "/Users/rof011/GBR-dhw/datasets/era5/
#' }
#' @export

process_ERA5 <- function(folder, units="celsius") {


  # Extract years from filenames assuming format "ecmwfr-YYYY.nc"
  files <- list.files(folder, full.names = FALSE)
  files <- sort(files)


  # Initialize combined raster
  ecmwfr_combined <- NULL

  # Loop through years and read NetCDF files
  for (i in length(files)) {
#   nc_file <- paste0("/Users/rof011/GBR-dhw/datasets/era5/ecmwfr-", i, ".nc")
    nc_file <- paste0(folder, files[i])
    print(nc_file)
    # Open NetCDF file
    nc <- ncdf4::nc_open(nc_file)
    time <- ncdf4::ncvar_get(nc, "valid_time")

    # Handle time conversion
    time_units <- ncdf4::ncatt_get(nc, "valid_time", "units")$value
    time_origin <- sub("days since ", "", time_units)
    time_origin <- as.Date(time_origin)
    time <- time_origin + time

    # Close the NetCDF file
    ncdf4::nc_close(nc)

    # Load raster data
    rastfile <- terra::rast(nc_file)

    # Assign time to the raster
    terra::time(rastfile) <- as.Date(time)
    names(rastfile) <- as.Date(time)

    if (units=="celsius") {
      rastfile <- rastfile - 273.15  # This applies the conversion to all layers
    }

    # Combine raster data
    if (is.null(ecmwfr_combined)) {
      ecmwfr_combined <- rastfile
    } else {
      ecmwfr_combined <- c(ecmwfr_combined, rastfile)
    }
  }

  return(ecmwfr_combined)

}
