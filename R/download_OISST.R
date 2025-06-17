#' @name download_OISST
#' @title Download OISST data
#' @description
#'
#' Function to download and save NetCDF files for CoralTemp
#' `download_OISST()` is a function to download OISST v2.1
#'
#' If the number of cores is set to >1, the function uses `mclapply` to parallel download datasets, else 1 = single downloads.
#'
#' Notes:
#' The NOAA 1/4° Daily Optimum Interpolation Sea Surface Temperature (OISST) is a long term Climate Data Record that incorporates
#' observations from different platforms (satellites, ships, buoys and Argo floats) into a regular global grid. The dataset is
#' interpolated to fill gaps on the grid and create a spatially complete map of sea surface temperature. Satellite and ship observations
#' are referenced to buoys to compensate for platform differences and sensor biases.
#'
#` https://www.ncei.noaa.gov/products/optimum-interpolation-sst
#'
#' @param url one of the NOAA thredds url
#' @param start_date end year
#' @param end_date end year
#' @param dates Vector of dates as an alternative to start_date and end_date for non sequential timeseries
#' @param dest_dir save file location
#' @param mc.cores set the number of cores
#' @returns downloaded nc files to specified location
#' @examples
#' \dontrun{
#'
#' download_OISST(url = "https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/",
#'   start_date = "1990-01-01",
#'   end_date = "1990-01-02",
#'   dest_dir = "/Volumes/Extreme_SSD/dhw/OISST/2024/",
#'   mc.cores = 1)
#'
#' download_OISST(url = "https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/",
#'   dates = c("1990-01-01", "1990-01-02")
#'   dest_dir = "/Volumes/Extreme_SSD/dhw/OISST/2024/",
#'   mc.cores = 1)

#'
#' }
#' @export


# Function to download and save NetCDF files for OISST
download_OISST <- function(
    url       = "https://www.ncei.noaa.gov/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/",
    start_date = NULL,
    end_date   = NULL,
    dates      = NULL,
    dest_dir,
    mc.cores   = 1
) {
  # Ensure destination directory exists
  if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE)

  # ---- Resolve dates: accept vector OR "start:end" OR start_date/end_date ----
  parse_date_any <- function(x) {
    if (inherits(x, "Date")) return(x)
    x <- as.character(x)
    if (grepl("^\\d{8}$", x)) return(as.Date(x, "%Y%m%d"))
    if (grepl("^\\d{4}-\\d{2}-\\d{2}$", x)) return(as.Date(x))
    as.Date(NA)
  }

  date_seq <- NULL

  if (!is.null(dates)) {
    if (length(dates) == 1L && grepl(":", dates)) {
      parts <- strsplit(dates, ":", fixed = TRUE)[[1]]
      if (length(parts) != 2) stop("When using 'dates' as 'start:end', provide exactly one colon.")
      d1 <- parse_date_any(trimws(parts[1]))
      d2 <- parse_date_any(trimws(parts[2]))
      if (any(is.na(c(d1, d2)))) stop("Unparseable date in 'dates' range. Use YYYYMMDD or YYYY-MM-DD.")
      if (d2 < d1) stop("End date is earlier than start date in 'dates' range.")
      date_seq <- seq(d1, d2, by = "day")
    } else {
      dv <- vapply(dates, parse_date_any, as.Date(NA))
      if (any(is.na(dv))) stop("One or more entries in 'dates' are unparseable. Use YYYYMMDD or YYYY-MM-DD.")
      date_seq <- sort(unique(as.Date(dv)))
    }
  } else {
    if (is.null(start_date) || is.null(end_date)) {
      stop("Provide either 'dates' or both 'start_date' and 'end_date'.")
    }
    d1 <- parse_date_any(start_date)
    d2 <- parse_date_any(end_date)
    if (any(is.na(c(d1, d2)))) stop("Unparseable 'start_date' or 'end_date'. Use YYYYMMDD or YYYY-MM-DD.")
    if (d2 < d1) stop("'end_date' must be on/after 'start_date'.")
    date_seq <- seq(d1, d2, by = "day")
  }

  dates <- format(date_seq, "%Y%m%d")

  # ---- Download worker ----
  dl_fun <- function(.date) {
    download_nc_file_OISST(.date, base_url = url, dest_dir = dest_dir)
  }

  # ---- Parallel or sequential processing ----
  if (mc.cores > 1) {
    invisible(parallel::mclapply(dates, dl_fun, mc.cores = mc.cores))
  } else {
    invisible(lapply(dates, dl_fun))
  }
}
