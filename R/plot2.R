#' @name plot2
#' @title Simple XY plot for terra::rast values() comparisons
#' @description
#'
#'
#' Helper function to quickly visualise the values of two terra::rast files in a base r xy plot (with abline)
#' Assumes one var per rast
#'
#'
#' @param x terra::rast(a)
#' @param y terra::rast(b)
#' @returns base R plot
#' @export



plot2 <- function(x,y){

  plot(terra::values(x) |> as.numeric(),
       terra::values(y) |> as.numeric())

  graphics::abline(a = 0, b = 1, col = "red", lwd = 2, lty = 2)

}
