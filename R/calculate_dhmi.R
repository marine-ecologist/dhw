#' @title Calculate Degree Heating Month Index (DHMi)
#' @description This function calculates Degree Heating Month Index (DHMi) from Lough et al (2018) and is calculated based on either monthly or daily SST data
#'
#'
#' Citation: Lough et al (2018) Increasing thermal stress for tropical coral reefs: 1871–2017 Scientific Reports 8(6079)
#' https://www.nature.com/articles/s41598-018-24530-9
#'
#' @param sst_raster A `SpatRaster` object containing SST data. The raster should include a time dimension.
#' @param accumulation_window time window for calculating DHMi (typically 3 or 4 months, see Table S1 in Mason et al 2024 Nature Geoscience)
#' @param timespan start and end months for summed DHMi calculations (for example in Austral summer - November to May = c(12,5)
#'
#'
#' @return A `SpatRaster` object with the computed metric.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' sst_data <- rast("dhw_5km_12c5_a60a_4147_U1739222110146.nc")
#' ssta <- calculate_dhmi(sst_data, timeseries="daily", timespan = c(12, 4))
#' plot(ssta)
#' }
#'
#' @export
#' @import terra
#'


calculate_dhmi <- function(sst_raster, timeseries = c("daily", "monthly"), accumulation_window = 3, timespan = c(12, 5)) {
  timeseries <- match.arg(timeseries)

  if (timeseries == "daily") {
    # Convert daily SST to monthly means
    sst_monthly <- tapp(sst_raster, index = format(time(sst_raster), "%Y-%m"), fun = mean, na.rm = TRUE)
    terra::time(sst_monthly) <- as.Date(paste0(unique(format(time(sst_raster), "%Y-%m")), "-15"))
  } else {
    sst_monthly <- sst_raster
  }

  # Subset data based on specified timespan (can cross year boundaries)
  months_seq <- if (timespan[1] <= timespan[2]) {
    seq(timespan[1], timespan[2])
  } else {
    c(seq(timespan[1], 12), seq(1, timespan[2]))
  }

  sst_monthly_subset <- subset(sst_monthly, which(month(time(sst_monthly)) %in% months_seq))

  # Calculate MMM raster from subset monthly SST data
  monthly_climatology <- tapp(sst_monthly_subset, index = month(time(sst_monthly_subset)), fun = mean, na.rm = TRUE)
  mmm_raster <- app(monthly_climatology, max)

  # Calculate SST anomaly
  anomaly_raster <- sst_monthly_subset - mmm_raster
  terra::time(anomaly_raster) <- terra::time(sst_monthly_subset)

  # Retain only positive anomalies
  positive_anomaly <- terra::ifel(anomaly_raster > 0, anomaly_raster, 0)
  terra::time(positive_anomaly) <- terra::time(sst_monthly_subset)

  # Apply rolling sum for DHMI calculation (Degree Heating Months Index)
  dhmi_raster <- terra::app(positive_anomaly, function(x) {
    zoo::rollapply(x, width = accumulation_window, FUN = sum, align = "right", fill = NA)
  })
  terra::time(dhmi_raster) <- terra::time(sst_monthly_subset)

  return(dhmi_raster)
}
