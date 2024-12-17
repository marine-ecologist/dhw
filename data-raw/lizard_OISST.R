# data-raw/lizard_OISST.R
## Script to prepare `lizard_OISST` dataset

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
sst_timeseries <- terra::rast("/Users/rof011/GBR-dhw/datasets/GBR_OISST_v2.1.nc")

# Crop the SST dataset to the grid point buffer
lizard_OISST <- sst_timeseries |> terra::crop(grid_point)

# Save the dataset to the `data/` directory in `.rda` format
usethis::use_data(lizard_OISST, overwrite = TRUE, compress = "bzip2")

# Print confirmation
cat("Dataset `lizard_OISST` has been saved successfully.\n")
