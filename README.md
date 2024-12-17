# dhw

#### dhw: an R package for calculating various SST metrics (Maximum Monthly Mean Climatology, SST Anomalies, Coral Bleaching HotSpots, Degree Heating Weeks)

  <p align="right" style="text-align: right" width="25%">
  <img src="https://github.com/user-attachments/assets/f173b60d-7822-46c7-b7dd-1358286eb6e9" 
     width="200" />
</p> 

The <b>dhw</b> package for calculates SST metrics from raw SST datasets by following the methods of the Coral Reef Watch Coral Bleaching Heat Stress Product Suite Version 3.1 (see Skirving et al 2020 for methods).

The Degree Heating Weeks product from [National Oceanic and Atmospheric Administration’s (NOAA) Coral Reef Watch (CRW) program](https://coralreefwatch.noaa.gov) are calculated from the [CoralTemp SST product](https://coralreefwatch.noaa.gov/product/5km/index_5km_sst.php). Due to changes in the datasets used by the CRW over the years (see Skirving et al 2020 for details), the degree heating weeks and other metrics are calculated against a specific climatology (1985–1990 and 1993) to allow for internally consistent anomaly products. 

The `dhw` package provides a series of functions to recreate the algorithms for the CRW metrics (Maximum Monthly Mean Climatology, SST Anomalies, Coral Bleaching HotSpots, Degree Heating Weeks) using any SST product (e.g. [OISST](https://www.ncei.noaa.gov/products/optimum-interpolation-sst)) that spans the baseline period of 1985 to 1993.


![ct5km_baa5-max-7d_v3 1_tropics_current](https://github.com/user-attachments/assets/37e9f9e0-b14b-4a6b-978c-5891434c07d9)


# Installation 

the current development version of `dhw` can be installed from github:

``` r
#install.packages("remotes")
remotes::install_github("symbiobase/symbioR", force=TRUE)

```


# References 
Skirving <i>et al</i> (2020) Remote Sensing 12(3856) doi:10.3390/rs12233856 


