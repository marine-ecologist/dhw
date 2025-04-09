#' @title Download Latest OISST and process outputs
#' @description Downloads the most recent `.nc` file for OISST
#' converts to DHW
#'
#' @param dataset Character. One of `"sst"`, `"ssta"`, `"dhw"`, `"hs"`, `"baa"`, or `"all"`.
#' @param folder Character. Local directory where files will be saved.
#' @param reefs shp file input, use dhw::download_gbr_spatial(return = "hull", crs = "EPSG:7844")
#'
#' @return Downloads the latest file(s) to the specified folder.
#' @export
#'
#' @examples
#' \dontrun{
#' GBR_hull = download_gbr_spatial(return = "hull", crs = "EPSG:7844")
#' remote_download_CoralTemp(dataset = "sst", folder = "data/", reefs = GBR_hull)
#' remote_download_CoralTemp(dataset = "all", folder = "data/", reefs = GBR_hull)
#' }

remote_download_OISST<- function(folder = ".",
                                      reefs = GBR_hull,
                                      quiet = FALSE) {

  year_month <- format(Sys.Date(), "%Y%m")
  listing_url <- paste0(base_url, year_month, "/")

  html <- xml2::read_html(listing_url)
  hrefs <- rvest::html_attr(rvest::html_nodes(html, "a"), "href")
  nc_files <- grep("\\.nc$", hrefs, value = TRUE)

  # Get most recent _preliminary file
  prelim_files <- grep("_preliminary\\.nc$", nc_files, value = TRUE)
  if (length(prelim_files) == 0) {
    message("No preliminary files found.")
    return(invisible(NULL))
  }

  # Extract dates and find most recent
  dates <- as.Date(sub(".*\\.(\\d{8})_preliminary\\.nc$", "\\1", prelim_files), format = "%Y%m%d")
  latest_index <- which.max(dates)
  latest_prelim <- prelim_files[latest_index]
  latest_date <- format(dates[latest_index], "%Y%m%d")
  verified_file <- paste0("oisst-avhrr-v02r01.", latest_date, ".nc")

  # Full paths
  dest_prelim <- file.path(folder, latest_prelim)
  dest_verified <- file.path(folder, verified_file)

  # Skip if verified file already exists
  if (file.exists(dest_verified)) {
    message("Verified version already exists: ", verified_file)
    return(invisible(NULL))
  }

  # Skip if already downloaded
  if (file.exists(dest_prelim)) {
    message("Preliminary already downloaded: ", latest_prelim)
  } else {
    # Download preliminary file
    download_url <- paste0(listing_url, latest_prelim)
    message("Downloading: ", download_url)
    utils::download.file(download_url, destfile = dest_prelim, mode = "wb")
  }

  # Check for older preliminary files that now have verified versions
  local_prelim_files <- list.files(folder, pattern = "_preliminary\\.nc$", full.names = TRUE)
  for (f in local_prelim_files) {
    prelim_date <- sub(".*\\.(\\d{8})_preliminary\\.nc$", "\\1", basename(f))
    verified <- file.path(folder, paste0("oisst-avhrr-v02r01.", prelim_date, ".nc"))
    if (file.exists(verified)) {
      file.remove(f)
      message("Removed obsolete preliminary file: ", basename(f))
    }
  }


  # Crop to GBR extent
  latest_dataset_gbr <- paste0("GBR_", latest_dataset)
  dest_path_gbr <- file.path(folder, latest_dataset_gbr)

  if (!file.exists(dest_path_gbr)) {

    r <- terra::rast(dest_path)[[1]]
    names(r) <- as.Date(terra::time(r))

    polygon <- sf::st_transform(reefs, terra::crs(r))

    # if (isTRUE(mask)) {
    r <- terra::mask(r, polygon)
    #  cat("Masking raster - ")
    #}

    # if (isTRUE(crop)) {
    r <- terra::crop(r, polygon)
    #  cat("Cropping raster - ")
    #}

    #if (isTRUE(downsample)) {
    #  target <- terra::rast(terra::ext(r), resolution = res, crs = terra::crs(r))
    #  r <- terra::resample(r, target, method = "bilinear")
    #  cat("Resampling raster - ")
    #}

    r <- terra::project(r, sf::st_crs(reefs)[1]$input)
    if (!isTRUE(quiet)){
      message(paste0("Downloaded global .nc: [", latest_dataset, "]"))
      message(paste0("Extracted GBR subset .nc [", latest_dataset_gbr, "]"))
      message("--------------------------------------------------------")
    }
    terra::writeCDF(r, dest_path_gbr, overwrite = TRUE)

  } else {
    message(var, " already exists: ", latest_dataset_gbr)
  }






  invisible(NULL)



}
