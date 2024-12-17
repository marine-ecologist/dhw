plot2 <- function(x,y){

  plot(terra::values(x) |> as.numeric(),
       terra::values(y) |> as.numeric())

  graphics::abline(a = 0, b = 1, col = "red", lwd = 2, lty = 2)

}
