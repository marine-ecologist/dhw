# Create sf polygon from bbox

Function to convert a bounding box to a polygon with correct CRS.

## Usage

``` r
st_polygon_from_bbox(bbox, output_crs)
```

## Arguments

- output_crs:

  desired output CRS (integer or string)

- boundaries:

  in list: c(xmin, ymin, xmax, ymax)

## Value

sf polygon
