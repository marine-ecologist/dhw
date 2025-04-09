#' @name process_CoralTemp
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
#' @param input Input folder with .nc files (flat structure, no per-year dirs)
#' @param polygon sf polygon to crop/mask
#' @param crs Output CRS (default EPSG:7844)
#' @param crop TRUE/FALSE to crop
#' @param mask TRUE/FALSE to mask
#' @param downsample TRUE/FALSE to resample to coarser resolution
#' @param res Resolution for downsampling (default 0.1)
#' @param variable Ignored (first band used always)
#' @param combinedfilename Output file path (.tif or .rds recommended)
#' @param mc.cores Number of cores (default 1)
#' @returns terra::SpatRaster
#' @export

process_CoralTemp <- function(input, polygon, crop = TRUE, mask = TRUE, downsample = FALSE,
                              res = 0.1, variable = "sst", crs = "EPSG:7844",
                              combinedfilename = NULL, mc.cores = 1) {

  process_file <- function(file, polygon, crop, mask, downsample, res) {
    r <- try(terra::rast(file), silent = TRUE)
    if (inherits(r, "try-error")) return(NULL)

    r <- r[[1]]
    names(r) <- base::as.Date(terra::time(r))
    poly_t <- sf::st_transform(polygon, terra::crs(r))
    if (isTRUE(mask)) r <- terra::mask(r, poly_t)
    if (isTRUE(crop)) r <- terra::crop(r, poly_t)
    if (isTRUE(downsample)) {
      target <- terra::rast(terra::ext(r), resolution = res, crs = terra::crs(r))
      r <- terra::resample(r, target, method = "bilinear")
    }

    tempfile_name <- base::file.path(tempdir(), paste0("ct_", basename(file), ".tif"))
    terra::writeRaster(r, filename = tempfile_name, overwrite = TRUE)
    return(tempfile_name)
  }

  rlist <- base::list.files(path = input, pattern = "\\.nc$", recursive = TRUE, full.names = TRUE)

  base::cat("Processing in parallel using", mc.cores, "cores\n")
  tempfiles <- parallel::mclapply(
    rlist,
    function(f) process_file(f, polygon, crop, mask, downsample, res),
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
  combined_raster <- terra::project(combined_raster, crs)

  if (grepl("\\.rds$", combinedfilename)) {
    base::saveRDS(terra::wrap(combined_raster), combinedfilename)
  } else {
    terra::writeRaster(combined_raster, filename = combinedfilename, overwrite = TRUE)
  }

  base::cat("Combined raster saved to:", combinedfilename, "\n")
  base::unlink(tempfiles)
}
