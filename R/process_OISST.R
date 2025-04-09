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
#' @param mc.cores number of cores, defaults to 1
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

process_OISST <- function(input, polygon, crop = TRUE, mask = TRUE, downsample = FALSE,
                          res = 0.1, variable = "sst", crs = "EPSG:7844",
                          combinedfilename = NULL, mc.cores = 1) {

  process_year <- function(year_dir, polygon, crop, mask, downsample, res, variable) {
    rlist <- base::list.files(path = year_dir, pattern = "\\.nc$", recursive = TRUE, full.names = TRUE)
    processed_rasters <- list()
    for (file in rlist) {
      base::cat("Reading file:", file, "\n")
      r <- try(terra::rast(file), silent = TRUE)
      if (inherits(r, "try-error")) next

      varname <- paste0(variable, "_zlev=0")
      if (!(varname %in% names(r))) {
        base::cat("Skipping:", file, " — variable not found\n")
        next
      }

      r <- r[[varname]]
      base::names(r) <- base::as.Date(terra::time(r))
      poly_t <- sf::st_transform(polygon, terra::crs(r))
      if (isTRUE(mask)) r <- terra::mask(r, poly_t)
      if (isTRUE(crop)) r <- terra::crop(r, poly_t)
      if (isTRUE(downsample)) {
        target <- terra::rast(terra::ext(r), resolution = res, crs = terra::crs(r))
        r <- terra::resample(r, target, method = "bilinear")
      }
      processed_rasters <- base::c(processed_rasters, r)
      base::cat("Processed:", file, "\n")
    }

    if (length(processed_rasters) == 0) return(NULL)

    year_combined <- base::do.call(c, processed_rasters)
    tempfile_name <- base::file.path(tempdir(), paste0("year_", basename(year_dir), ".tif"))
    terra::writeRaster(year_combined, filename = tempfile_name, overwrite = TRUE)
    return(tempfile_name)
  }

  subdirs <- base::list.dirs(input, full.names = TRUE, recursive = FALSE)
  if (length(subdirs) == 0) subdirs <- input

  base::cat("Processing in parallel using", mc.cores, "cores\n")
  tempfiles <- parallel::mclapply(
    subdirs,
    function(d) process_year(d, polygon, crop, mask, downsample, res, variable),
    mc.cores = mc.cores
  )

  tempfiles <- base::Filter(Negate(is.null), tempfiles)
  if (length(tempfiles) == 0) stop("No rasters processed successfully.")

  base::cat("Reading and combining temporary rasters\n")

  raster_list <- base::lapply(tempfiles, function(f) {
  r <- try(terra::rast(f), silent = TRUE)
  if (inherits(r, "try-error")) {
    base::cat("Failed to read:", f, "\n")
    return(NULL)
  }
  r
})
raster_list <- base::Filter(Negate(is.null), raster_list)
if (length(raster_list) == 0) stop("All temp rasters failed to load.")
  combined_raster <- base::do.call(c, raster_list)

  if (grepl("\\.rds$", combinedfilename)) {
    base::saveRDS(terra::wrap(combined_raster), combinedfilename)
  } else {
    terra::writeRaster(combined_raster, filename = combinedfilename, overwrite = TRUE)
  }

  base::cat("Combined raster saved to:", combinedfilename, "\n")

  base::unlink(tempfiles)
}
