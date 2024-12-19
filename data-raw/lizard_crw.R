## Script to prepare `lizard_crw` dataset
## access with:
# fpath <- system.file("extdata", "lizard_crw.tif", package="dhw")

# Load required libraries
library(dplyr)
library(terra)
library(usethis)  # For use_data()

# Define the grid point and create a buffer around it
grid_point <- data.frame(longitude = 145.405, latitude = -14.655) |>
  sf::st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |>
  terra::vect() |>
  terra::buffer(width = 1)

# Load the SST dataset
sst_timeseries <- terra::rast("/Users/rof011/GBR-dhw/datasets/coraltemp/GBR_coraltemp_v3.1_sst.nc")

# Crop the SST dataset to the grid point buffer
lizard_crw <- sst_timeseries |> terra::crop(grid_point)

# Save the dataset to the `data/` directory in `.rda` format
#usethis::use_data(lizard_crw, overwrite = TRUE, compress = "bzip2")


setGDALconfig("GDAL_PAM_ENABLED", "FALSE")
setGDALconfig("PRJ", "FALSE")


writeRaster(
  lizard_crw,
  filename = "data/lizard_crw.tif",
  gdal = c("COMPRESS=DEFLATE", "TFW=NO"),
  overwrite = TRUE
)

# Print confirmation
cat("Dataset `lizard_crw` has been saved successfully.\n")


# sst_timeseries[[which(terra::time(sst_timeseries) == as.Date("2024-03-14 12:00:00 UTC"))]]
#
# # Correct target time as POSIXct
# target_time <- as.POSIXct("2024-03-14 12:00:00", tz = "UTC")
#
# # Find the layer index matching the target time
# layer_index <- which(terra::time(sst_timeseries) == target_time)
#
# # Subset the SpatRaster by the valid index
# if (length(layer_index) > 0) {
#   filtered_sst <- sst_timeseries[[layer_index]]
#   print(filtered_sst)
# } else {
#   cat("No layer found for the specified time.\n")
# }
#
# library(ggplot2)
# library(tidyterra)
# ggplot2::ggplot() + ggplot2::theme_bw() +
#   tidyterra::geom_spatraster(data=filtered_sst, show.legend=FALSE) +
#   scale_fill_distiller(palette="RdBu", direction=-1, na.value = "transparent")

