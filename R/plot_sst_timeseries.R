#' @title Plot seasonal SST vs. MMM with bleaching status
#' @name plot_sst_timeseries
#' @description
#' Produce a seasonal plot (Nov of \code{targetyear-1} to Jul of \code{targetyear})
#' showing SST relative to the site MMM and MMM+1°C threshold, with a
#' bottom bar indicating NOAA-style bleaching alert status derived from
#' \code{hotspots} and \code{dhw}.
#'
#' @param input A list containing at least these \code{terra::SpatRaster} elements:
#'   \itemize{
#'     \item \code{sst} — daily sea-surface temperature (with time dimension)
#'     \item \code{mmm} — maximum monthly mean (single-layer raster or single cell)
#'     \item \code{hotspots} — daily hotspots (same time as \code{sst})
#'     \item \code{dhw} — daily Degree Heating Weeks (same time as \code{sst})
#'   }
#'   Typically this is the output from your climatology pipeline.
#' @param startdate start date for timeseries
#' @param enddate end date for timeseries
#' @param title legend title
#' @param legend_position legend position from ggplot standard
#' @return A \code{ggplot2} object.
#'
#' @examples
#' \dontrun{
#' p <- plot_sst_timeseries(eyrie_climatology, startdate = "2023-11-01", enddate = "2026-02-28")
#' print(p)
#' }
#' @export

