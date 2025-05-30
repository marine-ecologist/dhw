% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/download_gbr_spatial.R
\name{download_gbr_spatial}
\alias{download_gbr_spatial}
\title{Download GBR spatial data}
\usage{
download_gbr_spatial(crs = "EPSG:4283", return = "base")
}
\arguments{
\item{crs}{change the CRS if needed (EPSG:4283 as default)}

\item{return}{One of "combined", "hull", or "base"}
}
\value{
Simple feature collection with 9612 features and 35 fields
}
\description{
function to download the GBR shape files (14.1mb in size, shp file format) via eReefs

Notes:
There are several versions of the GBR reefs shape file. This version is downloaded via the eAtlas
Website and includes reefs from the Torres Strait. Default CRS is GDA94 (EPSG:4283)
}
\examples{
\dontrun{
eAtlas <- download_gbr_spatial(crs=4326)
}
}
