# Check missing dates

Function to check missing files by date in a folder

## Usage

``` r
check_missing_dates(folder, start_date, end_date)
```

## Arguments

- folder:

  input folder

- start_date:

  start date (YYYY-MM-DD)

- end_date:

  end date (YYYY-MM-DD)

## Value

Vector of filenames that are missing or "No missing dates"

## Examples

``` r
if (FALSE) { # \dontrun{

check_missing_dates(start_date="1981-09-01", end_date="2024-04-30",  "/Volumes/Extreme_SSD/dhw/OISST/gbr")
check_missing_dates(start_date="1981-09-01", end_date="2024-04-30",  "/Volumes/Extreme_SSD/dhw/OISST/global" )
check_missing_dates(start_date="1985-06-01", end_date="2024-04-30",  "/Volumes/Extreme_SSD/dhw/CRW/global/CRW_SST")
check_missing_dates(start_date="1985-06-01", end_date="2024-04-30",  "/Volumes/Extreme_SSD/dhw/CRW/global/CRW_SSTA")

} # }
```
