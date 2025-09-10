#' @name download_gbr_spatial
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
#' @param crs change the CRS if needed (EPSG:4283 as default)
#' @param return One of "combined", "hull", or "base"
#' @returns Simple feature collection with 9612 features and 35 fields
#' @examples
#' \dontrun{
#' eAtlas <- download_gbr_spatial(crs=4326)
#'}
#' @export

#' @name download_gbr_spatial
#' @title Download GBR spatial data
#' @description Download GBR (incl. Torres Strait) shapefiles and return base, combined (dissolved by LABEL_ID), hull, or outline.
#' @param crs Target CRS (EPSG code as integer or string like "EPSG:4283"). Default 4283 (GDA94).
#' @param return One of "combined", "hull", "outline", or "base"
#' @returns sf object
#' @export
download_gbr_spatial <- function(return = "base", crs = 4283) {
  # -------- helpers --------
  .target_epsg <- function(x) {
    if (inherits(x, "crs")) return(x)
    x <- as.character(x)
    x <- gsub("^EPSG:", "", x, ignore.case = TRUE)
    sf::st_crs(as.integer(x))
  }
  target_crs <- .target_epsg(crs)
  ea_crs <- sf::st_crs(3577)  # GDA94 / Australian Albers (equal-area in meters)

  # -------- download --------
  url <- "https://nextcloud.eatlas.org.au/s/xQ8neGxxCbgWGSd/download/TS_AIMS_NESP_Torres_Strait_Features_V1b_with_GBR_Features.zip"
  temp_zip <- file.path(tempdir(), "TS_AIMS_NESP_Torres_Strait_Features.zip")
  temp_dir <- file.path(tempdir(), "unzipped_files")

  message("Downloading spatial data...")
  resp <- httr::GET(url, httr::write_disk(temp_zip, overwrite = TRUE))
  httr::stop_for_status(resp)

  if (!dir.exists(temp_dir)) dir.create(temp_dir, recursive = TRUE)
  utils::unzip(temp_zip, exdir = temp_dir)

  shp <- list.files(temp_dir, pattern = "\\.shp$", full.names = TRUE)
  if (length(shp) == 0) stop("No shapefile (.shp) found in the unzipped files.")

  message("Reading shapefile...")
  gbr_shape <- sf::st_read(shp, quiet = TRUE)

  # If source CRS is missing, assume 4283 as per eAtlas metadata
  if (is.na(sf::st_crs(gbr_shape))) gbr_shape <- sf::st_set_crs(gbr_shape, 4283)

  # Always keep a clean, valid geometry set
  gbr_shape <- sf::st_make_valid(gbr_shape)

  # Return: base (just transformed)
  if (return == "base") {
    return(sf::st_transform(gbr_shape, target_crs))
  }

  # Return: outline (largest polygon by area, in equal-area CRS)
  if (return == "outline") {
    outline <- gbr_shape |>
      sf::st_transform(ea_crs) |>
      dplyr::slice_max(order_by = sf::st_area(.), n = 1) |>
      sf::st_transform(target_crs)
    return(outline)
  }

  # Return: combined (union by LABEL_ID, name via largest area feature)
  if (return == "combined") {
    gbr_files <- gbr_shape
    # Normalize IDs (extract XX-XXX)
    gbr_files$LABEL_ID_FULL <- gbr_files$LABEL_ID
    gbr_files$LABEL_ID <- stringr::str_extract(gbr_files$LABEL_ID_FULL, "^\\d{2}-\\d{3}")

    # choose name per LABEL_ID by largest area (equal-area)
    label_ids <- gbr_files |>
      dplyr::filter(.data$FEAT_NAME %in% c("Reef", "Terrestrial Reef", "Island", "Rock", "Bank")) |>
      sf::st_transform(ea_crs) |>
      dplyr::mutate(.area_m2 = sf::st_area(.)) |>
      dplyr::as_tibble() |>
      dplyr::select(LABEL_ID, GBR_NAME, .area_m2) |>
      dplyr::group_by(LABEL_ID) |>
      dplyr::slice_max(order_by = .data$.area_m2, n = 1, with_ties = FALSE) |>
      dplyr::ungroup() |>
      dplyr::select(-.area_m2)

    # dissolve by LABEL_ID
    combined <- gbr_files |>
      dplyr::group_by(LABEL_ID) |>
      dplyr::summarise(geometry = sf::st_union(geometry), .groups = "drop") |>
      dplyr::left_join(label_ids, by = "LABEL_ID") |>
      dplyr::mutate(
        GBR_NAME = stringr::str_remove(.data$GBR_NAME, " \\(Lagoon\\)")
      ) |>
      sf::st_transform(ea_crs) |>
      dplyr::mutate(area_m2 = as.numeric(sf::st_area(.))) |>
      sf::st_transform(target_crs)

    return(combined)
  }

  # Return: hull (concave hull of reef polygons, buffered 1km; compute in meters)
  if (return == "hull") {
    hull <- gbr_shape |>
      dplyr::filter(.data$FEAT_NAME %in% c("Reef", "Terrestrial Reef")) |>
      sf::st_transform(ea_crs) |>
      concaveman::concaveman() |>
      sf::st_make_valid() |>
      sf::st_buffer(1000) |>     # 1 km buffer in meters
      sf::st_transform(target_crs)
    return(hull)
  }

  stop('`return` must be one of "base", "combined", "hull", "outline".')
}
