#' Process CoralTemp NetCDF files into a combined raster
#'
#' This function reads, crops, masks, and (optionally) downsamples CoralTemp
#' NetCDF (.nc) files, then combines them into a single raster stack.
#' Processing can be done sequentially with \code{lapply} or in parallel with
#' \code{future.apply::future_lapply}.
#'
#' @param input Character. Path to directory containing .nc files.
#' @param polygon \code{sf} polygon object used for cropping/masking.
#' @param crop Logical. If TRUE, crop rasters to polygon extent. Default TRUE.
#' @param mask Logical. If TRUE, mask rasters by polygon. Default TRUE.
#' @param downsample Logical. If TRUE, resample rasters to coarser resolution. Default FALSE.
#' @param res Numeric. Resolution for downsampling. Default 0.1.
#' @param variable Character. Variable name (currently unused placeholder). Default "sst".
#' @param crs Character. Target CRS for final raster (e.g., "EPSG:7844").
#' @param combinedfilename Character. Output file path (.tif or .rds).
#' @param mc.cores Integer or NULL. Number of cores for parallel processing.
#'        If NULL, sequential \code{base::lapply} is used. Default 1.
#' @param silent Logical. If FALSE, print messages when files are processed.
#'
#' @return Writes a combined raster file to \code{combinedfilename}. Invisibly returns \code{TRUE}.
#' @export
#'
#' @examples
#' \dontrun{
#' process_CoralTemp(
#'   input = "data/CoralTemp/",
#'   polygon = sf::st_read("gbr_polygon.shp"),
#'   combinedfilename = "outputs/CoralTemp_combined.tif",
#'   mc.cores = 4,
#'   silent = FALSE
#' )
#' }

process_CoralTemp <- function (input, polygon, crop = TRUE, mask = TRUE, downsample = FALSE,
                               res = 0.1, variable = "sst", crs = "EPSG:7844", combinedfilename = NULL,
                               mc.cores = 1, silent = TRUE)
{
  process_file <- function(file, polygon, crop, mask, downsample, res, silent) {
    r <- try(terra::rast(file), silent = TRUE)
    if (inherits(r, "try-error"))
      return(NULL)
    r <- r[[1]]
    names(r) <- base::as.Date(terra::time(r))
    poly_t <- sf::st_transform(polygon, terra::crs(r))
    if (isTRUE(mask))
      r <- terra::mask(r, poly_t)
    if (isTRUE(crop))
      r <- terra::crop(r, poly_t)
    if (isTRUE(downsample)) {
      target <- terra::rast(terra::ext(r), resolution = res, crs = terra::crs(r))
      r <- terra::resample(r, target, method = "bilinear")
    }
    tempfile_name <- base::file.path(tempdir(), paste0("ct_", basename(file), ".tif"))
    terra::writeRaster(r, filename = tempfile_name, overwrite = TRUE)
    if (!silent) base::cat("processed", tempfile_name, "\n")
    return(tempfile_name)
  }

  rlist <- base::list.files(path = input, pattern = "\\.nc$", recursive = TRUE, full.names = TRUE)
  base::cat("Processing using", ifelse(is.null(mc.cores), "sequential lapply", paste(mc.cores, "cores")), "\n")

  if (is.null(mc.cores)) {
    tempfiles <- base::lapply(
      rlist,
      function(f) process_file(f, polygon, crop, mask, downsample, res, silent)
    )
  } else {
    future::plan(future::multisession, workers = mc.cores)
    tempfiles <- future.apply::future_lapply(
      rlist,
      function(f) process_file(f, polygon, crop, mask, downsample, res, silent),
      future.seed = TRUE
    )
  }

  tempfiles <- base::Filter(Negate(is.null), tempfiles)
  if (length(tempfiles) == 0)
    stop("No rasters processed successfully.")

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
  if (length(raster_list) == 0)
    stop("All temp rasters failed to load.")

  combined_raster <- base::do.call(c, raster_list)
  combined_raster <- terra::project(combined_raster, crs)

  if (grepl("\\.rds$", combinedfilename)) {
    base::saveRDS(terra::wrap(combined_raster), combinedfilename)
  } else {
    terra::writeRaster(combined_raster, filename = combinedfilename, overwrite = TRUE)
  }

  base::cat("Combined raster saved to:", combinedfilename, "\n")
  base::unlink(tempfiles)
  invisible(TRUE)
}
