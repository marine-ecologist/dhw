#' @name calculate_monthly_mean
#' @title Create Monthly Mean (MMM)
#' @description
#' Function to calculate maximum monthly mean or trends.
#'
#' See vignette for further details.
#'
#' @param sst_file SpatRaster of SST data.
#' @param return Type of output: "predict", "slope", or "intercept".
#' @param midpoint recentered date, see vignette
#' @returns Climatology as a terra::rast object.
#' @export
#'
calculate_monthly_mean <- function(sst_file, midpoint = 1988.2857, return = "predict") {

  # Extract time, years, and months from the raster
  time_input <- as.Date(terra::time(sst_file))
  years <- as.numeric(format(time_input, "%Y"))
  months <- as.numeric(format(time_input, "%m"))

  # Subset SST data to 1985–2012
  sst_8512 <- terra::subset(sst_file, which(years >= 1985 & years <= 2012))
  years_8512 <- years[years >= 1985 & years <= 2012]
  months_8512 <- months[years >= 1985 & years <= 2012]

  # Initialize output list
  mm <- vector("list", 12)

  # Process each month
  for (i in 1:12) {
   # message(paste0("Processing month = ", i))  # Log progress

    # Subset raster for the current month
    month_indices <- which(months_8512 == i)
    if (length(month_indices) > 0) {
      sst_month <- terra::subset(sst_8512, month_indices)

      # Compute climatology for each cell
      climatology_month <- terra::app(sst_month, function(sst_ts) {
        # Check for sufficient data
        if (sum(!is.na(sst_ts)) > 1) {

          # Create data frame for regression
          df <- data.frame(
            sst = sst_ts,
            year = years_8512[month_indices]
          )

          # Fit linear model
          lm_fit <- stats::lm(sst ~ year, data = df)

          # Compute requested output
         if (return == "predict") {
            return(stats::predict(lm_fit, newdata = data.frame(year = midpoint)))
          } else if (return == "slope") {
            return(stats::coef(lm_fit)[2])  # Slope
          } else if (return == "intercept") {
            return(stats::coef(lm_fit)[1])  # Intercept
          } else {
            stop("Invalid return type specified. Use 'predict', 'slope', or 'intercept'.")
          }
        } else {
          return(NA)  # Insufficient data
        }
      })

      # Store output
      mm[[i]] <- climatology_month
      names(mm[[i]]) <- paste0("mm-", month.name[i])
    } else {
      # Handle empty months
      mm[[i]] <- terra::rast()
      names(mm[[i]]) <- paste0("mm-", month.name[i])
    }
  }

  # Combine results into a single raster
  mm <- terra::rast(mm)
  names(mm) <- paste0("mm-", month.abb[1:12])
  terra::varnames(mm) <- paste0("mm-", month.abb[1:12])

  return(mm)
}
