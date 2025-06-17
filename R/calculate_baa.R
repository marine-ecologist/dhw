#' @name calculate_baa
#' @title Calculate BAA
#' @description
#' Function to calculate bleaching alert area (BAA)
#'
#' The BAA  outlines the current locations, coverage, and potential risk level of coral bleaching heat stress around the world.
#'
#' The heat stress level in the individual Bleaching Alert Area single-day products at a 5km satellite data grid, on any day,
#' is based on SST for that day. The coral bleaching heat stress levels are defined in the table below (updated in December 2023):
#'
#'
#' No Stress                 ---   HotSpot <= 0
#' Bleaching Watch           ---   0 < HotSpot < 1
#' Bleaching Warning         ---   1 <= HotSpot and 0 < DHW < 4
#' Bleaching Alert Level 1   ---   1 <= HotSpot and 4 <= DHW < 8
#' Bleaching Alert Level 2   ---   1 <= HotSpot and 8 <= DHW < 12
#' Bleaching Alert Level 3   ---   1 <= HotSpot and 12 <= DHW < 16
#' Bleaching Alert Level 4   ---   1 <= HotSpot and 16 <= DHW < 20
#' Bleaching Alert Level 5   ---   1 <= HotSpot and 20 <= DHW

#' See vignette for further details.
#'
#' @param hs hotspots
#' @param dhw dhw
#' @returns degree heating weeks (terra::rast format)
#'
#' @export
#'
calculate_baa <- function(hs, dhw) {

  hotspotdhw <- terra::sds(hs, dhw)

  # Vectorized categorization function
  categorize_baa <- function(hs, dhw) {
    # Treat NaN in dhw as 0
    dhw[is.nan(dhw)] <- 0

    # Initialize output
    result <- rep(NA, length(hs))

    result[hs <= 0] <- 0  # No Stress
    result[hs > 0 & hs < 1 & dhw < 4] <- 1  # Bleaching Watch
    result[hs >= 1 & dhw < 4] <- 2  # Bleaching Warning
    result[hs >= 1 & dhw >= 4 & dhw < 8] <- 3  # Bleaching Alert Level 1
    result[hs >= 1 & dhw >= 8 & dhw < 12] <- 4 # Bleaching Alert Level 2
    result[hs >= 1 & dhw >= 12 & dhw < 16] <- 5 # Bleaching Alert Level 3
    result[hs >= 1 & dhw >= 16 & dhw < 20] <- 6 # Bleaching Alert Level 4
    result[hs >= 1 & dhw >= 20] <- 7  # Bleaching Alert Level 5

    return(result)
  }

  baa <- terra::app(
    hotspotdhw,
    fun = function(x) categorize_baa(x[1], x[2])
  )

  terra::varnames(baa) <- "Bleaching Alert Area"
  return(baa)
}

