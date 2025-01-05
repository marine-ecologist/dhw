#' @name summarise_raster
#' @title Summarise rasters to year
#' @description
#' wrapper for tapp()
#'
#' Input rast requires time format (as.Date())
#' Options for index are time periods:
#' "years", "months", "yearmonths", "dekads", "yeardekads", "weeks" (the ISO 8601 week number, see tapp() for Details),
#' "yearweeks", "days", "doy" (day of the year), "7days" (seven-day periods starting at Jan 1 of each year), "10days", or "15days"
#' Fun as min, max, mean etc.
#'
#' @param input Input raster data.
#' @param index options for time, see above
#' @param fun summarise function see above)
#' @param cores number of cores, see tapp() for details
#' @param na.rm see tapp() for details
#' @param overwrite logical. If TRUE, filename is overwritten
#' @returns summarise raster
#' @examples
#' \dontrun{
#' noaa_dhw_file <- "https://pae-paha.pacioos.hawaii.edu/erddap/griddap/dhw_5km.nc?CRW_SST%5B(2024-12-20T12:00:00Z):1:(2024-12-25T12:00:00Z)%5D%5B(-8.9):1:(-25)%5D%5B(141):1:(153.5)%5D"
#' noaa_dhw_raster <- rast(noaa_dhw_file) |> flip() |> project("EPSG:4283")
#' tmp <- summarise_raster(noaa_dhw_raster, index="years", fun="min")
#' tmp
#' }
#' @export


summarise_raster <- function(input, index, fun, cores=1, na.rm=TRUE, overwrite){

  output <- terra::tapp(input, index = index, fun = fun, na.rm = na.rm, cores = cores, overwrite)

}
