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
#' @param targetyear Integer target year for the season window (plots Nov of
#'   \code{targetyear-1} through Jul of \code{targetyear}).
#'
#' @return A \code{ggplot2} object.
#'
#' @examples
#' \dontrun{
#' p <- plot_year(ningaloo_climatology, targetyear = 2025)
#' print(p)
#' }
#' @export
plot_sst_timeseries <- function(input, targetyear) {

  # ---- window: Nov (year-1) -> Jul (year) ----
  start_target_date <- base::as.Date(sprintf("%d-11-01", targetyear - 1))
  end_target_date   <- base::as.Date(sprintf("%d-07-31", targetyear))

  # ---- flatten rasters to a tidy df (lon/lat/time + variables) ----
  input_df <- dhw::as_climatology_df(
    input,
    vars = c("sst", "climatology", "anomaly", "hotspots", "dhw"),
    xy   = TRUE,
    rename_xy = TRUE
  )

  # derive year/month/day from time (robust even if not present)
  input_df <- input_df |>
    dplyr::ungroup() |>
    dplyr::mutate(
      year  = lubridate::year(.data$time),
      month = lubridate::month(.data$time),
      day   = lubridate::day(.data$time)
    )

  input_df_target <- input_df |>
    dplyr::filter(.data$year %in% c(targetyear, targetyear - 1))

  # ---- get MMM value (scalar) ----
  # Prefer the first cell; if the raster has multiple cells, you may replace with global mean/max.
  mmm_val <- {
    v <- terra::values(input$mmm)
    if (length(v) == 0L) NA_real_ else base::as.numeric(v[1])
  }

  # ---- prepare plotting df with alert levels & fill areas ----
  plot_df <- input_df |>
    dplyr::mutate(
      mmm_line   = mmm_val,
      dashed_line = mmm_val + 1,
      bleachingwatch = dplyr::case_when(
        .data$hotspots <= 0                                 ~ "No Stress",
        .data$hotspots > 0  & .data$hotspots < 1           ~ "Watch",
        .data$hotspots >= 1 & .data$dhw < 4                ~ "Warning",
        .data$hotspots >= 1 & .data$dhw >= 4  & .data$dhw < 8   ~ "Alert Level 1",
        .data$hotspots >= 1 & .data$dhw >= 8  & .data$dhw < 12  ~ "Alert Level 2",
        .data$hotspots >= 1 & .data$dhw >= 12 & .data$dhw < 16  ~ "Alert Level 3",
        .data$hotspots >= 1 & .data$dhw >= 16 & .data$dhw < 20  ~ "Alert Level 4",
        .data$hotspots >= 1 & .data$dhw >= 20              ~ "Alert Level 5",
        TRUE ~ NA_character_
      ),
      bleachingwatch = base::factor(
        .data$bleachingwatch,
        levels = c("No Stress","Watch","Warning",
                   "Alert Level 1","Alert Level 2","Alert Level 3","Alert Level 4","Alert Level 5")
      ),
      fill_area = ifelse(.data$sst > .data$dashed_line, .data$sst, .data$dashed_line),
      mmm_area  = ifelse(.data$sst < .data$mmm_line,    .data$mmm_line, .data$sst)
    ) |>
    dplyr::filter(.data$year %in% c(targetyear, targetyear - 1)) |>
    dplyr::filter(.data$time >= start_target_date, .data$time <= end_target_date)

  # y-band for the bottom status strip
  y0 <- base::floor(base::min(plot_df$sst, na.rm = TRUE)) - 1
  y1 <- y0 + 0.5

  # ---- build plot ----
  p <- ggplot2::ggplot(plot_df) +
    ggplot2::theme_bw() +

    ggplot2::geom_vline(
      xintercept = base::as.Date(sprintf("%d-01-01", targetyear)),
      color = "darkgrey", linewidth = 0.5
    ) +

    # bottom bleaching status strip (daily color along x)
    ggplot2::geom_linerange(
      ggplot2::aes(x = .data$time, ymin = y0, ymax = y1, color = .data$bleachingwatch),
      linewidth = 2
    ) +
    ggplot2::geom_rect(
      ggplot2::aes(
        xmin = base::as.Date(sprintf("%d-11-01", targetyear - 1)),
        xmax = base::as.Date(sprintf("%d-07-01", targetyear)),
        ymin = y0,
        ymax = y1
      ),
      color = "black", fill = "transparent", linewidth = 0.2
    ) +

    # shading below MMM (up to SST when SST < MMM)
    ggpattern::geom_ribbon_pattern(
      ggplot2::aes(x = .data$time, ymin = mmm_val, ymax = .data$mmm_area),
      na.rm = TRUE,
      pattern = "gradient",
      fill = "#00000000",
      pattern_fill = "darkgoldenrod2",
      pattern_fill2 = "darkgoldenrod2"
    ) +

    # shading above MMM+1 (from dashed_line up to SST)
    ggpattern::geom_ribbon_pattern(
      ggplot2::aes(x = .data$time, ymin = .data$dashed_line, ymax = .data$fill_area),
      na.rm = TRUE,
      pattern = "gradient",
      fill = "#00000000",
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
      ggplot2::aes(base::as.Date(sprintf("%d-01-09", targetyear)),
                   base::ceiling(base::max(plot_df$sst, na.rm = TRUE)),
                   label = targetyear),
      size = 4, color = "darkgrey"
    ) +
    ggplot2::geom_text(
      ggplot2::aes(base::as.Date(sprintf("%d-12-23", targetyear - 1)),
                   base::ceiling(base::max(plot_df$sst, na.rm = TRUE)),
                   label = targetyear - 1),
      size = 4, color = "darkgrey"
    ) +
    ggplot2::geom_text(
      ggplot2::aes(base::as.Date(sprintf("%d-11-09", targetyear - 1)), mmm_val + 0.2, label = "MMM"),
      size = 4, color = "darkred"
    ) +
    ggplot2::geom_text(
      ggplot2::aes(base::as.Date(sprintf("%d-11-17", targetyear - 1)), mmm_val + 1.2, label = "MMM + 1°C"),
      size = 4, color = "darkred"
    ) +
    ggplot2::geom_text(
      ggplot2::aes(base::as.Date(sprintf("%d-11-26", targetyear - 1)), y1 + 0.5,
                   label = "Bleaching alert status"),
      size = 4, color = "black"
    ) +

    ggplot2::scale_x_date(
      date_breaks = "1 month",
      date_labels = "%b",
      limits = base::as.Date(c(sprintf("%d-11-01", targetyear - 1),
                               sprintf("%d-07-01", targetyear)))
    ) +
    ggplot2::scale_y_continuous(
      limits = c(y0, base::ceiling(base::max(plot_df$sst, na.rm = TRUE)))
    ) +

    ggplot2::labs(x = "\nMonth", y = "Sea Surface Temperature (°C) [NOAA CRW SST]\n") +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = c(0.99, 0.99),
      legend.justification = c("right", "top"),
      legend.background = ggplot2::element_rect(fill = "white", color = NA),
      legend.box.background = ggplot2::element_blank(),
      legend.title = ggplot2::element_blank()
    ) +
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
    )

  p
}
