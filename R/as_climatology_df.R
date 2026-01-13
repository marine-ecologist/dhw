
#' Flatten climatology outputs (list of SpatRaster) to a tidy data.frame
#'
#' @param x list with SpatRaster elements (e.g., x$sst, x$climatology, x$anomaly, x$hotspots, x$dhw)
#' @param vars character vector of element names to extract and join
#'             (defaults to c("sst","climatology","anomaly","hotspots","dhw") present in x)
#' @return tibble with columns: lon, lat, time, and one column per var in `vars`
#' @export


as_climatology_df <- function(input,
                              vars = NULL,
                              xy = TRUE,
                              rename_xy = TRUE) {

  stopifnot(is.list(input))

  allowed <- c("sst","climatology","anomaly","hotspots","dhw","baa")
  if (is.null(vars)) vars <- intersect(allowed, names(input))
  keep <- intersect(vars, names(input))
  if (!length(keep)) return(tibble::tibble())

  keys <- c(if (xy) c("x","y") else character(0), "time")

  dfs <- lapply(keep, function(v) {
    df <- terra::as.data.frame(input[[v]], wide = FALSE, xy = xy, time = TRUE)
    nm <- names(df)
    nm[nm == "value"]  <- v
    nm[nm == "values"] <- v
    nm[nm == "lyr"]    <- "layer"
    names(df) <- nm
    dplyr::select(df, dplyr::any_of(c(keys, v)))
  })

  out <- Reduce(function(a, b) dplyr::full_join(a, b, by = keys), dfs)

  if (rename_xy && xy) out <- dplyr::rename(out, lon = x, lat = y)
  if ("dhw" %in% names(out)) out <- dplyr::mutate(out, dhw = tidyr::replace_na(dhw, 0))

  out %>% mutate(year=year(time), month=month(time))
}
