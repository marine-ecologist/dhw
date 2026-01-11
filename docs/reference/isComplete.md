# Check completeness of dated NetCDF files by filename

Scans one or more folders for `.nc` files (OISST and CoralTemp),
extracts the last `YYYYMMDD` token from each filename, parses to `Date`,
and evaluates completeness against a user-specified cadence. See
download_CoralTemp and download_OISST for further details.

## Usage

``` r
isComplete(
  paths,
  recurse = TRUE,
  date_regex = "(?<!\\d)(\\d{8})(?!\\d)",
  cadence_days = NULL,
  expected_start = NULL,
  expected_end = NULL,
  treat_duplicates_as_incomplete = FALSE
)
```

## Arguments

- paths:

  Character vector of directories to search.

- recurse:

  Logical; search subdirectories recursively. Default `TRUE`.

- date_regex:

  Character regex used to extract an 8-digit date (`YYYYMMDD`); the last
  match per filename is taken. Default `"(?<!\d)(\d{8})(?!\d)"`.

- cadence_days:

  Integer; expected step in days between consecutive dates, e.g., `1`
  (daily), `7` (weekly), `30` (monthly-ish). If `NULL` (default),
  cadence is inferred from the modal gap in observed dates.

- expected_start, expected_end:

  Optional inclusive bounds (coerced to `Date`) to clip files before
  completeness checking.

- treat_duplicates_as_incomplete:

  Logical; if `TRUE`, any date with multiple files will cause `FALSE` to
  be returned. Default `FALSE`.

## Value

Logical scalar. `TRUE` if no missing dates (and, if requested, no
duplicates) within the audited range; otherwise `FALSE`. The full audit
is attached as attribute `"audit"` with elements:

- `files` — tibble of files and parsed dates

- `summary` — tibble with coverage and counts

- `missing_dates` — tibble of missing `Date`s

- `duplicates` — tibble of duplicate dates with counts

## Examples

``` r
if (FALSE) { # \dontrun{
ok <- isComplete(
  paths = c("/data/crw/CRW_SST", "/data/crw/CRW_DHW"),
  cadence_days = 1,                         # daily
  expected_start = "1985-06-01",
  expected_end   = "2025-06-30",
  treat_duplicates_as_incomplete = TRUE
)
attr(ok, "audit")$summary
attr(ok, "audit")$missing_dates
} # }
```
