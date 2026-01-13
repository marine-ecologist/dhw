#' Check completeness of dated NetCDF files by filename
#'
#' Scans one or more folders for \code{.nc} files (OISST and CoralTemp), extracts the last \code{YYYYMMDD}
#' token from each filename, parses to \code{Date}, and evaluates completeness
#' against a user-specified cadence. See download_CoralTemp and download_OISST for further details.
#'
#' @param paths Character vector of directories to search.
#' @param recurse Logical; search subdirectories recursively. Default \code{TRUE}.
#' @param date_regex Character regex used to extract an 8-digit date (\code{YYYYMMDD});
#'   the last match per filename is taken. Default \code{"(?<!\\d)(\\d{8})(?!\\d)"}.
#' @param cadence_days Integer; expected step in days between consecutive dates,
#'   e.g., \code{1} (daily), \code{7} (weekly), \code{30} (monthly-ish). If \code{NULL}
#'   (default), cadence is inferred from the modal gap in observed dates.
#' @param expected_start,expected_end Optional inclusive bounds (coerced to \code{Date})
#'   to clip files before completeness checking.
#' @param treat_duplicates_as_incomplete Logical; if \code{TRUE}, any date with
#'   multiple files will cause \code{FALSE} to be returned. Default \code{FALSE}.
#'
#' @return Logical scalar. \code{TRUE} if no missing dates (and, if requested,
#'   no duplicates) within the audited range; otherwise \code{FALSE}.
#'   The full audit is attached as attribute \code{"audit"} with elements:
#'   \itemize{
#'     \item \code{files} — tibble of files and parsed dates
#'     \item \code{summary} — tibble with coverage and counts
#'     \item \code{missing_dates} — tibble of missing \code{Date}s
#'     \item \code{duplicates} — tibble of duplicate dates with counts
#'   }
#'
#' @examples
#' \dontrun{
#' ok <- isComplete(
#'   paths = c("/data/crw/CRW_SST", "/data/crw/CRW_DHW"),
#'   cadence_days = 1,                         # daily
#'   expected_start = "1985-06-01",
#'   expected_end   = "2025-06-30",
#'   treat_duplicates_as_incomplete = TRUE
#' )
#' attr(ok, "audit")$summary
#' attr(ok, "audit")$missing_dates
#' }
#'
#' @export



isComplete <- function(paths,
                       recurse = TRUE,
                       date_regex = "(?<!\\d)(\\d{8})(?!\\d)",
                       cadence_days = NULL,         # e.g., 1=daily, 7=weekly; NULL = infer
                       expected_start = NULL,
                       expected_end   = NULL,
                       treat_duplicates_as_incomplete = FALSE) {

  stopifnot(length(paths) >= 1)

  # collect files
  files_tbl <- purrr::map(paths, \(p) {
    tibble::tibble(
      dir  = p,
      file = list.files(p, pattern = "\\.nc$", full.names = TRUE,
                        recursive = recurse, ignore.case = TRUE)
    )
  }) %>%
    list_rbind()

  if (nrow(files_tbl) == 0) {
    audit <- list(
      files = tibble::tibble(),
      summary = tibble::tibble(start = as.Date(NA), end = as.Date(NA),
                               n_files = 0, n_unique_dates = 0,
                               cadence_days = NA_integer_, n_missing = NA_integer_,
                               n_duplicates = 0L),
      missing_dates = tibble::tibble(date = as.Date(character())),
      duplicates = tibble::tibble(date = as.Date(character()), n = integer())
    )
    out <- FALSE
    attr(out, "audit") <- audit
    return(out)
  }

  # parse dates from filenames (use last 8-digit token)
  files_tbl <- files_tbl %>%
    dplyr::mutate(
      fname = basename(.data$file),
      date_str = stringr::str_extract_all(.data$fname, date_regex) %>%
        purrr::map_chr(~ if (length(.x)) utils::tail(.x, 1) else NA_character_),
      date = ifelse(!is.na(.data$date_str) & nchar(.data$date_str) == 8,
                    .data$date_str, NA_character_) %>%
        as.Date(format = "%Y%m%d")
    ) %>%
    dplyr::filter(!is.na(.data$date))

  if (nrow(files_tbl) == 0) {
    audit <- list(
      files = tibble::tibble(),
      summary = tibble::tibble(start = as.Date(NA), end = as.Date(NA),
                               n_files = 0, n_unique_dates = 0,
                               cadence_days = NA_integer_, n_missing = NA_integer_,
                               n_duplicates = 0L),
      missing_dates = tibble::tibble(date = as.Date(character())),
      duplicates = tibble::tibble(date = as.Date(character()), n = integer())
    )
    out <- FALSE
    attr(out, "audit") <- audit
    return(out)
  }

  # optional clip to expected range
  if (!is.null(expected_start)) files_tbl <- dplyr::filter(files_tbl, .data$date >= as.Date(expected_start))
  if (!is.null(expected_end))   files_tbl <- dplyr::filter(files_tbl, .data$date <= as.Date(expected_end))

  if (nrow(files_tbl) == 0) {
    audit <- list(
      files = tibble::tibble(),
      summary = tibble::tibble(start = as.Date(NA), end = as.Date(NA),
                               n_files = 0, n_unique_dates = 0,
                               cadence_days = if (is.null(cadence_days)) NA_integer_ else as.integer(cadence_days),
                               n_missing = NA_integer_, n_duplicates = 0L),
      missing_dates = tibble::tibble(date = as.Date(character())),
      duplicates = tibble::tibble(date = as.Date(character()), n = integer())
    )
    out <- FALSE
    attr(out, "audit") <- audit
    return(out)
  }

  dates <- sort(unique(files_tbl$date))

  # infer cadence if needed
  if (is.null(cadence_days)) {
    diffs <- as.integer(diff(dates))
    cadence_days <- if (length(diffs) == 0) 1L else {
      md <- suppressWarnings(as.integer(names(which.max(table(diffs)))))
      if (is.na(md) || md < 1L) 1L else md
    }
  } else {
    cadence_days <- as.integer(cadence_days)
    if (is.na(cadence_days) || cadence_days < 1L) cadence_days <- 1L
  }

  start_date <- min(dates)
  end_date   <- max(dates)
  expected_seq <- seq.Date(start_date, end_date, by = cadence_days)

  missing <- sort(setdiff(expected_seq, dates))
  duplicates <- files_tbl %>%
    dplyr::count(.data$date, name = "n") %>%
    dplyr::filter(.data$n > 1L)

  summary_tbl <- tibble::tibble(
    start = start_date,
    end = end_date,
    n_files = nrow(files_tbl),
    n_unique_dates = length(dates),
    cadence_days = cadence_days,
    n_missing = length(missing),
    n_duplicates = nrow(duplicates)
  )

  audit <- list(
    files = dplyr::arrange(files_tbl, .data$date, .data$fname),
    summary = summary_tbl,
    missing_dates = tibble::tibble(date = as.Date(missing)),
    duplicates = duplicates
  )

  complete_flag <- (summary_tbl$n_missing == 0L) &&
    (!treat_duplicates_as_incomplete || summary_tbl$n_duplicates == 0L)

  attr(complete_flag, "audit") <- audit
  complete_flag
}
