#' @name extract_reefs
#' @title Extract reef
#' @description
#' Function to extract SST data for shapefile overlay.
#' Processing large daily datasets output in sf may result in significant lag due to tidyverse
#' pivot_longer approach (i.e. 365 days results in an sf with 1357104 rows). Alternative approach
#' implemented earlier (looping over time periods) is still slow - to be refined later.
#'
#' See vignette for further details
#'
#' @param input Input raster data.
#' @param output Output format, "sf" (default) or "df".
#' @param shpfile Location of shapefile mask.
#' @param weights see ?exact_extract for details
#' @param fun  see ?exact_extract for details
#' @param timeseries time series
#' @param varname varname
#' @returns Shapefile `sf` object with SST details or `data.frame` (see above for details).
#' @examples
#'
#
#' \dontrun{
#'
#'
#' #### annual data
#' ecmwfr_combined <- process_ERA5("/Users/rof011/GBR-dhw/datasets/era5/")
#' gbr_era5_annual_max <- summarise_raster(ecmwfr_combined, index = "years", fun = max, na.rm = TRUE)
#' gbr_era5_sf_annual_max <- extract_reefs(gbr_era5_annual_max, gbr_files, output="sf", weights="area", fun="mean")
#'
#' ### daily data for 2024 only
#' ecmwfr_2024 <- ecmwfr_combined[[format(terra::time(ecmwfr_combined), "%Y") == "2024"]]
#' gbr_era5_sf_2024 <- extract_reefs(ecmwfr_2024, gbr_files, output="sf", weights="area", fun="mean")
#'
#'
#' ### ERA5 climatology
#' ecmwfr_combined <- process_ERA5("/Users/rof011/GBR-dhw/datasets/era5/")
#' ecmwfr_climatology <- create_climatology(ecmwfr_combined, baa=FALSE)
#'
#' ###### DHW
#'
#' ### maxDHW per year for era5 in rast
#' gbr_era5_dhw_annual_max <- summarise_raster(ecmwfr_climatology$dhw, index = "years", fun = max, na.rm = TRUE)
#'
#' ggplot() + theme_bw() +
#'  facet_wrap(~lyr, ncol=10) +
#'  tidyterra::geom_spatraster(data=gbr_era5_dhw_annual_max) +
#'  scale_fill_distiller(palette="Reds", direction=1)
#'
#'
#' ### annual mean reef-average maxDHW
#' gbr_era5_dhw_mean_annual_max <- extract_reefs(gbr_era5_dhw_annual_max, gbr_files, output="df", varname="dhw", weights="area", fun="mean")
#'
#' gbr_era5_dhw_mean_annual_max_summarised <- gbr_era5_dhw_mean_annual_max |>
#'   group_by(date) |>
#'   summarise(dhw = mean(dhw, na.rm=TRUE))
#'
#'
#' ggplot() + theme_bw() +
#'  geom_vline(xintercept=c("1998", "2002", "2016", "2017", "2020", "2022", "2024"), linewidth=2, alpha=0.2) +
#'  geom_col(data=gbr_era5_dhw_mean_annual_max_summarised, aes(x=date, y=dhw, fill=dhw), color="black", show.legend=FALSE) +
#'  scale_fill_distiller(palette="Reds", direction=1)
#'
#'
#' ###### SST
#'
#' ### maxSST per year for era5 in rast
#' gbr_era5_sst_annual_max <- summarise_raster(ecmwfr_climatology$sst, index = "years", fun = max, na.rm = TRUE)
#'
#' ggplot() + theme_bw() +
#'   facet_wrap(~lyr, ncol=10) +
#'   tidyterra::geom_spatraster(data=gbr_era5_sst_annual_max) +
#'   scale_fill_distiller(palette="RdBu")
#'
#'
#' ### annual mean reef-average SST
#' gbr_era5_SST_mean_annual_max <- extract_reefs(gbr_era5_sst_annual_max, gbr_files, output="df", varname="sst", weights="area", fun="mean")
#'
#' gbr_era5_sst_mean_annual_max_summarised <- gbr_era5_SST_mean_annual_max |>
#'   group_by(date) |>
#'   summarise(sst = mean(sst, na.rm=TRUE)) |>
#'   mutate(date=as.numeric(date))
#'
#'
#' ggplot() + theme_bw() +
#'   geom_vline(xintercept=c(1998, 2002, 2016, 2017, 2020, 2022, 2024), linewidth=2, alpha=0.2) +
#'   geom_point(data=gbr_era5_sst_mean_annual_max_summarised, aes(x=date, y=sst, fill=sst),
#'              color="black", show.legend=FALSE, shape=21) +
#'   geom_smooth(data=gbr_era5_sst_mean_annual_max_summarised, aes(x=date, y=sst), method = "lm") +
#'   scale_fill_distiller(palette="RdBu", direction=-1) +
#'   coord_cartesian(ylim = c(28,30))
#'
#'
#' ###### SSTanom
#'
#' ### meanSSTanom per year for era5 in rast
#' gbr_era5_sstanom_annual_max <- summarise_raster(ecmwfr_climatology$anomaly, index = "years", fun = mean, na.rm = TRUE)
#'
#' ggplot() + theme_bw() +
#'   facet_wrap(~lyr, ncol=10) +
#'   tidyterra::geom_spatraster(data=gbr_era5_sstanom_annual_max) +
#'   scale_fill_distiller(palette="RdBu")
#'
#'
#' ### annual mean reef-average SST
#' gbr_era5_SSTanom_mean_annual_max <- extract_reefs(gbr_era5_sstanom_annual_max, gbr_files, output="df", varname="sstanom", weights="area", fun="mean")
#'
#' gbr_era5_sstanom_mean_annual_max_summarised <- gbr_era5_SSTanom_mean_annual_max |>
#'   group_by(date) |>
#'   summarise(sstanom = mean(sstanom, na.rm=TRUE)) |>
#'   mutate(date=as.numeric(date))
#'
#'
#' ggplot() + theme_bw() +
#'   geom_vline(xintercept=c(1998, 2002, 2016, 2017, 2020, 2022, 2024), linewidth=2, alpha=0.2) +
#'   geom_line(data=gbr_era5_sstanom_mean_annual_max_summarised, aes(x=date, y=sstanom),
#'             color="black", show.legend=FALSE) +
#'   geom_smooth(data=gbr_era5_sstanom_mean_annual_max_summarised, aes(x=date, y=sstanom), method = "lm", alpha=0.2) +
#'   scale_fill_distiller(palette="RdBu", direction=-1) +
#'   geom_hline(yintercept=0, lwd=0.4)
#' #coord_cartesian(ylim = c(28,30))
#'
#'
#' }
#' @export
extract_reefs <- function(input, shpfile, output = "sf", fun = "mean", weights = "area", timeseries = "daily", varname = "sst", silent = TRUE) {

  # Reproject the input raster to match the shapefile CRS
  input <- terra::project(input, sf::st_crs(shpfile)$wkt)
  names(input) <- terra::time(input)

  # Perform exact extraction
  extracted_output <- exactextractr::exact_extract(
    input, shpfile, progress = !silent, fun = fun, weights = weights,
    append_cols = c("LABEL_ID", "GBR_NAME")
  )

  # Pivot longer with user-defined varname
  output_file <- extracted_output |>
    tidyr::pivot_longer(
      cols = -c("LABEL_ID", "GBR_NAME"),
      names_to = "date",
      values_to = varname # Use custom variable name
    ) |>
    dplyr::mutate(date = sub("^mean\\.", "", date)) # Clean date format

  # Handle output type (sf or data.frame)
  if (output == "sf") {
    output_file <- shpfile %>%
      dplyr::left_join(., output_file, by = c("LABEL_ID", "GBR_NAME"))
  }

  return(output_file)
}
