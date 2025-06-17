#' @title Plot annual maximum DHW time series
#' @name plot_annual_dhw_max
#' @description
#' Compute annual maxima from a DHW \code{SpatRaster} and return a wide data.frame
#' with columns \code{year} and \code{maxdhw}, plus a ggplot showing bars for each year.
#'
#' @param dhw_rast A \code{terra::SpatRaster} of Degree Heating Weeks with a valid time vector.
#' @param pad_years_left Integer, years to extend the left x-axis beyond min year (default 1).
#' @param pad_years_right Integer, years to extend the right x-axis beyond max year (default 1).
#' @param x_break_by Integer, spacing between x-axis breaks in years (default 2).
#' @param fill_limits Numeric length-2, limits for the fill gradient (default \code{c(0, 26)}).
#' @param fill_midpoint Numeric, midpoint for \code{ggplot2::scale_fill_gradient2} (default 3).
#' @return A list with:
#' \itemize{
#'   \item \code{data}: \code{tibble} with columns \code{year} (integer) and \code{maxdhw} (double)
#'   \item \code{plot}: \code{ggplot} object of the annual maxima bar chart
#' }
#' @examples
#' \dontrun{
#' out <- plot_annual_dhw_max(ningaloo_climatology$dhw)
#' out$data
#' print(out$plot)
#' }
#' @export
plot_max_dhw <- function(dhw_rast) {

  stopifnot(inherits(dhw_rast, "SpatRaster"))



  # annual max across layers grouped by year from the raster's time vector
  annual_max <- terra::tapp(
    x     = dhw_rast,
    index = base::format(terra::time(dhw_rast), "%Y"),
    fun   = base::max,
    na.rm = TRUE
  )

  # clean names like "X1982" -> "1982"
  base::names(annual_max) <- base::sub("^X", "", base::names(annual_max))

  # to data.frame (wide=layer names -> columns), then long to year/maxdhw
  inputmax <- terra::as.data.frame(annual_max, xy = FALSE) |>
    tidyr::pivot_longer(
      cols      = tidyselect::everything(),
      names_to  = "year",
      values_to = "maxdhw"
    ) |>
    dplyr::mutate(year = base::as.integer(.data$year))

  start_year <- base::min(inputmax$year, na.rm = TRUE) - 1
  end_year   <- base::max(inputmax$year, na.rm = TRUE) + 1

  fill_limits = c(0, base::max(inputmax$maxdhw))
  fill_midpoint = fill_limits[2]/4


  p <- ggplot2::ggplot() +
    ggplot2::theme_bw() +
    ggplot2::scale_x_continuous(
      limits = c(start_year, end_year),
      breaks = base::seq(start_year, end_year, by = 2),
      labels = base::seq(start_year, end_year, by = 2),
      expand = c(0, 0)
    ) +
    ggplot2::geom_col(
      data = inputmax,
      ggplot2::aes(x = .data$year, y = .data$maxdhw, fill = .data$maxdhw),
      show.legend = FALSE,
      linewidth = 0.25,
      color = "black"
    ) +
    ggplot2::ylab("Maximum annual DHW") +
    ggplot2::scale_fill_gradient2(
      midpoint = fill_midpoint,
      low  = RColorBrewer::brewer.pal(9, "RdBu")[9],
      mid  = RColorBrewer::brewer.pal(9, "RdBu")[5],
      high = RColorBrewer::brewer.pal(9, "RdBu")[1],
      limits = fill_limits
    ) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5, hjust = 1))

  p
}