plot_sst_timeseries <- function(input, startdate, enddate, title="", legend_position= c(0.95, 0.4)) {

  startdate <- as.Date(startdate)
  enddate   <- as.Date(enddate)

  input_df <- dhw::as_climatology_df(
    input,
    vars = c("sst", "climatology", "anomaly", "hotspots", "dhw"),
    xy   = TRUE,
    rename_xy = TRUE
  ) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      year  = lubridate::year(.data$time),
      month = lubridate::month(.data$time),
      day   = lubridate::day(.data$time)
    )

  mmm_val <- {
    v <- terra::values(input$mmm)
    if (length(v) == 0L) NA_real_ else as.numeric(v[1])
  }

  plot_df <- input_df |>
    dplyr::mutate(
      mmm_line    = mmm_val,
      dashed_line = mmm_val + 1,
      bleachingwatch = dplyr::case_when(
        .data$hotspots <= 0                               ~ "No Stress",
        .data$hotspots > 0  & .data$hotspots < 1          ~ "Watch",
        .data$hotspots >= 1 & .data$dhw < 4               ~ "Warning",
        .data$hotspots >= 1 & .data$dhw >= 4  & .data$dhw < 8   ~ "Alert Level 1",
        .data$hotspots >= 1 & .data$dhw >= 8  & .data$dhw < 12  ~ "Alert Level 2",
        .data$hotspots >= 1 & .data$dhw >= 12 & .data$dhw < 16  ~ "Alert Level 3",
        .data$hotspots >= 1 & .data$dhw >= 16 & .data$dhw < 20  ~ "Alert Level 4",
        .data$hotspots >= 1 & .data$dhw >= 20            ~ "Alert Level 5",
        TRUE ~ NA_character_
      ),
      bleachingwatch = factor(
        .data$bleachingwatch,
        levels = c("No Stress","Watch","Warning",
                   "Alert Level 1","Alert Level 2","Alert Level 3","Alert Level 4","Alert Level 5")
      ),
      fill_area = dplyr::if_else(.data$sst > .data$dashed_line, .data$sst, .data$dashed_line),
      mmm_area  = dplyr::if_else(.data$sst < .data$mmm_line,    .data$mmm_line, .data$sst)
    ) |>
    dplyr::filter(.data$time >= startdate, .data$time <= enddate)

  y0 <- floor(min(plot_df$sst, na.rm = TRUE)) - 1
  y1 <- y0 + 0.5
  ymax <- ceiling(max(plot_df$sst, na.rm = TRUE))

  # label anchors derived from window (keeps them inside)
  ann <- tibble::tibble(
    xmin = startdate,
    xmax = enddate,
    y0 = y0,
    y1 = y1,
    ymax = ymax,
    mmm = mmm_val,
    x_mmm  = startdate + 8,
    x_mmm1 = startdate + 16,
    x_lab  = startdate + 25,
    x_top1 = startdate + 70,
    x_top2 = startdate + 30
  )

  ggplot2::ggplot(plot_df) +
    ggplot2::theme_bw() +

    ggplot2::geom_linerange(
      ggplot2::aes(x = .data$time, ymin = y0, ymax = y1, color = .data$bleachingwatch),
      linewidth = 2
    ) +

    ggplot2::geom_rect(
      data = ann,
      ggplot2::aes(xmin = .data$xmin, xmax = .data$xmax, ymin = .data$y0, ymax = .data$y1),
      inherit.aes = FALSE,
      color = "black", fill = NA, linewidth = 0.2
    ) +

    ggpattern::geom_ribbon_pattern(
      ggplot2::aes(x = .data$time, ymin = mmm_val, ymax = .data$mmm_area),
      na.rm = TRUE,
      pattern = "gradient",
      fill = NA,
      pattern_fill = "darkgoldenrod2",
      pattern_fill2 = "darkgoldenrod2"
    ) +

    ggpattern::geom_ribbon_pattern(
      ggplot2::aes(x = .data$time, ymin = .data$dashed_line, ymax = .data$fill_area),
      na.rm = TRUE,
      pattern = "gradient",
      fill = NA,
      pattern_fill = "red",
      pattern_fill2 = "red"
    ) +

    ggplot2::geom_hline(yintercept = mmm_val, color = "darkred") +
    ggplot2::geom_hline(yintercept = mmm_val + 1, linetype = "dashed") +

    ggplot2::geom_line(
      ggplot2::aes(x = .data$time, y = .data$sst),
      color = "black", linewidth = 0.6, show.legend = FALSE
    ) +

    ggplot2::geom_text(
      data = ann,
      ggplot2::aes(x = .data$x_mmm, y = .data$mmm + 0.2, label = "MMM"),
      inherit.aes = FALSE,
      size = 4, color = "darkred"
    ) +
    ggplot2::geom_text(
      data = ann,
      ggplot2::aes(x = .data$x_mmm1, y = .data$mmm + 1.2, label = "MMM + 1°C"),
      inherit.aes = FALSE,
      size = 4, color = "darkred"
    ) +
    ggplot2::geom_text(
      data = ann,
      ggplot2::aes(x = .data$x_lab, y = .data$y1 + 0.5, label = "Bleaching alert"),
      inherit.aes = FALSE,
      size = 4, color = "black"
    ) +

    ggplot2::scale_x_date(
      date_breaks = "1 month",
      date_labels = "%b",
      limits = c(startdate, enddate)
    ) +
    ggplot2::scale_y_continuous(limits = c(y0, ymax)) +

    ggplot2::labs(x = "\nMonth", y = "Sea Surface Temperature (°C) [NOAA OISST]\n") +

    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = c(0.99, 0.99),
      legend.justification = c("right", "top"),
      legend.background = ggplot2::element_rect(fill = "white", color = NA),
      legend.box.background = ggplot2::element_blank(),
      legend.title = ggplot2::element_blank()
    ) +
    ggplot2::ggtitle(title) +
    ggplot2::scale_color_manual(
      values = c(
        "No Stress"     = "#d2f8f9",
        "Watch"         = "#fcf050",
        "Warning"       = "#eead3e",
        "Alert Level 1" = "#dc2f21",
        "Alert Level 2" = "#891a10",
        "Alert Level 3" = "#6c1210",
        "Alert Level 4" = "#4a0d0d",
        "Alert Level 5" = "#2a0707"
      )
    ) + ggplot2::theme(legend.position.inside = legend_position)
}
