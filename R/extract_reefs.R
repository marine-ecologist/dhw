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
#'
#' noaa_dhw_file = "https://pae-paha.pacioos.hawaii.edu/erddap/griddap/dhw_5km.nc?CRW_SST%5B(2024-12-20T12:00:00Z):1:(2024-12-25T12:00:00Z)%5D%5B(-8.9):1:(-25)%5D%5B(141):1:(153.5)%5D"
#' noaa_dhw_raster <- rast(noaa_dhw_file) |> flip() |> project("EPSG:4283")
#' tmp <- extract_reefs(input=noaa_dhw_raster, shpfile=gbr_files)
#' tmp
#' }
#' @export

extract_reefs <- function(input, shpfile,  output = "sf", extract_fun = "weighted_mean", quiet=FALSE) {


    rasterfile <- terra::project(input, sf::st_crs(shpfile)$wkt)
    time_steps <- terra::time(rasterfile)

    if (is.null(time_steps)) {
      stop("Time information is missing from the raster")
    }


    if (!quiet) {
      cat("--- extract_reefs ---\n")
    }
    print_elapsed_time <- function(message) {
      elapsed <- Sys.time() - start_time
      cat(format(elapsed, digits = 2), " - ", message, "\n")
    }

    start_time <- Sys.time()
    combined_extracted <- foreach(i = seq_len(nlyr(input)), .combine = rbind) %do% {

      timestep <- as.Date(time(input[[i]]))
        if (!quiet) {
          print_elapsed_time(paste0("extracting ", i, "/", length(time_steps), " [", timestep, "]"))
        }

      shpfile |>
        mutate(
          date = rep(time(input[[i]]), nrow(shpfile)),
          sst = exactextractr::exact_extract(input[[i]], shpfile, progress = FALSE, fun = "weighted_mean", weights = "area")
        )

    }

    if (output == "sf") {

      if (!quiet) {
        print_elapsed_time("Done")
      }
      return(combined_extracted)
    } else if (output == "df") {

      combined_extracted <- combined_extracted |> as.data.frame() |> select(-geometry)
      if (!quiet) {
        print_elapsed_time("Done")
      }
      return(combined_extracted)
    }


}
