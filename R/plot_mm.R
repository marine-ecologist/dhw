#' @name plot_mm
#' @title Plot mean monthly maximum for a given gridcell
#' @description
#' Plot mean monthly maximum for a given gridcell
#' from a terra::rast() file input
#'
#'
#'
#' @param input rast() file
#' @param lon vector of longitude
#' @param lat vector of latitude
#' @returns ggplot of baseline climatology
#'
#' @export
#'
plot_mm <- function(input, lon, lat) {

  # Create a point for the specified coordinates
  point <- terra::vect(cbind(lon, lat), crs = "EPSG:4326")

  # Extract the single cell as a SpatRaster
  input <- terra::mask(input, point)# |> terra::mask(point)

  # Convert input to a data frame
  input_df <- input |> terra::as.data.frame(xy = TRUE, wide = FALSE, time = TRUE)

  # Process annual data
  input_df_annual <- input_df |>
    dplyr::mutate(time = as.Date(time), year = lubridate::year(time), month = lubridate::month(time)) |>
    dplyr::group_by(year, month) |>
    dplyr::summarise(sst = mean(values), .groups = 'drop') |>
    dplyr::filter(year >= 1985, year <= 2012)

  # Calculate predictions, slopes, and intercepts
  input_predict_1998 <- input |> calculate_monthly_mean(return = "predict") |>
    terra::as.data.frame(xy = FALSE, wide = FALSE, time = FALSE) |>
    dplyr::mutate(month = 1:12)

  input_predict <- input |> calculate_monthly_mean(return = "predict", midpoint = 1988.2857) |>
    terra::as.data.frame(xy = FALSE, wide = FALSE, time = FALSE) |>
    dplyr::mutate(month = 1:12)

  input_slope <- input |> calculate_monthly_mean(return = "slope")
  input_intercept <- input |> calculate_monthly_mean(return = "intercept")

  # Prepare plot data
  plot_data <- input_df_annual |>
    dplyr::mutate(
      slope = sapply(month, function(m) as.numeric(input_slope[[m]][1])),
      intercept = sapply(month, function(m) as.numeric(input_intercept[[m]][1]))
    )

  # Create plot
  plot <- ggplot2::ggplot() +
    ggplot2::theme_bw() +
    ggplot2::facet_wrap(~month, ncol = 3, scales = "free") +
    ggplot2::geom_point(data = input_df_annual, ggplot2::aes(year, sst, fill = month),
                        alpha = 0.2, shape = 21, show.legend=FALSE) +
    ggplot2::scale_fill_distiller(palette = "RdBu") +

    # Predictions for 1998 and 1988.2857
    ggplot2::geom_point(data = input_predict_1998, ggplot2::aes(1998.5, values), color = "red", shape = 8, size = 3) +
    ggplot2::geom_point(data = input_predict, ggplot2::aes(1988.2857, values), color = "darkred", shape = 8, size = 3) +
    ggplot2::geom_text(data = input_predict_1998, ggplot2::aes(1998.5, values + 0.2, label = "1998.5"), color = "red", size = 3) +
    ggplot2::geom_text(data = input_predict, ggplot2::aes(1988.2857, values + 0.1, label = "1988.2857"), color = "darkred", size = 3) +

    # Regression lines
    ggplot2::geom_abline(data = plot_data, ggplot2::aes(slope = slope, intercept = intercept),
                         color = "black", linewidth = 0.75, alpha = 0.4) +

    ggplot2::scale_x_continuous(limits = c(1985, 2012), expand = c(0, 0)) +

    # Horizontal segments
    ggplot2::geom_segment(data = input_predict_1998,
                          ggplot2::aes(x = 1985, xend = 1998.5,
                                       y = values, yend = values),
                          color = "red") +
    ggplot2::geom_segment(data = input_predict,
                          ggplot2::aes(x = 1985, xend = 1988.2857,
                                       y = values, yend = values),
                          color = "darkred") +

    # Vertical segments
    ggplot2::geom_segment(data = input_predict_1998,
                          ggplot2::aes(x = 1998.5, xend = 1998.5,
                                       y = min(plot_data$sst), yend = values),
                          color = "red") +
    ggplot2::geom_segment(data = input_predict,
                          ggplot2::aes(x = 1988.2857, xend = 1988.2857,
                                       y = min(plot_data$sst), yend = values),
                          color = "darkred")

  return(plot)
}
