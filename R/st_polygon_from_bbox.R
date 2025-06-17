#' @name st_polygon_from_bbox
#' @title Create sf polygon from bbox
#' @description
#' Function to convert a bounding box to a polygon with correct CRS.
#'
#' @param boundaries in list: c(xmin, ymin, xmax, ymax)
#' @param output_crs desired output CRS (integer or string)
#' @return sf polygon
#' @export
#'
st_polygon_from_bbox <- function(bbox, output_crs) {
  # Create bbox with CRS if input is numeric
  if (!inherits(bbox, "bbox")) {
    bbox <- st_bbox(c(xmin = bbox[1], ymin = bbox[2], xmax = bbox[3], ymax = bbox[4]), crs = st_crs(4326))
  }

  # Convert to polygon with same CRS
  polygon <- st_as_sfc(bbox)

  # Transform to output CRS if needed
  polygon <- st_transform(polygon, crs = output_crs)

  return(polygon)
}
