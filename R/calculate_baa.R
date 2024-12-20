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

#' See vignette for further details
#'
#' @param hotspots hotspots
#' @param window number of days to sum hotspots, default = 84 (12 weeks)
#' @returns degree heating weeks (terra::rast format)
#'
#' @export
#'
calculate_baa <- function(hotspots, dhw) {

  hotspotdhw <- sds(hotspots, dhw)

  categorize_baa <- function(hs, dhw) {
    ifelse(
      hs <= 0, 0,  # No Stress
      ifelse(hs > 0 & dhw < 4, 1,  # Bleaching Watch
             ifelse(hs >= 1 & dhw >= 4 & dhw < 8, 2,  # Bleaching Warning
                    ifelse(hs >= 1 & dhw >= 8 & dhw < 12, 3,  # Bleaching Alert Level 1
                           ifelse(hs >= 1 & dhw >= 12 & dhw < 16, 4,  # Bleaching Alert Level 2
                                  ifelse(hs >= 1 & dhw >= 16 & dhw < 20, 5,  # Bleaching Alert Level 3
                                         ifelse(hs >= 1 & dhw >= 20, 6, NA)  # Bleaching Alert Level 4
                                  )
                           )
                    )
             )
      )
    )
  }


  baa <- terra::app(
    hotspotdhw,
    fun = function(x) categorize_baa(x[1], x[2])
  )

  varnames(baa) <- "Bleaching Alert Area"
  return(baa)

}
