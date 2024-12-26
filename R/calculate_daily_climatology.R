#' @name calculate_daily_climatology
#' @title Calculate Daily Climatology
#' @description
#' Function to calculate daily climatology
#'
#' See vignette for further details
#'
#' @param sst_file sst file
#' @param mm monthly maximums
#' @returns climatology (terra::rast format)
#'
#'
#' @export
#'
calculate_daily_climatology <- function(sst_file, mm) {
  # Ensure time in the sst_file is in Date format
  terra::time(sst_file) <- as.Date(terra::time(sst_file))

  # Extract the start and end dates
  start_date <- min(terra::time(sst_file))
  end_date <- max(terra::time(sst_file))

  # Generate monthly time values centered on the 15th of each month
  time_values <- seq(as.Date(format(start_date, "%Y-%m-15")),
                     as.Date(format(end_date, "%Y-%m-15")), by = "month")

  # Align monthly climatology to the start of the time range
  start_month <- as.numeric(format(start_date, "%m"))
  mm_aligned <- mm[[c(start_month:12, 1:(start_month - 1))]]

  # Repeat the aligned climatology to match the time range
  # n_repeats <- ceiling(length(time_values) / 12)
  climatology_rep <- mm_aligned[[rep(1:12, length.out = length(time_values))]]
  terra::time(climatology_rep) <- time_values

  # Extract daily dates from sst_file
  daily_dates <- as.Date(terra::time(sst_file))

  # Interpolation function to align monthly climatology to daily resolution
  interpolate_daily_climatology <- function(monthly_sst) {
    if (all(is.na(monthly_sst))) {
      return(rep(NA, length(daily_dates)))
    }
    # Interpolate only within the exact daily range
    zoo::na.approx(monthly_sst, x = time_values, xout = daily_dates, rule = 2)
  }

  # Apply interpolation
  climatology <- terra::app(climatology_rep, fun = function(x) interpolate_daily_climatology(x))

  # Assign the exact time dimension from sst_file to climatology
  terra::time(climatology) <- daily_dates
  terra::varnames(climatology) <- "Daily SST climatology"
  names(climatology) <- daily_dates

  return(climatology)
}
