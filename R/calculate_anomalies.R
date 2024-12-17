calculate_anomalies <- function(sst_file, climatology) {

  anomaly <- sst_file - climatology
  terra::varnames(anomaly) <- "SST Anomalies"
  terra::time(anomaly) <- terra::time(sst_file)

  return(anomaly)
}
