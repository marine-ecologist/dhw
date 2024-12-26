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
#' @param reefs Combine reefs to single LABEL_ID? See vignette
#' @returns Simple feature collection with 9612 features and 35 fields
#' @examples
#' \dontrun{
#' eAtlas <- download_gbr_spatial(crs=4326)
#'}
#' @export



download_gbr_spatial <- function(crs = "EPSG:4283", reefs) {
  # URL for the spatial data
  url <- "https://nextcloud.eatlas.org.au/s/xQ8neGxxCbgWGSd/download/TS_AIMS_NESP_Torres_Strait_Features_V1b_with_GBR_Features.zip"

  # Temporary file paths
  temp_zip <- file.path(tempdir(), "TS_AIMS_NESP_Torres_Strait_Features.zip")
  temp_dir <- file.path(tempdir(), "unzipped_files")

  # Download the ZIP file
  message("Downloading spatial data...")
  httr::GET(url, httr::write_disk(temp_zip, overwrite = TRUE))

  # Create output directory for unzipped files
  if (!dir.exists(temp_dir)) {
    dir.create(temp_dir)
  }

  # Unzip the downloaded file
  utils::unzip(temp_zip, exdir = temp_dir)

  # Identify the shapefile path
  shapefile_path <- list.files(
    temp_dir,
    pattern = "\\.shp$",
    full.names = TRUE
  )

  if (length(shapefile_path) == 0) {
    stop("No shapefile (.shp) found in the unzipped files.")
  }

  # Load and transform the shapefile
  message("Reading and transforming shapefile...")
  gbr_shape <- sf::st_read(shapefile_path, quiet = TRUE) |>
    sf::st_transform(crs)

  if (reefs=="combined"){

    gbr_files <- gbr_shape |> st_transform(4283)
    gbr_files$LABEL_ID_FULL <- gbr_files$LABEL_ID
    gbr_files$LABEL_ID <- stringr::str_extract(gbr_files$LABEL_ID_FULL, "^\\d{2}-\\d{3}")

    label_ids <- gbr_files |>
      filter(FEAT_NAME %in% c("Reef", "Terestrial Reef")) |>
      as.data.frame() |>
      select(LABEL_ID, GBR_NAME) |>
      group_by(LABEL_ID) |>
      filter(row_number() == 1)
    #filter(GBR_NAME==first(GBR_NAME))


    gbr_shape <- gbr_files |>
      filter(FEAT_NAME %in% c("Reef", "Terestrial Reef")) |>
      st_make_valid() |>
      group_by(LABEL_ID) |>
      summarize(geometry = st_union(geometry)) |>
      ungroup() |>
      left_join(label_ids, by="LABEL_ID") %>%
      mutate(area = st_area(.))

    return(gbr_shape)

  } else {

  return(gbr_shape)

  }

}
