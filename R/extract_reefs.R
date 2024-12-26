#' @name extract_reefs
#' @title Extract reef
#' @description
#' Function to extract sst data for shp file overlay
#'
#' See vignette for further details
#'
#' @param input input
#' @param output output format, sf default
#' @param shpfile location of shpfile mask
#' @param extract_fun = "weighted_mean" by default
#' @param quiet show verbose
#' @returns shp file sf with SST details (see above for details)
#' @examples
#' \dontrun{
#' output <- extract_reefs()
#' }
#' @export

extract_reefs <- function(input, output = "sf", shpfile, extract_fun = "weighted_mean", quiet=FALSE) {


  gbr_shape_import <- sf::st_read(shpfile, quiet = TRUE) |>
    dplyr::filter(FEAT_NAME == "Reef")

  gbr_shape <- gbr_shape_import |>
    dplyr::filter(!LABEL_ID %in% gbr_shape_import$LABEL_ID[duplicated(gbr_shape_import$LABEL_ID)])

  if (is.list(input)) {

    cat("--- extract_reefs ---\n")
    print_elapsed_time <- function(message) {
      elapsed <- Sys.time() - start_time
      cat(format(elapsed, digits = 2), " - ", message, "\n")
    }

    start_time <- Sys.time()

    combined_extracted <- list()

    for (layer_name in names(input)) {

      if (!quiet) {
        print_elapsed_time(paste0("Processing ", layer_name))
      }

      rasterfile <- terra::project(input[[layer_name]], sf::st_crs(gbr_shape)$wkt)

      time_steps <- terra::time(rasterfile)
      if (is.null(time_steps)) {
        stop("Time information is missing from the raster")
      }

      unique_layer_names <- paste0(layer_name, "_", time_steps)
      names(rasterfile) <- unique_layer_names

      gbr_extracted <- exactextractr::exact_extract(rasterfile, gbr_shape, fun = extract_fun, progress = FALSE, weights = "area", append_cols = "LOC_NAME_S")
      names(gbr_extracted) <- gsub("weighted_mean\\.", "", names(gbr_extracted))

      gbr_extracted_long <- gbr_extracted |>
        tidyr::pivot_longer(-LOC_NAME_S, values_to = layer_name, names_to = "time") |>
        dplyr::mutate(time = sub(".*_", "", time))

      combined_extracted[[layer_name]] <- gbr_extracted_long
    }

    combined_df <- Reduce(function(x, y) dplyr::left_join(x, y, by = c("LOC_NAME_S", "time")), combined_extracted)

    if (output == "sf") {

      if (!quiet) {
        print_elapsed_time("Merging outputs")
      }

      final_output <- dplyr::left_join(gbr_shape, combined_df, by = "LOC_NAME_S") |>
        dplyr::select(LOC_NAME_S, LABEL_ID, time, dplyr::everything())

      if (!quiet) {
        print_elapsed_time("Done")
      }
      return(final_output)
    } else if (output == "df") {
      if (!quiet) {
        print_elapsed_time("Done")
      }
      return(combined_df)
    }

  }

  else { # single use case

    gbr_extracted <- exact_extract(input, gbr_shape, fun = extract_fun, progress=FALSE, weights = "area", append_cols="LOC_NAME_S")
    names(gbr_extracted) <- gsub("weighted_mean\\.", "", names(gbr_extracted))

    if (output=="sf"){
      output <- left_join(gbr_shape, gbr_extracted)
      return(output)
    } else if (output=="df"){
      return(gbr_extracted)
    }


  }

}
