# NOAA_CRW_data

subset of NOAA CRW data from rerdapp

## Usage

``` r
NOAA_CRW_data
```

## Format

dataframe

- CRW_SST:

  Sea Surface Temperature)

- CRW_SSTANOMALY:

  Sea Surface Temperature anomaly)

- CRW_DHW:

  Degree Heating Weeks

## Source

library(rerddap)

NOAA_CRW \<- griddap( datasetx = 'NOAA_DHW', time = c("2015-06-01",
"2017-06-01"), latitude = c(-14.655, -14.655), longitude = c(145.405,
145.405), fmt = "nc" )

NOAA_CRW_data \<- NOAA_CRW\$data

## Examples

``` r
data(NOAA_CRW_data)
summary(NOAA_CRW_data)
```
