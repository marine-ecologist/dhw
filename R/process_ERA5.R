#' @name process_ERA5
#' @title Process ERA5 NetCDF Files
#' @description
#' Function to extract and combine SST data from NetCDF files in a specified folder.
#'
#' See vignette for further details.
#'
#' @param input Folder containing NetCDF (.nc) files.
#' @param polygon polygon for crop/masl
#' @param crs change the CRS if needed (EPSG:4283 as default)
#' @param crop TRUE/FALSE
#' @param mask TRUE/FALSE
#' @param downsample TRUE/FALSE
#' @param res resolution for downsamlpling
#' @param variable redundant?
#' @param combinedfilename output file path, should be .rds
#' @param units Units for temperature: one of "celsius" or "kelvin". Default is "celsius".
#' @param silent = TRUE
#' @return A combined SpatRaster object in ERA5 format.
#' @examples
#' \dontrun{
#' folder <- "/Users/rof011/GBR-dhw/datasets/era5/"
#' process_ERA5(folder, units = "celsius")
#' }
#' @export

process_ERA5 <- function(input, polygon, crop=TRUE, mask=TRUE, downsample=FALSE, res=0.1, crs="EPSG:7844", combinedfilename = NULL, silent=TRUE, units = "celsius") {

  # List all NetCDF files in the folder
  files <- list.files(input, pattern = "\\.nc$", full.names = TRUE)

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

    if (isFALSE(silent)){
      print(paste0("Processed ", file))
      }
  }


  polygon <- polygon %>% sf::st_transform(terra::crs(ecmwfr_combined))

  if (isTRUE(mask)){
    ecmwfr_combined <- terra::mask(ecmwfr_combined, vect(polygon))
  }
  if (isTRUE(crop)){
    ecmwfr_combined <- terra::crop(ecmwfr_combined, vect(polygon))
  }
  if (isTRUE(downsample)){
    target <- terra::rast(terra::ext(ecmwfr_combined), resolution = res, crs = terra::crs(ecmwfr_combined))
    ecmwfr_combined <- terra::resample(ecmwfr_combined, target, method = "bilinear")
  }

  if (grepl("\\.rds$", combinedfilename)) {
    base::saveRDS(terra::wrap(ecmwfr_combined), combinedfilename)
  } else {
    terra::writeRaster(ecmwfr_combined, filename = combinedfilename, overwrite = TRUE)
  }


  # Return the combined raster
  return(ecmwfr_combined)
}
