


# Load Coraltemp, calculate Mean Monthly with calculate_monthly_mean

grid_area <- data.frame(longitude = 145.405, latitude = -14.655) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |>
  st_transform(4283) |>
  vect() |>
  buffer(width = 40000)

CoralTempSST_area <- rast("/Users/rof011/GBR-dhw/datasets/coraltemp/GBR_coraltemp_v3.1_sst.nc") |>
  crop(grid_area) |>
  project("EPSG:4283")


# Load Climatology
CoralTempDailyClimatology_area <- rast("/Users/rof011/GBR-dhw/datasets/coraltemp/ct5km_climatology_v3.1.nc") |>
  select(2:13) |>
  crop(grid_area) |>
  project("EPSG:4283")


# round extents
ext(CoralTempDailyClimatology_area) <- round(ext(CoralTempDailyClimatology_area),2)
ext(CoralTempSST_area) <- round(ext(CoralTempSST_area),2)

# get NOAA data to match the extent

crop_project_date <- function(input, grid_area, start_time, end_time){

  output <- unwrap(input) |> crop(grid_area) |>  project("EPSG:4283")
  ext(output) <- round(ext(output),2)
  time(output) <- as.Date(time(output))
  names(output) <- as.Date(time(output))
  output <- output[[time(output) >= as.Date(start_time) & time(output) <= as.Date(end_time)]]


}

NOAA_CRW_area_SST <- crop_project_date(NOAA_CRW_area_rast_SST, grid_area, "2015-09-01", "2016-09-01")
NOAA_CRW_area_SSTANOMALY <- crop_project_date(NOAA_CRW_area_rast_SSTANOMALY, grid_area, "2015-09-01", "2016-09-01")
NOAA_CRW_area_HOTSPOT <- crop_project_date(NOAA_CRW_area_rast_HOTSPOT, grid_area, "2015-09-01", "2016-09-01")
NOAA_CRW_area_DHW <- crop_project_date(NOAA_CRW_area_rast_DHW, grid_area, "2015-09-01", "2016-09-01")
NOAA_CRW_area_BAA <- crop_project_date(NOAA_CRW_area_rast_BAA, grid_area, "2015-09-01", "2016-09-01")


#time(NOAA_CRW_area_SST) <- time(NOAA_CRW_area_SST) |> as.Date()

CoralTempSST_area_subset <- CoralTempSST_area[[which(as.Date(time(CoralTempSST_area)) >= min(as.Date(time(NOAA_CRW_area_SST))) &
                         as.Date(time(CoralTempSST_area)) <= max(as.Date(time(NOAA_CRW_area_SST))))]]

calculated_mmm <- calculate_maximum_monthly_mean(mm = CoralTempDailyClimatology_area)
calculated_dc <- calculate_daily_climatology(sst_file = CoralTempSST_area_subset, mm = CoralTempDailyClimatology_area)
calculated_anomalies <- calculate_anomalies(sst_file = NOAA_CRW_area_SST, climatology = calculated_dc)
calculated_hotspots <- calculate_hotspots(mmm = calculated_mmm, sst_file = NOAA_CRW_area_SST)
calculated_dhw <- calculate_dhw(hotspots = calculated_hotspots)
calculated_baa <- calculate_baa(hotspots = calculated_hotspots, dhw = calculated_dhw)

#names(calculated_dhw) <- paste0("T-", names(calculated_dhw))
#names(calculated_anomalies) <- paste0("T-", names(calculated_anomalies))

ggplot() + theme_bw() +
  tidyterra::geom_spatraster(data=calculated_anomalies["2016-03-01"])


ggplot() + theme_bw() +
  tidyterra::geom_spatraster(data=NOAA_CRW_area_SSTANOMALY["2016-03-01"])
