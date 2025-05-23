% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/check_missing_dates.R
\name{check_missing_dates}
\alias{check_missing_dates}
\title{Check missing dates}
\usage{
check_missing_dates(folder, start_date, end_date)
}
\arguments{
\item{folder}{input folder}

\item{start_date}{start date (YYYY-MM-DD)}

\item{end_date}{end date (YYYY-MM-DD)}
}
\value{
Vector of filenames that are missing or "No missing dates"
}
\description{
Function to check missing files by date in a folder
}
\examples{
\dontrun{

check_missing_dates(start_date="1981-09-01", end_date="2024-04-30",  "/Volumes/Extreme_SSD/dhw/OISST/gbr")
check_missing_dates(start_date="1981-09-01", end_date="2024-04-30",  "/Volumes/Extreme_SSD/dhw/OISST/global" )
check_missing_dates(start_date="1985-06-01", end_date="2024-04-30",  "/Volumes/Extreme_SSD/dhw/CRW/global/CRW_SST")
check_missing_dates(start_date="1985-06-01", end_date="2024-04-30",  "/Volumes/Extreme_SSD/dhw/CRW/global/CRW_SSTA")

}
}
