library(terra)

quantile_map <- function(input1, input2, n_quantiles = 100,
                         method = "qm", combine_with_obs = TRUE,
                         return_format = "raster",
                         overlap_period = NULL) {

  method <- tolower(method)
  if (!method %in% c("qm", "qdm")) stop("method must be either 'qm' or 'qdm'")

  return_format <- tolower(return_format)
  if (!return_format %in% c("raster", "dataframe", "df")) {
    stop("return_format must be 'raster', 'dataframe', or 'df'")
  }

  cat("Starting quantile mapping hindcast using", toupper(method), "method...\n")

  if (!terra::compareGeom(input1, input2, stopOnError = FALSE)) {
    cat("Grids don't match - resampling input2 to match input1...\n")
    cat("  Input1: ", terra::nrow(input1), "rows x", terra::ncol(input1), "cols =", terra::ncell(input1), "cells\n")
    cat("  Input2: ", terra::nrow(input2), "rows x", terra::ncol(input2), "cols =", terra::ncell(input2), "cells\n")
    cat("  Input1 extent:", as.vector(terra::ext(input1)), "\n")
    cat("  Input2 extent:", as.vector(terra::ext(input2)), "\n")

    input2 <- terra::resample(input2, input1, method = "bilinear")

    cat("  After resampling, input2: ", terra::nrow(input2), "rows x", terra::ncol(input2), "cols\n")
    cat("Spatial alignment complete.\n\n")
  } else {
    cat("Grids already match.\n\n")
  }

  time1 <- terra::time(input1)
  time2 <- terra::time(input2)
  time1_dates <- as.Date(time1)
  time2_dates <- as.Date(time2)

  cat("Input1 time range:", as.character(min(time1_dates)), "to",
      as.character(max(time1_dates)), "(", length(time1_dates), "layers )\n")
  cat("Input2 time range:", as.character(min(time2_dates)), "to",
      as.character(max(time2_dates)), "(", length(time2_dates), "layers )\n")

  overlap_start <- max(min(time1_dates), min(time2_dates))
  overlap_end <- min(max(time1_dates), max(time2_dates))

  if (!is.null(overlap_period)) {
    overlap_start <- max(overlap_start, as.Date(overlap_period[1]))
    overlap_end <- min(overlap_end, as.Date(overlap_period[2]))
  }

  cat("Overlap period:", as.character(overlap_start), "to",
      as.character(overlap_end), "\n")

  idx1_overlap <- which(time1_dates >= overlap_start & time1_dates <= overlap_end)
  idx2_overlap <- which(time2_dates >= overlap_start & time2_dates <= overlap_end)

  cat("Input1 overlap indices: ", length(idx1_overlap), "layers\n")
  cat("Input2 overlap indices: ", length(idx2_overlap), "layers\n")

  dates1_overlap <- time1_dates[idx1_overlap]
  dates2_overlap <- time2_dates[idx2_overlap]

  common_dates_numeric <- base::intersect(as.numeric(dates1_overlap), as.numeric(dates2_overlap))
  common_dates <- as.Date(common_dates_numeric, origin = "1970-01-01")

  cat("Number of matching dates in overlap:", length(common_dates), "\n")
  if (length(common_dates) == 0) stop("No matching dates found in overlap period!")

  idx1_matched <- match(common_dates, time1_dates)
  idx2_matched <- match(common_dates, time2_dates)

  valid_matches <- !is.na(idx1_matched) & !is.na(idx2_matched)
  idx1_matched <- idx1_matched[valid_matches]
  idx2_matched <- idx2_matched[valid_matches]

  cat("Valid matched dates:", length(idx1_matched), "\n")

  hindcast_dates <- time2_dates[time2_dates < min(time1_dates)]
  idx2_hindcast <- which(time2_dates %in% hindcast_dates)

  cat("Number of hindcast dates:", length(idx2_hindcast), "\n")
  cat("Hindcast period:", as.character(min(hindcast_dates)), "to",
      as.character(max(hindcast_dates)), "\n\n")

  cat("Identifying valid cells...\n")

  all_coords <- cbind(
    x = terra::xFromCell(input1, 1:terra::ncell(input1)),
    y = terra::yFromCell(input1, 1:terra::ncell(input1))
  )

  first_layer_input1 <- terra::values(input1[[1]])
  first_layer_input2 <- terra::values(input2[[1]])

  valid_cells_input1 <- which(!is.na(first_layer_input1))
  valid_cells_input2 <- which(!is.na(first_layer_input2))

  cat("Valid cells in input1:", length(valid_cells_input1), "\n")
  cat("Valid cells in input2 (after resampling):", length(valid_cells_input2), "\n")
  cat("Cells lost during resampling:", length(valid_cells_input1) - length(valid_cells_input2), "\n")

  valid_cells <- base::intersect(valid_cells_input1, valid_cells_input2)
  valid_coords <- all_coords[valid_cells, , drop = FALSE]

  n_valid <- nrow(valid_coords)

  cat("Total cells:", terra::ncell(input1), "\n")
  cat("Valid cells to process (valid in both):", n_valid, "\n\n")

  if (n_valid < terra::ncell(input1) * 0.5) {
    cat("NOTE: Only", round(100 * n_valid / terra::ncell(input1), 1),
        "% of cells are valid.\n")
    cat("Reasons:\n")
    cat("  - Land/ocean mask: ~", round(100 * length(valid_cells_input1) / terra::ncell(input1), 1),
        "% of grid is ocean\n")
    cat("  - Spatial coverage difference: ", length(valid_cells_input1) - n_valid,
        " cells lost due to different extents\n\n")
  } else {
    cat("\n")
  }

  cat("Initializing output matrix...\n")
  n_hindcast <- length(idx2_hindcast)
  output_matrix <- matrix(NA, nrow = terra::ncell(input1), ncol = n_hindcast)

  cat("Output matrix size:", nrow(output_matrix), "cells x", ncol(output_matrix), "times\n\n")

  probs <- seq(0, 1, length.out = n_quantiles)

  cat("Performing quantile mapping...\n")

  for (i in 1:n_valid) {
    if (i %% 50 == 0 || i == 1) {
      cat("  Processing cell", i, "of", n_valid,
          sprintf("(%.1f%%)\n", 100 * i / n_valid))
    }

    point_coords <- valid_coords[i, , drop = FALSE]

    ts1 <- terra::extract(input1, point_coords)
    ts2 <- terra::extract(input2, point_coords)

    ts1 <- as.numeric(ts1[1, -1])
    ts2 <- as.numeric(ts2[1, -1])

    obs_vals <- ts1[idx1_matched]
    model_vals <- ts2[idx2_matched]
    hindcast_vals <- ts2[idx2_hindcast]

    if (sum(!is.na(obs_vals)) < 10 || sum(!is.na(model_vals)) < 10) next

    obs_quantiles <- stats::quantile(obs_vals, probs = probs, na.rm = TRUE)
    model_quantiles <- stats::quantile(model_vals, probs = probs, na.rm = TRUE)

    if (method == "qdm") model_mean <- mean(model_vals, na.rm = TRUE)

    corrected_hindcast <- rep(NA_real_, length(hindcast_vals))

    # --- CHANGED INTERNAL LOOP (vectorised, continuous quantile position) ---
    ok <- !is.na(hindcast_vals)
    if (any(ok)) {
      q_pos <- stats::approx(
        x = as.numeric(model_quantiles),
        y = probs,
        xout = hindcast_vals[ok],
        rule = 2,
        ties = "ordered"
      )$y

      corrected_base <- stats::approx(
        x = probs,
        y = as.numeric(obs_quantiles),
        xout = q_pos,
        rule = 2,
        ties = "ordered"
      )$y

      if (method == "qm") {
        corrected_hindcast[ok] <- corrected_base
      } else {
        model_delta <- hindcast_vals[ok] - model_mean
        corrected_hindcast[ok] <- corrected_base + model_delta
      }
    }
    # --- END CHANGE ---

    cell_idx <- terra::cellFromXY(input1, point_coords)
    output_matrix[cell_idx, ] <- corrected_hindcast
  }

  cat("\nQuantile mapping complete!\n")
  cat("Converting matrix to raster...\n")

  template_layer <- input1[[1]]
  output <- terra::rast(template_layer)

  output_list <- list()

  for (t in 1:n_hindcast) {
    if (t %% 1000 == 0) cat("  Creating layer", t, "of", n_hindcast, "\n")
    layer <- terra::rast(template_layer)
    terra::values(layer) <- output_matrix[, t]
    output_list[[t]] <- layer
  }

  cat("Combining layers...\n")
  output <- terra::rast(output_list)

  terra::time(output) <- hindcast_dates
  names(output) <- as.character(hindcast_dates)

  cat("\nQuantile mapping complete!\n")

  if (combine_with_obs) {
    cat("Combining hindcast with original observations...\n")
    combined <- c(output, input1)
    time_combined <- terra::time(combined)
    time_order <- order(time_combined)
    output <- combined[[time_order]]

    cat("Combined time series created!\n")
    cat("Total layers:", terra::nlyr(output), "\n")
    cat("Time range:", as.character(min(terra::time(output))), "to",
        as.character(max(terra::time(output))), "\n")
  } else {
    cat("Returning hindcast period only.\n")
    cat("Hindcast layers:", terra::nlyr(output), "\n")
    cat("Time range:", as.character(min(terra::time(output))), "to",
        as.character(max(terra::time(output))), "\n")
  }

  if (return_format %in% c("dataframe", "df")) {
    cat("\nConverting to data frame...\n")

    x_coords <- terra::xFromCell(output, 1:terra::ncell(output))
    y_coords <- terra::yFromCell(output, 1:terra::ncell(output))
    time_vals <- terra::time(output)

    df_list <- list()

    for (i in 1:terra::nlyr(output)) {
      if (i %% 1000 == 0) cat("  Processing layer", i, "of", terra::nlyr(output), "\n")

      vals <- terra::values(output[[i]])[, 1]
      non_na <- !is.na(vals)

      if (sum(non_na) > 0) {
        df_list[[i]] <- data.frame(
          x = x_coords[non_na],
          y = y_coords[non_na],
          time = time_vals[i],
          value = vals[non_na]
        )
      }
    }

    cat("Combining data frames...\n")
    output_df <- do.call(rbind, df_list)

    cat("Data frame created with", nrow(output_df), "rows\n")
    cat("Columns:", paste(names(output_df), collapse = ", "), "\n")

    return(output_df)
  }

  output
}

