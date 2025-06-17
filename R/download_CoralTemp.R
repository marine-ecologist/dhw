#' @name download_CoralTemp
#' @title Download CoralTemp data
#' @description
#' Downloads and saves NOAA CoralTemp NetCDF files from the specified start and end dates.
#'
#' The CoralTemp dataset provides daily global 5km Sea Surface Temperature (SST) data,
#' including anomalies and degree heating weeks, spanning from January 1, 1985.
#'
#' URL links current 4th Jan:
#' https://www.ncei.noaa.gov/thredds-ocean/catalog/crw/5km/v3.1/nc/v1.0/daily/sst/1985/catalog.html?dataset=crw/5km/v3.1/nc/v1.0/daily/sst/1985/coraltemp_v3.1_19850101.nc
#' https://www.ncei.noaa.gov/thredds-ocean/fileServer/crw/5km/v3.1/nc/v1.0/daily/sst/1985/coraltemp_v3.1_19850101.nc
#'
#' See: https://coralreefwatch.noaa.gov/product/5km/index_5km_sst.php
#'
#' @param url NOAA THREDDS server URL. Default is the CoralTemp data server.
#' @param start_date Start date in "YYYY-MM-DD" format.
#' @param end_date End date in "YYYY-MM-DD" format.
#' @param dates Vector of dates as an alternative to start_date and end_date for non sequential timeseries
#' @param dest_dir Directory where NetCDF files should be saved.
#' @param variable Data type: 'sst', 'dhw', 'ssta', or 'hs'.
#' @param mc.cores Number of cores for parallel downloads.
#' @param quiet show verbose? TRUE by default
#' @returns Saves NetCDF files in the specified destination folder.
#' @examples
#' \dontrun{
#'
#' download_CoralTemp(url = "https://www.ncei.noaa.gov/thredds-ocean/fileServer/crw/5km/v3.1/nc/v1.0/daily/",
#'                    start_date = "1990-01-01",
#'                    end_date = "1990-01-02",
#'                    dest_dir = "/Volumes/Extreme_SSD/dhw/CRW/2024/",
#'                    variable = "sst",
#'                    mc.cores = 1)
#'}
#' @export

download_CoralTemp <- function(
    url = "https://www.ncei.noaa.gov/thredds-ocean/fileServer/crw/5km/v3.1/nc/v1.0/daily/",
    start_date = NULL,
    end_date   = NULL,
    dates      = NULL,
    dest_dir,
    variable   = "sst",
    mc.cores   = 1,
    quiet      = TRUE
) {
  # Validate the variable argument
  valid_vars <- c("sst", "dhw", "ssta", "hs")
  if (!(variable %in% valid_vars)) {
    stop("Invalid variable. Choose from 'sst', 'dhw', 'ssta', 'hs'.")
  }

  # Ensure destination directory exists
  if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE)

  # ---- Resolve dates: accept vector OR single "start:end" OR start_date/end_date ----
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
    download_nc_file_CRW(.date, base_url = url, dest_dir = dest_dir, var = variable)
  }

  # ---- Parallel or sequential processing ----
  if (mc.cores > 1) {
    if (isFALSE(quiet)) {
      invisible(parallel::mclapply(dates, dl_fun, mc.cores = mc.cores))
    } else {
      parallel::mclapply(dates, dl_fun, mc.cores = mc.cores)
    }
  } else {
    if (isFALSE(quiet)) {
      invisible(lapply(dates, dl_fun))
    } else {
      lapply(dates, dl_fun)
    }
  }
}
