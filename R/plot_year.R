#' @name plot_year
#' @title Calculate anomalies
#' @description
#' Function to calculate anomalies
#'
#' See vignette for further details
#'
#'
#' @param sst_file sst file
#' @param climatology daily climatology
#' @returns SST anomalies (terra::rast format)
#'
#' @export
plot_year <- function(sst_file, climatology) {

  anomaly <- sst_file - climatology
  terra::varnames(anomaly) <- "SST Anomalies"
  terra::time(anomaly) <- terra::time(sst_file)

  return(anomaly)
}


#fpath <- system.file("extdata", "lizard_crw.tif", package="dhw")
#
# tmp_sst <- rast(fpath)
#
#
# input <- create_climatology(tmp_sst, )
#
# function(input, year)
#
# data_df <- data.frame(
#   time = as.Date(terra::time(input$sst)),
#   year_select = year(time),
#   lat = rep(terra::crds(input$sst, na.rm = FALSE)[1, 1], length(terra::time(input$sst))),
#   lon = rep(terra::crds(input$sst, na.rm = FALSE)[1, 2], length(terra::time(input$sst))),
#   sst = as.numeric(terra::values(input$sst)),
#   mmm = rep(terra::values(input$mmm)[1], length(as.Date(terra::time(input$sst)))),
#   climatology =  as.numeric(terra::values(input$climatology)),
#   anomalies = as.numeric(terra::values(input$anomaly)),
#   hotspots = as.numeric(terra::values(input$hotspots)),
#   dhw =  as.numeric(terra::values(input$dhw))
# )
#
# year = 2016
# mmm_val <- unique(data_df$mmm)

#
# data_sst <- input$sst |>
#   as.data.frame(xy=TRUE, wide=FALSE, time=TRUE) |>
#   rename(calculated_SST=values) |>
#   filter(time >= as.Date("2015-06-01")) |>
#   filter(time < as.Date("2017-06-01")) |>
#   select(-x, -y, -layer)

#
# range <- data_df %>%
#   ungroup() %>%
#   filter(year_select >= year-1) %>%
#   filter(year_select < year+1)
#
# data_df %>%
#   ungroup() %>%
#   filter(year >= year-1) %>%
#   filter(year < year+1) %>%
#   mutate(mmm_line = mmm_val,
#          dashed_line = mmm_val + 1) |>
#   mutate(fill_area = ifelse(sst > dashed_line, sst, dashed_line),
#          mmm_area = ifelse(sst < mmm_line, mmm_line, sst)) %>%
#
#   ggplot() + theme_bw() +
#   #ggtitle("Lizard Island Reef (North West) (14-116a)") +
#   geom_vline(xintercept = as.Date(paste0(year, "-01-01 12:00:00")), color = "darkgrey", linewidth=0.5) +
#   geom_linerange(aes(x = as.Date(time), ymin = floor(min(range$sst))-0.5,
#                      ymax = floor(min(range$sst)), color = bleachingwatch), linewidth = 2) +
#   ggpattern::geom_ribbon_pattern(aes(x = as.Date(time), ymin = mmm_val, ymax = mmm_area), na.rm = TRUE,
#                       pattern = "gradient",
#                       fill = "#00000000",
#                       pattern_fill = "darkgoldenrod2",
#                       pattern_fill2 = "darkgoldenrod2") +
# #
#   geom_ribbon_pattern(aes(x = as.Date(time), ymin = dashed_line, ymax = fill_area), na.rm = TRUE,
#                       pattern = "gradient",
#                       fill = "#00000000",
#                       pattern_fill = "red",
#                       pattern_fill2 = "red") +
#
#   geom_hline(yintercept = mmm_val, color = "darkred") +
#   geom_hline(yintercept = mmm_val + 1, linetype = "dashed") +
#
#   geom_line(aes(x = as.Date(time), y = sst, color = "SST"), color = "black", show.legend = FALSE, linewidth = 0.6) +  # Add sst
#
#   geom_line(aes(x = as.Date(time), y = climatology), color = "grey", linetype="dashed", show.legend = FALSE, linewidth = 0.6) +  # Add sst
#
#   geom_rect(aes(xmin = as.Date(paste0(year-1, "-11-01 12:00:00")), xmax = as.Date(paste0(year, "-12-31 12:00:00")), ymin = 23.5, ymax = 24), fill = NA, color = "black", linewidth = 0.5) +
#
#   geom_text(aes(as.Date(paste0(year, "-01-09")), ceiling(max(range$sst))-0.2, label=year), size=4, color="darkgrey") +
#   geom_text(aes(as.Date(paste0(year-1, "-12-24")), ceiling(max(range$sst))-0.2, label=year-1), size=4, color="darkgrey") +
#   geom_text(aes(as.Date(paste0(year-1, "-11-09")), mmm_val+0.25, label="MMM"), size=4, color="darkred") +
#   geom_text(aes(as.Date(paste0(year-1, "-11-17")), mmm_val+1.25, label="MMM + 1°C"), size=4, color="darkred") +
#   geom_text(aes(as.Date(paste0(year-1, "-11-26")), floor(min(range$sst))+0.25, label="Bleaching alert status"), size=4, color="black") +
#
#   scale_x_date(date_breaks = "1 month", date_labels = "%b",
#                limits = as.Date(c(as.Date(paste0(year-1, "-11-01")), as.Date(paste0(year, "-07-01"))))) +
#   scale_y_continuous(limits = c(floor(min(range$sst)-1), ceiling(max(range$sst)+0.2)),
#                      breaks=seq(floor(min(range$sst)-1), ceiling(max(range$sst)+0.2),2)) +
#
#   labs(x = "\n Month", y = "Sea Surface Temperature (°C) [NOAA OISST]\n") +
#   theme(panel.grid.minor = element_blank(),
#         legend.position = c(0.99, 0.99),  # Position legend at the top right
#         legend.justification = c("right", "top"),
#         legend.background = element_rect(fill = "white", color = NA),
#         legend.box.background = element_blank(),  # Remove border around legend
#         legend.title = element_blank()) +  # Optionally remove legend title
#   scale_color_manual(values = c("No Stress" = "#d2f8f9", "Watch" = "#fcf050", "Warning" = "#eead3e",
#                                 "Alert Level 1" = "#dc2f21", "Alert Level 2" = "#891a10",
#                                 "Alert Level 3" = "#6c1210", "Alert Level 4" = "#4a0d0d",
#                                 "Alert Level 5" = "#2a0707"))
