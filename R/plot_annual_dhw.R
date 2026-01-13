#' @name plot_annual_dhw
#' @title Plot mean monthly maximum for a given gridcell
#' @description
#' Plot mean monthly maximum for a given gridcell
#' from a terra::rast file input
#'
#' @param input rast file
#' @param fixedyears range y lims for ggplot
#' @returns ggplot of annual DHW scaled Nov-Aug
#'
#' @export
#'
#'
plot_annual_dhw <- function(input, fixedyears=NULL) {

  input_df <- input %>%
    terra::as.data.frame(xy = TRUE, wide = FALSE, time = TRUE) %>%
    dplyr::rename(dhw = values) %>%
    dplyr::mutate(dhw = base::round(base::ifelse(is.na(dhw), 0, dhw), 2)) %>%
    dplyr::mutate(xy = base::paste0(x, y),
                  year = lubridate::year(time),
                  month = lubridate::month(time),
                  day = lubridate::yday(time))


  # calculate mean annual maxDHW
  data_dhw_mean_annual_max <- input_df %>%
    dplyr::mutate(xy = base::paste0(x, y)) %>%
    dplyr::mutate(year = lubridate::year(time)) %>%
    dplyr::group_by(year, xy) %>%
    dplyr::summarise(dhw = base::max(dhw, na.rm = TRUE)) %>%
    dplyr::ungroup() %>%
    dplyr::group_by(year) %>%
    dplyr::summarise(dhw = base::mean(dhw, na.rm = TRUE))

  # calculate mean daily DHW
  data_dhw_daily_mean_base <- input_df %>%
    dplyr::group_by(year, month, day) %>%
    dplyr::summarise(dhw = base::mean(dhw, na.rm = TRUE)) %>%
    dplyr::mutate(dhw = base::round(dhw, 2))

  # calculate long-term mean DHW with 95% CI
  data_dhw_daily_mean_summary <- data_dhw_daily_mean_base %>%
    dplyr::group_by(day) %>%
    dplyr::summarise(
      mean_dhw = base::mean(dhw, na.rm = TRUE),
      se_dhw   = stats::sd(dhw, na.rm = TRUE) / base::sqrt(base::sum(!base::is.na(dhw))),
      ci_lower = mean_dhw - stats::qt(0.975, df = base::sum(!base::is.na(dhw)) - 1) * se_dhw,
      ci_upper = mean_dhw + stats::qt(0.975, df = base::sum(!base::is.na(dhw)) - 1) * se_dhw
    ) %>%
    dplyr::mutate(yday = day,
                  maxdhw = base::max(mean_dhw))

  # rebase to Nov-Aug timeseries
  data_dhw_daily_mean <- data_dhw_daily_mean_base %>%
    dplyr::mutate(
      date = base::as.Date(day - 1, origin = base::paste0(year, "-01-01")),
      month_day = base::format(date, "%b-%d"),
      month_day = dplyr::if_else(base::format(date, "%b") %in% c("Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun"),
                                 month_day, NA_character_)
    ) %>%
    dplyr::mutate(yday = dplyr::if_else(month %in% c(11, 12),
                                        lubridate::yday(date) - 365,
                                        lubridate::yday(date))) %>%
    dplyr::mutate(eventyear = dplyr::if_else(month %in% c(11, 12), year + 1, year))

  # calculate top ten years
  if (!is.null(fixedyears)) {
    data_dhw_daily_mean_ten <- data_dhw_mean_annual_max %>%
      dplyr::filter(year %in% fixedyears)
  } else {
    data_dhw_daily_mean_ten <- data_dhw_mean_annual_max %>%
      dplyr::slice_max(dhw, n = 10)
  }

  # extract main bleaching events
  data_dhw_daily_mean_mainevents <- data_dhw_daily_mean %>%
    dplyr::mutate(eventyear = base::as.factor(eventyear)) %>%
    dplyr::filter(eventyear %in% unique(data_dhw_daily_mean_ten$year)) %>%
    dplyr::group_by(eventyear) %>%
    dplyr::mutate(maxdhw = base::max(dhw)) %>%
    dplyr::ungroup() %>%
    arrange(eventyear)

  # characterise peaks of main bleaching events
  data_dhw_daily_mean_mainevents_peaks <- data_dhw_daily_mean_mainevents %>%
    dplyr::arrange(eventyear, dplyr::desc(dhw), dplyr::desc(date)) %>%
    dplyr::group_by(eventyear) %>%
    dplyr::slice(1) %>%
    dplyr::ungroup()

  # set range to max DHW
  range=c(0, (ceiling(max(input_df$dhw)) + 1))

  # number of groups = unique years
  # clamp Brewer base palette to [3, 11], then interpolate to n_grp
  n_grp <- length(unique(data_dhw_daily_mean_ten$year))
  base_cols <- RColorBrewer::brewer.pal(max(3, min(11, n_grp)), "RdYlBu")
  pal_cols  <- grDevices::colorRampPalette(base_cols)(n_grp)

  # plot
  plot <- ggplot2::ggplot() +
    ggplot2::theme_bw() +
    ggplot2::geom_rect(ggplot2::aes(xmin = -61, xmax = 1, ymin = 0, ymax = range[2]),
                       fill = "#bed5e6", linewidth = 0, alpha = 0.2) +
    ggplot2::geom_line(data = data_dhw_daily_mean_mainevents %>% base::droplevels(),
                       show.legend = FALSE,
                       ggplot2::aes(x = yday, y = dhw, group = eventyear, color = base::as.factor(eventyear)),
                       linewidth = 1.2) +
    scale_color_manual(values = setNames(pal_cols, rev(sort(unique(as.factor(data_dhw_daily_mean_ten$year)))))) +
    ggplot2::geom_line(data = data_dhw_daily_mean_summary,
                       ggplot2::aes(x = yday, y = mean_dhw)) +
    ggplot2::geom_ribbon(data = data_dhw_daily_mean_summary,
                         ggplot2::aes(x = yday, ymin = ci_lower, ymax = ci_upper),
                         fill = "grey", alpha = 0.2) +
    ggplot2::scale_x_continuous(limits = c(-61, 230),
                                breaks = c(-61, -30, 1, 32, 60, 91, 121, 152, 182, 213),
                                labels = c("Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug"),
                                expand = c(0, 0),
                                sec.axis = ggplot2::sec_axis(trans = ~.,
                                                             breaks = c(-61, -30, 1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335),
                                                             labels = c("Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"))) +
    ggplot2::scale_y_continuous(limits = range,
                                breaks = base::seq(range[1], range[2], 2),
                                expand = c(0, 0)) +
    ggplot2::labs(x = "Month", y = "DHW", color = "Year") +
    ggplot2::geom_text(data = data_dhw_daily_mean_mainevents_peaks,
                       ggplot2::aes(x = -45, y = maxdhw + 0.2, label = year),
                       size = 3) +
    ggplot2::geom_text(data = data_dhw_daily_mean_mainevents_peaks,
                       ggplot2::aes(x = 0, y = maxdhw + 0.2, label = base::paste0(base::round(maxdhw, 1), " DHW")),
                       size = 3) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   panel.grid.major = ggplot2::element_blank()) +
    ggplot2::geom_linerange(data = data_dhw_daily_mean_mainevents_peaks,
                            ggplot2::aes(xmin = -60, xmax = day, y = maxdhw, color = eventyear),
                            linetype = "dashed",
                            show.legend = FALSE) +
    ggplot2::geom_linerange(ggplot2::aes(xmax = data_dhw_daily_mean_summary %>%
                                           dplyr::slice_max(mean_dhw) %>%
                                           dplyr::pull(day),
                                         xmin = 0,
                                         y = data_dhw_daily_mean_summary %>%
                                           dplyr::distinct(maxdhw) %>%
                                           dplyr::pull(maxdhw)),
                            linetype = "dotted") +
    ggplot2::geom_linerange(ggplot2::aes(x = data_dhw_daily_mean_summary %>%
                                           dplyr::slice_max(mean_dhw) %>%
                                           dplyr::pull(day),
                                         ymin = 0,
                                         ymax = data_dhw_daily_mean_summary %>%
                                           dplyr::slice_max(mean_dhw) %>%
                                           dplyr::pull(mean_dhw)),
                            linetype = "dotted")

  return(plot)
}
