## Script to prepare `lizard_crw` dataset
## access with:
# fpath <- system.file("extdata", "lizard_crw.tif", package="dhw")

# Load required libraries
library(dplyr)
library(sf)
library(terra)
library(usethis)
library(rerddap)


# set spatial ext

grid_area <- data.frame(longitude = 145.405, latitude = -14.655) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |>
  vect() |>
  buffer(width = 40000)


# download NOAA data to match the extent

NOAA_CRW_area <- griddap(
  datasetx = 'NOAA_DHW',
  time = c("2015-09-01", "2016-09-01"),
  longitude = c(ext(grid_area)[1], ext(grid_area)[2]),
  latitude = c(ext(grid_area)[3], ext(grid_area)[4]),
  fields = c('CRW_SST', 'CRW_SSTANOMALY', 'CRW_HOTSPOT', 'CRW_DHW', 'CRW_BAA'),
  fmt = "nc"
)


NOAA_CRW_area_rast <- rast("/var/folders/y9/9hk07gw12mj0hv3xvsfx4w400000gn/T//RtmprZqkSm/R/rerddap/782b95fd187fb9c4ee547e1c1e9d31be.nc")
NOAA_CRW_area_rast_SST <- subset(NOAA_CRW_area_rast, grep("CRW_SST_", names(NOAA_CRW_area_rast)))


NOAA_CRW_area_rast_SST <- wrap(NOAA_CRW_area_rast_SST)
NOAA_CRW_area_rast_SSTANOMALY <- wrap(NOAA_CRW_area_rast["CRW_SSTANOMALY"])
NOAA_CRW_area_rast_HOTSPOT <- wrap(NOAA_CRW_area_rast["CRW_HOTSPOT"])
NOAA_CRW_area_rast_DHW <- wrap(NOAA_CRW_area_rast["CRW_DHW"])
NOAA_CRW_area_rast_BAA <- wrap(NOAA_CRW_area_rast["CRW_BAA"])


usethis::use_data(NOAA_CRW_area_rast_SST)
usethis::use_data(NOAA_CRW_area_rast_SSTANOMALY)
usethis::use_data(NOAA_CRW_area_rast_HOTSPOT)
usethis::use_data(NOAA_CRW_area_rast_DHW)
usethis::use_data(NOAA_CRW_area_rast_BAA)
