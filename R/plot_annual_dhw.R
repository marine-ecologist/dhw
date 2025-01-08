#' @name plot_mm
#' @title Plot mean monthly maximum for a given gridcell
#' @description
#' Plot mean monthly maximum for a given gridcell
#' from a terra::rast() file input
#'
#'
#'
#' @param input rast() file
#' @param range y lims for ggplot
#' @returns ggplot of annual DHW scaled Nov-Aug
#'
#' @export
#'
#'
#'
plot_annual_DHW <- function(input, range=c(0,12)){


  input_df <- input |>
    as.data.frame(xy = TRUE, wide = FALSE, time = TRUE) |>
    dplyr::rename(dhw = values) |>
    mutate(dhw= round(ifelse(is.na(dhw), 0, dhw)), 2) |>
    dplyr::mutate(xy = paste0(x, y),
                  year = lubridate::year(time),
                  month = lubridate::month(time),
                  day = lubridate::yday(time))

  # calculate mean annual maxDHW
  data_dhw_mean_annual_max <- input_df |>
    dplyr::mutate(xy = paste0(x, y)) |>
    dplyr::mutate(year = lubridate::year(time)) |>
    # calculate max DHW per gridcell
    dplyr::group_by(year, xy) |>
    dplyr::summarise(dhw = max(dhw, na.rm = TRUE)) |>
    dplyr::ungroup() |>
    # calculate mean DHW per year
    dplyr::group_by(year) |>
    dplyr::summarise(dhw = mean(dhw, na.rm = TRUE))

  # calculate mean daily DHW
  data_dhw_daily_mean_base <- input_df |>
    dplyr::group_by(year, month, day) |>
    dplyr::summarise(dhw = mean(dhw, na.rm = TRUE)) |>
    dplyr::mutate(dhw=round(dhw, 2))

  # calculate long-term mean DHW with 95% CI
  data_dhw_daily_mean_summary <- data_dhw_daily_mean_base |>
    dplyr::group_by(day) |>
    dplyr::summarise(
      mean_dhw = mean(dhw, na.rm = TRUE),  # Mean while ignoring NaN values
      se_dhw = stats::sd(dhw, na.rm = TRUE) / sqrt(sum(!is.na(dhw))), # Standard Error
      ci_lower = mean_dhw - stats::qt(0.975, df = sum(!is.na(dhw)) - 1) * se_dhw, # Lower 95% CI
      ci_upper = mean_dhw + stats::qt(0.975, df = sum(!is.na(dhw)) - 1) * se_dhw  # Upper 95% CI
    ) |>
    mutate(yday=day,
           maxdhw=max(mean_dhw))

  # rebase to Nov-Aug timeseries
  data_dhw_daily_mean <- data_dhw_daily_mean_base |>
    dplyr::mutate(
      date = as.Date(day - 1, origin = paste0(year, "-01-01")),
      month_day = format(date, "%b-%d"),
      month_day = dplyr::if_else(format(date, "%b") %in% c("Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun"), month_day, NA_character_), # Remove other months
    ) |>
    dplyr::mutate(yday = dplyr::if_else(month %in% c(11, 12), lubridate::yday(date) - 365, lubridate::yday(date))) |>   # Shift Nov-Dec of previous year
    dplyr::mutate(eventyear = dplyr::if_else(month %in% c(11, 12), year+1, year))  # Shift Nov-Dec of previous year

  # calculate top ten years
  data_dhw_daily_mean_ten <- data_dhw_mean_annual_max |>
    dplyr::slice_max(dhw, n = 10)

  # extract main bleaching events
  data_dhw_daily_mean_mainevents <- data_dhw_daily_mean |>
    dplyr::mutate(eventyear = as.factor(eventyear)) |>
    dplyr::filter(eventyear %in% c("1998", "2002", "2016", "2017", "2020", "2022", "2024")) |>
    group_by(eventyear) |>
    mutate(maxdhw=max(dhw)) |>
    ungroup()

  # characterise peaks of main bleaching events
  data_dhw_daily_mean_mainevents_peaks <- data_dhw_daily_mean_mainevents |>
    dplyr::arrange(eventyear, desc(dhw), desc(date)) |> # Resolve ties by preferring later dates
    dplyr::group_by(eventyear) |>
    dplyr::slice(1) |> # Take only the first row in each group
    dplyr::ungroup()
  # data_dhw_daily_mean_mainevents_peaks <- data_dhw_daily_mean_mainevents |>
  #   slice_max(dhw, n=1, by=year, with_ties=TRUE)


  # plot
  plot <- ggplot2::ggplot() + ggplot2::theme_bw() +
    geom_rect(aes(xmin=-61, xmax=1, ymin=0, ymax=range[2]), fill="#bed5e6", linewidth=0, alpha=0.2) +
    # annual DHW lines
    ggplot2::geom_line(data = data_dhw_daily_mean_mainevents |> droplevels(), show.legend=FALSE, ggplot2::aes(x = yday, y = dhw, group = eventyear, color = as.factor(eventyear)), linewidth = 1.2) +
    # color ramp
    ggplot2::scale_color_manual(values=c("#3565a7", "#8faec1", "#bed5e6","#e9a381",  "#d57c5e",  "#e23b4b",  "#a32a31")) +
    # mean dhw
    ggplot2::geom_line(data = data_dhw_daily_mean_summary, ggplot2::aes(x = yday,y = mean_dhw)) +
    ggplot2::geom_ribbon(data = data_dhw_daily_mean_summary, ggplot2::aes(x = yday, ymin = ci_lower, ymax = ci_upper), fill = "grey", alpha = 0.2) +
    # xy ranges
    ggplot2::scale_x_continuous(limits=c(-61,230), breaks = c(-61, -30, 1, 32, 60, 91, 121, 152, 182, 213),  labels = c("Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug"), expand=c(0,0),
                                sec.axis = ggplot2::sec_axis( trans = ~., breaks = c(-61, -30, 1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335), labels = c("Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"))) +
    ggplot2::scale_y_continuous(limits=range, breaks=seq(range[1], range[2], 2), expand=c(0,0)) +
    # labels
    ggplot2::labs(x = "Month", y = "DHW", color = "Year") +
    # add year labels
    ggplot2::geom_text(data=data_dhw_daily_mean_mainevents_peaks,  aes(x=-45, y=maxdhw+0.2, label=year)) +
    # add max dhw labels
    ggplot2::geom_text(data=data_dhw_daily_mean_mainevents_peaks,  aes(x=0, y=maxdhw+0.2, label=paste0(round(maxdhw,1), "°C"))) +
    # remove grids
    ggplot2::theme(panel.grid.minor = element_blank(), panel.grid.major = element_blank()) +
    # mean peak DHW events
    ggplot2::geom_linerange(data=data_dhw_daily_mean_mainevents_peaks, aes(xmin = -60, xmax = day, y = maxdhw, color=eventyear), linetype="dashed", show.legend=FALSE) +
    # mean peak DHW
    ggplot2::geom_linerange(aes(xmax = data_dhw_daily_mean_summary |> slice_max(mean_dhw) |> pull(day), xmin = 0,  y = data_dhw_daily_mean_summary |> distinct(maxdhw) |> pull(maxdhw)), linetype="dotted") +
    # mean peak DHW date
    ggplot2::geom_linerange(aes(x = data_dhw_daily_mean_summary |> slice_max(mean_dhw) |> pull(day), ymin = 0,  ymax = data_dhw_daily_mean_summary |> slice_max(mean_dhw) |> pull(mean_dhw)), linetype="dotted")



  return(plot)

}
