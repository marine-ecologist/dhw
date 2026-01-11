# Changelog

## dhw 1.3.0

## dhw 1.2.1

## dhw 1.2.0

- added
  [`hindcast_qm()`](https://marine-ecologist.github.io/dhw/reference/hindcast_qm.md),
  anomaly-based quantile mapping to reconstruct a hindcast SST time
  series by bias-correcting a long model dataset (e.g. ERA5) to a
  shorter observed reference dataset (e.g. OISST), enabling extension of
  historical SST records.

## dhw 1.1.0

- fixed `downloadCoralTemp()` and
  [`download_OISST()`](https://marine-ecologist.github.io/dhw/reference/download_OISST.md)
  to handle date vectors

- fixed
  [`calculate_baa()`](https://marine-ecologist.github.io/dhw/reference/calculate_baa.md)
  to handle NaN in dhw input

- fixed
  [`calculate_dhw()`](https://marine-ecologist.github.io/dhw/reference/calculate_dhw.md)
  so that if `anomaly >= 1`, only daily hotspot values greater than or
  equal to that threshold are included, and if `anomaly < 1`, *all*
  non-NA hotspot values are included without thresholding

- updated
  [`process_CoralTemp()`](https://marine-ecologist.github.io/dhw/reference/process_CoralTemp.md)
  to use `futures::future_lapply()` instead of
  [`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html) to
  make OS compatible and fix new mc issues in MacOS (to do:
  [`process_OISST()`](https://marine-ecologist.github.io/dhw/reference/process_OISST.md))

- added
  [`isComplete()`](https://marine-ecologist.github.io/dhw/reference/isComplete.md)
  function that checks for completeness of
  [`download_OISST()`](https://marine-ecologist.github.io/dhw/reference/download_OISST.md)
  and
  [`download_CoralTemp()`](https://marine-ecologist.github.io/dhw/reference/download_CoralTemp.md)
  timeseries

- added
  [`plot_sst_timeseries()`](https://marine-ecologist.github.io/dhw/reference/plot_sst_timeseries.md)
  function for visualising SST time series

- added
  [`plot_max_dhw()`](https://marine-ecologist.github.io/dhw/reference/plot_annual_dhw_max.md)
  function for visualising annual max DHW over a timeseries

- added `plot_annual_dhw` function for visualising daily DHW over an
  annual timeseries

- added `visualising_outputs` vignette to display plot/mapping options
  for outputs

## dhw 1.0.0

- Initial release
