#' @name calculate_monthly_mean
#' @title Create Monthly Mean (MMM)
#' @description
#' Function to calculate maximum monthly mean
#'
#' See vignette for further details
#'
#' @param sst_file sst file
#' @returns climatology (terra::rast format)
#'
#'
#'
#' @export
calculate_monthly_mean <- function(sst_file) {

  time_input <- as.Date(terra::time(sst_file))
  years <- as.numeric(format(time_input, "%Y"))
  months <- as.numeric(format(time_input, "%m"))


  sst_8512 <- terra::subset(sst_file, which(years >= 1985 & years <= 2012))
  years_8512 <- years[years >= 1985 & years <= 2012]
  months_8512 <- months[years >= 1985 & years <= 2012]
  # time_8512 <- terra::time(sst_8512)

  # Initialize a list for monthly climatologies
  mm <- list()

  for (i in 1:12) {
    # Subset indices for the current month
    month_indices <- which(months_8512 == i)

    # Check for valid data
    if (length(month_indices) > 0) {
      # Subset SST data for the current month
      month_indices <- which(months_8512 == i)
      sst_month <- terra::subset(sst_8512, month_indices)  # Ensure correct subset

      # Calculate climatology for the month
      climatology_month <- terra::app(sst_month, function(sst_ts) {
        if (sum(!is.na(sst_ts)) > 1) {

          month_indices <- which(months_8512 == i)
          # sst_month <- terra::subset(sst_8512, month_indices)  # Ensure correct subset

          df <- data.frame(
            sst = sst_ts,
            month = months_8512[month_indices],
            year = years_8512[month_indices]
          )

          #time_center <- if (i <= 5) 1988.833 else 1988.2857
          time_center <- 1988.2857

          lm_fit <- stats::lm(sst ~ year, data = df)
          T_1988 <- stats::predict(lm_fit, newdata = data.frame(year = time_center))
          return(T_1988)
        } else {
          return(NA)
        }
      })

      # Store climatology raster
      mm[[i]] <- climatology_month
      names(mm[[i]]) <- paste0("mm-", month.name[i])
    } else {
      # Handle empty months
      mm[[i]] <- terra::rast()
      names(mm[[i]]) <- paste0("mm-", month.name[i])
    }
  }

  # Combine climatologies into a single raster
  mm <- terra::rast(mm[1:12])
  names(mm) <- paste0("mm-", month.abb[1:12])
  terra::varnames(mm) <- paste0("mm-", month.abb[1:12])

  return(mm)

}
