#' NOAA_CRW_data
#'
#' subset of NOAA CRW data from rerdapp
#'
#' @format dataframe
#' \describe{
#'   \item{CRW_SST}{Sea Surface Temperature)}
#'   \item{CRW_SSTANOMALY}{Sea Surface Temperature anomaly)}
#'   \item{CRW_DHW}{Degree Heating Weeks}
#' }
#' @source
#'
#'
#' library(rerddap)
#'
#' NOAA_CRW <- griddap(
#'   datasetx = 'NOAA_DHW',
#'   time = c("2015-06-01", "2017-06-01"),
#'   latitude = c(-14.655, -14.655),
#'   longitude = c(145.405, 145.405),
#'   fmt = "nc"
#' )
#'
#' NOAA_CRW_data <- NOAA_CRW$data
#'
#' @examples
#' data(NOAA_CRW_data)
#' summary(NOAA_CRW_data)
"NOAA_CRW_data"
