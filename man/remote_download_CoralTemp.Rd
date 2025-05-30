% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/remote_download_CoralTemp.R
\name{remote_download_CoralTemp}
\alias{remote_download_CoralTemp}
\title{Download Latest CoralTemp Dataset(s) from NOAA THREDDS Server}
\usage{
remote_download_CoralTemp(
  dataset = "all",
  folder = ".",
  reefs = GBR_hull,
  quiet = FALSE
)
}
\arguments{
\item{dataset}{Character. One of \code{"sst"}, \code{"ssta"}, \code{"dhw"}, \code{"hs"}, \code{"baa"}, or \code{"all"}.}

\item{folder}{Character. Local directory where files will be saved.}

\item{reefs}{shp file input, use dhw::download_gbr_spatial(return = "hull", crs = "EPSG:7844")}
}
\value{
Downloads the latest file(s) to the specified folder.
}
\description{
Downloads the most recent \code{.nc} file for selected CoralTemp variable(s)
from NOAA's THREDDS server into a local folder. Automatically skips download if the file exists.
}
\examples{
\dontrun{
GBR_hull = download_gbr_spatial(return = "hull", crs = "EPSG:7844")
remote_download_CoralTemp(dataset = "sst", folder = "data/", reefs = GBR_hull)
remote_download_CoralTemp(dataset = "all", folder = "data/", reefs = GBR_hull)
}
}
