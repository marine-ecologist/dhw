# dhw 1.1.0

* fixed `downloadCoralTemp()` and `download_OISST()` to handle date vectors
* fixed `calculate_baa()` to handle NaN in dhw input
* fixed `calculate_dhw()` so that if  `anomaly >= 1`, only daily hotspot values greater than or equal to that threshold are included, and if `anomaly < 1`, *all* non-NA hotspot values are
included without thresholding
* updated `process_CoralTemp()` to use `futures::future_lapply()` instead of `parallel::mclapply()` to make OS compatible and fix new mc issues in MacOS (to do: `process_OISST()`)


* added `isComplete()` function that checks for completeness of `download_OISST()` and `download_CoralTemp()` timeseries 
* added `plot_sst_timeseries()` function for visualising SST time series
* added `plot_max_dhw()` function for visualising annual max DHW over a timeseries 
* added `plot_annual_dhw` function for visualising daily DHW over an annual timeseries
* added `visualising_outputs` vignette to display plot/mapping options for outputs 


# dhw 1.0.0

* Initial release
