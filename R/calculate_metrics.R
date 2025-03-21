#' @title Calculate SST Variability Metrics
#' @description This function calculates various sea surface temperature (SST) variability metrics from a `SpatRaster` object.
#' The user can specify the desired metric, which is then computed based on time series data.
#'
#' @param rast_obj A `SpatRaster` object containing SST data. The raster should include a time dimension.
#' @param metric A character string specifying the SST metric to compute. Options include:
#'   \describe{
#'     \item{"SSTA"}{Sea Surface Temperature Anomaly (SST deviation from climatology).}
#'     \item{"SST_SD"}{Standard deviation of SST over time.}
#'     \item{"SST_Trend"}{Linear trend of SST over time.}
#'     \item{"SST_Variance"}{Variance of SST values.}
#'     \item{"SST_Seasonality"}{Annual range (max - min SST).}
#'     \item{"SST_Interannual_Amplitude"}{Difference between annual max and min SST.}
#'     \item{"SST_Skewness"}{Skewness of SST distribution.}
#'   }
#'
#' @return A `SpatRaster` object with the computed metric.
#'
#' @details
#' - The function ensures that the input raster contains time information.
#' - If an invalid metric is supplied, an error is returned.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' sst_data <- rast("dhw_5km_12c5_a60a_4147_U1739222110146.nc")
#' ssta <- calculate_metrics(sst_data, "SSTA")
#' plot(ssta)
#' }
#'
#' @export
#' @import terra
#'

# Function to calculate SST variability metrics from a SpatRaster object
calculate_metrics <- function(rast_obj, lyr, metric) {

  # Ensure input is a SpatRaster object
  if (!inherits(rast_obj, "SpatRaster")) {
    stop("Input must be a SpatRaster object")
  }

  # Extract the SST layers (assuming "CRW_SST" is the correct SST variable name)
  sst <- rast_obj[[lyr]]

  # Ensure the raster contains time information
  if (is.null(terra::time(sst))) {
    stop("Input raster must have time dimension")
  }

  # Calculate time-based statistics based on the selected metric
  result <- switch(metric,

                   # 1. Sea Surface Temperature Anomaly (SSTA)
                   "SSTA" = {
                     climatology <- terra::app(sst, mean, na.rm = TRUE)  # Compute mean climatology
                     sst_anomaly <- sst - climatology  # Compute anomalies
                     return(sst_anomaly)
                   },

                   # 2. Standard Deviation of SST
                   "SST_SD" = {
                     sst_sd <- terra::app(sst, sd, na.rm = TRUE)  # Compute standard deviation
                     return(sst_sd)
                   },

                   # 3. SST Trend (Linear)
                   "SST_Trend" = {
                     time_index <- seq_len(terra::nlyr(sst))  # Create time index for regression
                     sst_trend <- terra::app(sst, function(x) {
                       if (all(is.na(x))) return(NA)  # Handle NA values
                       lm_fit <- stats::lm(x ~ time_index, na.action = na.exclude)  # Fit linear model
                       return(coef(lm_fit)[2])  # Return the slope (trend)
                     })
                     return(sst_trend)
                   },

                   # 6. SST Variance
                   "SST_Variance" = {
                     sst_var <- terra::app(sst, var, na.rm = TRUE)  # Compute variance
                     return(sst_var)
                   },

                   # 7. SST Seasonality (Annual Range: max - min)
                   "SST_Seasonality" = {
                     annual_max <- terra::tapp(sst, terra::time(sst), max, na.rm = TRUE)  # Annual max
                     annual_min <- terra::tapp(sst, terra::time(sst), min, na.rm = TRUE)  # Annual min
                     seasonality <- annual_max - annual_min  # Compute seasonality range
                     return(seasonality)
                   },

                   # 9. Interannual SST Anomaly Amplitude
                   "SST_Interannual_Amplitude" = {
                     interannual_max <- terra::tapp(sst, floor(terra::time(sst)), max, na.rm = TRUE)  # Yearly max
                     interannual_min <- terra::tapp(sst, floor(terra::time(sst)), min, na.rm = TRUE)  # Yearly min
                     interannual_amplitude <- interannual_max - interannual_min  # Compute amplitude
                     return(interannual_amplitude)
                   },

                   # 10. Skewness of SST Distribution
                   "SST_Skewness" = {
                     skewness_fun <- function(x) {
                       if (all(is.na(x))) return(NA)  # Handle NA values
                       x <- na.omit(x)
                       mean_x <- mean(x)
                       sd_x <- sd(x)
                       n <- length(x)
                       return(sum(((x - mean_x) / sd_x)^3) / n)  # Compute skewness
                     }
                     sst_skewness <- terra::app(sst, skewness_fun)  # Apply skewness function
                     return(sst_skewness)
                   },

                   stop("Invalid metric. Choose from: 'SSTA', 'SST_SD', 'SST_Trend', 'SST_Variance', 'SST_Seasonality', 'SST_Interannual_Amplitude', 'SST_Skewness'")
  )

  return(result)
}
