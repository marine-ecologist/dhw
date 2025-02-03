#' @name process_OISST
#' @title Download GBR spatial data
#' @description
#'
#'
#' function to download the GBR shape files (14.1mb in size, shp file format) via eReefs
#'
#' Notes:
#' There are several versions of the GBR reefs shape file. This version is downloaded via the eAtlas
#' Website and includes reefs from the Torres Strait. Default CRS is GDA94 (EPSG:4283)
#'
#'
#' @param input input folder
#' @param polygon polygon for crop/masl
#' @param crs change the CRS if needed (EPSG:4283 as default)
#' @param crop TRUE/FALSE
#' @param mask TRUE/FALSE
#' @param downsample TRUE/FALSE
#' @param res resolution for downsamlpling
#' @param variable redundant?
#' @param combinedfilename output file path, should be .rds
#' @returns terra::rast
#' @examples
#' \dontrun{
#'
#' GBR_hull <- download_gbr_spatial(return="hull", crs = "EPSG:7844")
#'
#' process_OISST(input = "/Volumes/Extreme_SSD/dhw/global",
#'                   polygon = GBR_hull, crs = "EPSG:7844",
#'                   combinedfilename = "/Volumes/Extreme_SSD/dhw/GBR_OISST_full.rds",
#'                   crop=TRUE, mask=TRUE, downsample=FALSE)
#'
#'
#' rast(unwrap("/Volumes/Extreme_SSD/dhw/GBR_CoralTemp_full.rds"))
#' rast(unwrap("/Volumes/Extreme_SSD/dhw/GBR_CoralTemp_full.rds"))[[1]] |> plot()
#'
#' }
#'
#' \dontrun{
#'
#' process_CoralTemp(input = "/Volumes/Extreme_SSD/dhw/coraltempdhw",
#'                   polygon = GBR_hull, crs = "EPSG:7844",
#'                   combinedfilename = "/Volumes/Extreme_SSD/dhw/GBR_CoralTempDHW_full.rds",
#'                   crop=TRUE, mask=TRUE, downsample=FALSE)
#'
#'
#' rast(unwrap("/Volumes/Extreme_SSD/dhw/GBR_CoralTempDHW_full.rds"))[[1]] |> plot()
#' rast(unwrap("/Volumes/Extreme_SSD/dhw/GBR_CoralTempDHW_full.rds"))
#'
#'}
#' @export
#'


process_OISST <-  function(input, polygon, crop=TRUE, mask=TRUE, downsample=FALSE, res=0.1, variable = "sst",  crs="EPSG:7844", combinedfilename = NULL){

  rlist <- list.files(path = input,
                      pattern = "\\.nc$",
                      recursive = TRUE,
                      full.names = TRUE)

  processed_rasters <- list()

  for (file in rlist) {

    r <- terra::rast(file)
    #r <- r[[4]] # get fourth var (anom_zlev=0, err_zlev=0, ice_zlev=0, sst_zlev=0)
    r <- r[['sst_zlev=0']]
    names(r) <- as.Date(terra::time(r))

    polygon <- polygon |> sf::st_transform(terra::crs(r))


    if (isTRUE(mask)){
      r <- terra::mask(r, polygon)
    }
    if (isTRUE(crop)){
      r <- terra::crop(r, polygon)
    }
    if (isTRUE(downsample)){
      target <- terra::rast(terra::ext(r), resolution = res, crs = terra::crs(r))
      r <- terra::resample(r, target, method = "bilinear")
    }

    processed_rasters <- c(processed_rasters, r)
    cat("Processed:", file, "\n")
  }

  cat("Combining rasters")

  combined_raster <- do.call(c, processed_rasters)
  terra::writeRaster(combined_raster, combinedfilename)

  cat("Combined raster saved to:", combinedfilename, "\n")


}
