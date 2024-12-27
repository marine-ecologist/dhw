#' @name extract_reefs
#' @title Extract reef
#' @description
#' Function to extract SST data for shapefile overlay
#'
#' See vignette for further details
#'
#' @param input Input raster data.
#' @param output Output format, "sf" (default) or "df".
#' @param shpfile Location of shapefile mask.
#' @param extract_fun Extraction function, "weighted_mean" by default.
#' @param quiet Logical, suppress verbose output (default = FALSE).
#' @returns Shapefile `sf` object with SST details or `data.frame` (see above for details).
#' @examples
#' \dontrun{
#' noaa_dhw_file <- "https://pae-paha.pacioos.hawaii.edu/erddap/griddap/dhw_5km.nc?CRW_SST%5B(2024-12-20T12:00:00Z):1:(2024-12-25T12:00:00Z)%5D%5B(-8.9):1:(-25)%5D%5B(141):1:(153.5)%5D"
#' noaa_dhw_raster <- rast(noaa_dhw_file) |> flip() |> project("EPSG:4283")
#' tmp <- extract_reefs(input = noaa_dhw_raster, shpfile = gbr_files)
#' tmp
#' }
#' @export

extract_reefs <- function(input, shpfile, output = "sf", extract_fun = "weighted_mean", quiet = FALSE) {
  # Ensure CRS matches
  input <- terra::project(input, sf::st_crs(shpfile)$wkt)
  time_steps <- terra::time(input)

  # Check for time data
  if (is.null(time_steps)) {
    stop("Time information is missing from the raster.")
  }

  # Initialize timer
  start_time <- Sys.time()
  print_elapsed_time <- function(message) {
    elapsed <- Sys.time() - start_time
    cat(format(elapsed, digits = 2), " - ", message, "\n")
  }

  # Initialize output
  combined_extracted <- NULL

  # Process layers using a for-loop for speed
  for (i in seq_len(nlyr(input))) {
    # Extract time step
    timestep <- as.Date(time(input[[i]]))

    if (!quiet) {
      print_elapsed_time(paste0("Extracting ", i, "/", length(time_steps), " [", timestep, "]"))
    }

    # Perform extraction
    extracted <- shpfile |>
      mutate(
        date = rep(timestep, nrow(shpfile)),
        sst = exactextractr::exact_extract(
          input[[i]], shpfile, progress = FALSE,
          fun = extract_fun, weights = "area"
        )
      )

    # Combine results
    if (is.null(combined_extracted)) {
      combined_extracted <- extracted
    } else {
      combined_extracted <- rbind(combined_extracted, extracted)
    }
  }

  # Final output based on format
  if (output == "sf") {
    if (!quiet) {
      print_elapsed_time("Done")
    }
    return(combined_extracted)
  } else if (output == "df") {
    combined_extracted <- combined_extracted |>
      as.data.frame() |>
      dplyr::select(-geometry)

    if (!quiet) {
      print_elapsed_time("Done")
    }
    return(combined_extracted)
  }
}
