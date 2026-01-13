#' Hindcast Bias-Corrected Raster Time Series via Monthly Anomaly Quantile Mapping (QM/QDM)
#'
#' Reconstructs (hindcasts) an extended raster time series by bias-correcting a long
#' model dataset against a shorter observed/reference dataset using **monthly anomaly
#' Quantile Mapping (QM)** or **Quantile Delta Mapping (QDM; Cannon-style)**.
#'
#' This implementation operates **per grid cell**, applies corrections
#' **independently for each calendar month**, and performs computations **in memory**
#' to avoid block-wise I/O workflows.
#'
#' @section Conceptual workflow:
#' \enumerate{
#'   \item Align `input2` to `input1` (resample) if geometries differ.
#'   \item Identify a calibration period from overlapping dates (optionally constrained by `overlap_period`).
#'   \item For each grid cell and month:
#'     \enumerate{
#'       \item Compute monthly climatologies over the calibration overlap for observed and model.
#'       \item Convert calibration series to monthly anomalies (value minus monthly climatology).
#'       \item Convert hindcast (pre-observed) model values to anomalies (minus model monthly climatology).
#'       \item Apply either:
#'         \itemize{
#'           \item \strong{QM}: map model-historical anomaly distribution to observed anomaly distribution.
#'           \item \strong{QDM}: preserve model hindcast anomaly changes by adding the model delta at the same quantile:
#'                 \deqn{\hat{y} = F_{obs}^{-1}(\tau) + \left(x - F_{mod,hist}^{-1}(\tau)\right), \;\; \tau = F_{mod,proj}(x)}
#'         }
#'       \item Reconstruct absolute values using observed monthly climatology.
#'     }
#'   \item Optionally concatenate the hindcast with the original observed series.
#' }
#'
#' Working in anomaly space preserves the seasonal cycle and reduces variance inflation
#' often seen when mapping absolute values directly.
#'
#' @param input1 terra::SpatRaster
#'   Reference (observed) raster with the **shorter** time series. Must have a valid
#'   Date vector set via `terra::time(input1)`.
#'
#' @param input2 terra::SpatRaster
#'   Model raster with the **longer** time series extending earlier than `input1`.
#'   Must have a valid Date vector set via `terra::time(input2)`.
#'
#' @param n_quantiles integer
#'   Number of quantiles used for mapping (default `100`). Typical range: `50` to `200`.
#'
#' @param method character
#'   Bias-correction method, one of:
#'   \describe{
#'     \item{"qm"}{Quantile Mapping on anomalies (distribution matching).}
#'     \item{"qdm"}{Quantile Delta Mapping (Cannon-style) on anomalies; preserves model anomaly changes.}
#'   }
#'
#' @param overlap_period character vector of length 2 or `NULL`
#'   Optional calibration window `c(start_date, end_date)` in `"YYYY-MM-DD"` format.
#'   If `NULL` (default), the full overlap is used.
#'
#' @param combine logical
#'   If `TRUE` (default), returns a continuous raster combining the hindcast period
#'   with the original observed data, ordered by time. If `FALSE`, returns only the hindcast period.
#'
#' @param filename character or `NULL`
#'   Output filename for the raster. If `NULL` (default), returns a raster in memory.
#'
#' @param overwrite logical
#'   Overwrite an existing file if `TRUE` (default).
#'
#' @param wopt list
#'   Write options passed to `terra::writeRaster()`. Defaults to float storage with LZW compression:
#'   `list(datatype = "FLT4S", gdal = c("COMPRESS=LZW"))`.
#'
#' @param min_n integer
#'   Minimum number of non-`NA` observations per **month** and **cell** required during the
#'   calibration period to perform mapping (default `10`). Months/cells failing this remain `NA`.
#'
#' @param verbose logical
#'   If `TRUE` (default), prints progress messages unless `silent = TRUE`.
#'
#' @param silent logical
#'   If `TRUE` (default), suppresses messages regardless of `verbose`.
#'
#' @return terra::SpatRaster
#'   Bias-corrected hindcast raster. If `combine = TRUE`, spans from the earliest date in `input2`
#'   through the latest date in `input1`. If `combine = FALSE`, spans only the hindcast period.
#'
#' @details
#' \itemize{
#'   \item Correction is independent for each grid cell and calendar month.
#'   \item Monthly climatologies are computed only from the calibration overlap.
#'   \item Cells/months with insufficient calibration data (`min_n`) remain `NA`.
#'   \item All raster values for calibration and hindcast periods are read into memory; large domains may require substantial RAM.
#'   \item The `filename` write uses a temporary file then renames, to avoid "source and target are the same" issues.
#' }
#'
#' @references
#' Cannon, A. J., Sobie, S. R., & Murdock, T. Q. (2015).
#' Bias correction of GCM precipitation by quantile mapping: How well do methods preserve changes in quantiles and extremes?
#' \emph{Journal of Climate}, 28(17), 6938–6959.
#'
#' Cannon, A. J. (2015).
#' Selecting GCM scenarios that span the range of changes in a multimodel ensemble.
#' \emph{Journal of Climate}, 28(3), 1260–1267.
#'
#' @examples
#' \dontrun{
#' library(terra)
#'
#' obs <- rast("GBR_OISST_SST.tif")  # observed shorter series
#' mod <- rast("GBR_ERA5_SST.tif")   # model longer series (extends earlier)
#'
#' # QM hindcast (in memory)
#' out_qm <- hindcast_qm2(
#'   input1 = obs,
#'   input2 = mod,
#'   method = "qm",
#'   n_quantiles = 100,
#'   overlap_period = c("1982-01-01", "2025-12-31"),
#'   combine = TRUE,
#'   filename = NULL
#' )
#'
#' # QDM hindcast (write to disk)
#' out_qdm <- hindcast_qm2(
#'   input1 = obs,
#'   input2 = mod,
#'   method = "qdm",
#'   n_quantiles = 100,
#'   overlap_period = c("1982-01-01", "2025-12-31"),
#'   combine = TRUE,
#'   filename = "GBR_OISST2_SST_anomQDM_month.tif",
#'   overwrite = TRUE
#' )
#' }
#'
#' @importFrom terra compareGeom resample values rast time setValues writeRaster
#' @importFrom lubridate month
#' @importFrom stats quantile approx
#' @export
#'
hindcast <- function(input1, input2,
                         n_quantiles = 100,
                         method = c("qm", "qdm"),
                         overlap_period = NULL,
                         combine = TRUE,
                         filename = NULL,
                         overwrite = TRUE,
                         wopt = list(datatype = "FLT4S", gdal = c("COMPRESS=LZW")),
                         min_n = 10,
                         verbose = TRUE,
                         silent = TRUE) {

  method <- tolower(match.arg(method))

  msg <- function(...) {
    if (!silent && isTRUE(verbose)) cat(..., "\n")
  }

  as_date_time <- function(x) {
    tt <- terra::time(x)
    if (inherits(tt, "Date")) return(tt)
    if (inherits(tt, "POSIXt")) return(as.Date(tt))
    if (is.numeric(tt)) return(as.Date(tt, origin = "1970-01-01"))
    as.Date(tt)
  }

  probs <- seq(0, 1, length.out = n_quantiles)

  safe_q <- function(x) {
    stats::quantile(as.numeric(x), probs, na.rm = TRUE, names = FALSE, type = 8)
  }

  inv_cdf <- function(q, qq) {
    stats::approx(x = probs, y = qq, xout = q, rule = 2, ties = "ordered")$y
  }

  cdf_pos <- function(x, qq) {
    stats::approx(x = qq, y = probs, xout = x, rule = 2, ties = "ordered")$y
  }

  qm_adjust <- function(obs_anom, mod_hist_anom, x_anom) {
    oq <- safe_q(obs_anom)
    mq <- safe_q(mod_hist_anom)

    if (sum(!is.na(oq)) < 2 || sum(!is.na(mq)) < 2) return(rep(NA_real_, length(x_anom)))
    if (length(unique(mq[!is.na(mq)])) < 2) return(rep(NA_real_, length(x_anom)))

    tau <- cdf_pos(x_anom, mq)       # tau = F_mod_hist(x)
    inv_cdf(tau, oq)                 # F_obs^{-1}(tau)
  }

  qdm_adjust <- function(obs_anom, mod_hist_anom, mod_proj_anom, x_anom) {
    oq <- safe_q(obs_anom)
    mq <- safe_q(mod_hist_anom)
    pq <- safe_q(mod_proj_anom)

    if (sum(!is.na(oq)) < 2 || sum(!is.na(mq)) < 2 || sum(!is.na(pq)) < 2) {
      return(rep(NA_real_, length(x_anom)))
    }
    if (length(unique(mq[!is.na(mq)])) < 2) return(rep(NA_real_, length(x_anom)))
    if (length(unique(pq[!is.na(pq)])) < 2) return(rep(NA_real_, length(x_anom)))

    tau <- cdf_pos(x_anom, pq)       # tau = F_mod_proj(x)
    mod_hist_at_tau <- inv_cdf(tau, mq)
    obs_at_tau      <- inv_cdf(tau, oq)

    obs_at_tau + (x_anom - mod_hist_at_tau)
  }

  # ---- align geometry
  if (!terra::compareGeom(input1, input2, stopOnError = FALSE)) {
    msg("compareGeom=FALSE -> resampling input2 to input1")
    input2 <- terra::resample(input2, input1, method = "bilinear")
  }

  # ---- time + overlap
  t1 <- as_date_time(input1)
  t2 <- as_date_time(input2)

  if (any(is.na(t1)) || any(is.na(t2))) stop("Missing time values in input rasters.")
  if (is.unsorted(t1, strictly = TRUE)) stop("time(input1) must be strictly increasing.")
  if (is.unsorted(t2, strictly = TRUE)) stop("time(input2) must be strictly increasing.")

  msg("t1:", format(min(t1)), "..", format(max(t1)), "(", length(t1), ")")
  msg("t2:", format(min(t2)), "..", format(max(t2)), "(", length(t2), ")")

  overlap_start <- max(min(t1), min(t2))
  overlap_end   <- min(max(t1), max(t2))
  if (!is.null(overlap_period)) {
    overlap_start <- max(overlap_start, as.Date(overlap_period[1]))
    overlap_end   <- min(overlap_end,   as.Date(overlap_period[2]))
  }
  msg("overlap:", format(overlap_start), "..", format(overlap_end))

  d1_overlap <- t1[t1 >= overlap_start & t1 <= overlap_end]
  d2_overlap <- t2[t2 >= overlap_start & t2 <= overlap_end]
  common_dates <- as.Date(
    intersect(as.numeric(d1_overlap), as.numeric(d2_overlap)),
    origin = "1970-01-01"
  ) %>%
    sort()

  if (!length(common_dates)) stop("No matching dates found in overlap period.")

  idx1_cal <- match(common_dates, t1)
  idx2_cal <- match(common_dates, t2)

  hind_dates <- t2[t2 < min(t1)]
  if (!length(hind_dates)) stop("No hindcast period: input2 does not start before input1.")
  idx2_hind <- which(t2 %in% hind_dates)

  msg("hind:", format(min(hind_dates)), "..", format(max(hind_dates)), "(", length(hind_dates), ")")

  # ---- month partitions
  cal_month  <- lubridate::month(common_dates)
  hind_month <- lubridate::month(hind_dates)
  cal_idx_by_month  <- lapply(1:12, \(m) which(cal_month == m))
  hind_idx_by_month <- lapply(1:12, \(m) which(hind_month == m))

  # ---- pull values
  msg("reading values into memory (mat=TRUE) ...")
  obs_cal_mat  <- terra::values(input1[[idx1_cal]], mat = TRUE)
  mod_cal_mat  <- terra::values(input2[[idx2_cal]], mat = TRUE)
  mod_hind_mat <- terra::values(input2[[idx2_hind]], mat = TRUE)

  storage.mode(obs_cal_mat)  <- "numeric"
  storage.mode(mod_cal_mat)  <- "numeric"
  storage.mode(mod_hind_mat) <- "numeric"

  ncell_all <- nrow(mod_hind_mat)
  nhind     <- ncol(mod_hind_mat)

  msg("mat dims:",
      "obs_cal",  paste(dim(obs_cal_mat), collapse = "x"),
      "mod_cal",  paste(dim(mod_cal_mat), collapse = "x"),
      "mod_hind", paste(dim(mod_hind_mat), collapse = "x"))

  out_mat <- matrix(NA_real_, nrow = ncell_all, ncol = nhind)

  msg("computing per-cell monthly", method, "...")
  for (i in seq_len(ncell_all)) {
    obs_cal  <- obs_cal_mat[i, ]
    mod_cal  <- mod_cal_mat[i, ]
    mod_hind <- mod_hind_mat[i, ]

    if (all(is.na(mod_hind))) next

    for (m in 1:12) {
      ci <- cal_idx_by_month[[m]]
      hi <- hind_idx_by_month[[m]]
      if (!length(hi)) next

      obs_m <- obs_cal[ci]
      mod_m <- mod_cal[ci]

      if (sum(!is.na(obs_m)) < min_n || sum(!is.na(mod_m)) < min_n) next

      obs_clim <- mean(obs_m, na.rm = TRUE)
      mod_clim <- mean(mod_m, na.rm = TRUE)
      if (is.na(obs_clim) || is.na(mod_clim)) next

      obs_anom <- obs_m - obs_clim
      mod_anom <- mod_m - mod_clim

      x_raw <- mod_hind[hi]
      ok <- !is.na(x_raw)
      if (!any(ok)) next

      x_anom <- x_raw[ok] - mod_clim

      if (method == "qm") {
        anom_corr <- qm_adjust(obs_anom, mod_anom, x_anom)
      } else {
        proj_anom_all <- (x_raw - mod_clim)
        if (sum(!is.na(proj_anom_all)) < min_n) next
        anom_corr <- qdm_adjust(obs_anom, mod_anom, proj_anom_all, x_anom)
      }

      if (all(is.na(anom_corr))) next
      out_mat[i, hi[ok]] <- obs_clim + anom_corr
    }
  }

  out_hind <- terra::rast(input1, nlyr = length(hind_dates))
  terra::time(out_hind) <- hind_dates
  names(out_hind) <- as.character(hind_dates)

  msg("setting values + writing ...")
  out_hind <- terra::setValues(out_hind, out_mat)

  write_safe <- function(x, filename, overwrite, wopt) {
    if (is.null(filename)) return(x)

    dir.create(dirname(filename), recursive = TRUE, showWarnings = FALSE)

    tmp <- tempfile(pattern = "terra_write_", tmpdir = dirname(filename), fileext = ".tif")
    terra::writeRaster(x, tmp, overwrite = TRUE, wopt = wopt)

    if (file.exists(filename)) {
      ok <- file.remove(filename)
      if (!ok) stop("Could not remove existing file: ", filename)
    }

    ok <- file.rename(tmp, filename)
    if (!ok) stop("Could not rename temp file to target: ", filename)

    terra::rast(filename)
  }

  if (!combine) {
    out_hind <- write_safe(out_hind, filename, overwrite, wopt)
    return(out_hind)
  }

  combined <- c(out_hind, input1)
  tt <- as_date_time(combined)
  combined <- combined[[order(tt)]]

  if (!is.null(filename)) {
    combined <- write_safe(combined, filename, overwrite, wopt)
  }

  combined
}
