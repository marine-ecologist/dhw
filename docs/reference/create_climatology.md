# Create climatology

Function to calculate climatology from datasets

See vignette for further details outputs:

- output\$sst

- output\$anomalies

- output\$mm

- output\$mmm

- output\$dailyclimatology

- output\$hs

- output\$dhw

note - calculating BAA is slow

## Usage

``` r
create_climatology(
  sst_file,
  anomaly = 1,
  window = 84,
  quiet = FALSE,
  return = FALSE,
  baa = FALSE,
  save_output = NULL,
  climatology = NULL,
  ...
)
```

## Arguments

- sst_file:

  input

- window:

  number of days for the DHW sum (12 weeks = 84 days default)

- quiet:

  verbose - update with messages?

- return:

  return output TRUE/FALSE

- baa:

  return baa? TRUE/FALSE (speeds up processing)

- save_output:

  save output? "folder/filename" format where "folder/filename_sst.tif",
  "folder/filename_dhw.tif" etc

- climatology:

  replace mmm with external climatology? link to .nc, explicit for CRW
  (i.e. "GBR_ct5km_climatology_v3.1.nc")

## Value

output list (see above for details)

## Examples

``` r
if (FALSE) { # \dontrun{
output <- create_climatology("crw.nc")
} # }
```
