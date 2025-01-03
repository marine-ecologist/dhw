% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/process_ERA5.R
\name{process_ERA5}
\alias{process_ERA5}
\title{Process ERA5 NetCDF Files}
\usage{
process_ERA5(folder, units = "celsius")
}
\arguments{
\item{folder}{Folder containing NetCDF (.nc) files.}

\item{units}{Units for temperature: one of "celsius" or "kelvin". Default is "celsius".}
}
\value{
A combined SpatRaster object in ERA5 format.
}
\description{
Function to extract and combine SST data from NetCDF files in a specified folder.

See vignette for further details.
}
\examples{
\dontrun{
folder <- "/Users/rof011/GBR-dhw/datasets/era5/"
process_ERA5(folder, units = "celsius")
}
}
