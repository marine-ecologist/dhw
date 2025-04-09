#' @title Download Latest CoralTemp Dataset(s) from NOAA THREDDS Server
#' @description Downloads the most recent `.nc` file for selected CoralTemp variable(s)
#' from NOAA's THREDDS server into a local folder. Automatically skips download if the file exists.
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

remote_download_CoralTemp <- function(dataset = "all",
                                      folder = ".",
                                      reefs = GBR_hull,
                                      quiet = FALSE) {
  dataset <- match.arg(dataset)
  year <- format(Sys.Date(), "%Y")
  vars <- if (dataset == "all") c("sst", "ssta", "dhw", "hs", "baa") else dataset

  lapply(vars, function(var) {
    catalog_url <- paste0(
      "https://www.ncei.noaa.gov/thredds-ocean/catalog/crw/5km/v3.1/nc/v1.0/daily/",
      var, "/", year, "/catalog.xml"
    )

    catalog <- thredds::CatalogNode$new(catalog_url)
    datasets <- catalog$list_datasets()

    dataset_names <- names(datasets)
    dates <- as.Date(gsub(".*_(\\d{8})\\.nc$", "\\1", dataset_names), format = "%Y%m%d")
    latest_index <- which.max(dates)
    latest_dataset <- dataset_names[latest_index]

    download_url <- paste0(
      "https://www.ncei.noaa.gov/thredds-ocean/fileServer/crw/5km/v3.1/nc/v1.0/daily/",
      var, "/", year, "/", latest_dataset
    )

    dest_path <- file.path(folder, latest_dataset)

    if (!file.exists(dest_path)) {
      #message("Downloading: ", latest_dataset)
      utils::download.file(download_url, destfile = dest_path, quiet=TRUE, mode = "wb")
    } else {
      message(var, " already exists: ", latest_dataset)
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
  })

  invisible(NULL)
}
