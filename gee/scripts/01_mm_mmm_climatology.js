// =============================================================================
// Script 1: Monthly Mean (MM) and Maximum Monthly Mean (MMM) Climatology
// =============================================================================
// Following: Skirving et al. 2020, "CoralTemp and the Coral Reef Watch Coral
// Bleaching Heat Stress Product Suite Version 3.1"
// Remote Sens. 2020, 12, 3856; doi:10.3390/rs12233856
//
// Dataset: NOAA CDR OISST v02r01 (0.25° resolution)
// Period:  1985–2012 (28 years)
// Method:  For each month, compute yearly monthly means, then apply
//          least-squares linear regression against year, and evaluate
//          the regression at X = 1988.2857 to obtain the MM value.
//
// Memory-optimized: processes one month at a time, each with only 28 images.
// =============================================================================

// ── Configuration ──────────────────────────────────────────────────────────────
var CLIM_START = 1985;
var CLIM_END   = 2012;  // inclusive
var TARGET_YEAR = 1988.2857;

// Region of interest: Great Barrier Reef
var ROI = ee.Geometry.Rectangle([141.0958, -24.70584, 153.2032, -8.926405]);

// ── Helper: compute MM for a single month ──────────────────────────────────────
// Loads OISST fresh per call so GEE can garbage-collect between months.
// Produces only 28 images (one per year), runs regression, returns one image.

function computeMMForMonth(month) {
  month = ee.Number(month);
  var years = ee.List.sequence(CLIM_START, CLIM_END);

  // 28 images: mean SST for this calendar month in each year
  var yearlyMeans = ee.ImageCollection(years.map(function(year) {
    year = ee.Number(year);
    var t1 = ee.Date.fromYMD(year, month, 1);
    var t2 = t1.advance(1, 'month');

    var meanSST = ee.ImageCollection('NOAA/CDR/OISST/V2_1')
      .select('sst')
      .filterDate(t1, t2)
      .filterBounds(ROI)
      .mean()
      .multiply(0.01);  // raw units are °C × 100

    return meanSST
      .addBands(ee.Image.constant(1).rename('constant').toFloat())
      .addBands(ee.Image.constant(year).rename('year').toFloat())
      .rename(['sst', 'constant', 'year'])
      .set('year', year);
  }));

  // OLS: sst = intercept + slope × year
  var regression = yearlyMeans
    .select(['constant', 'year', 'sst'])
    .reduce(ee.Reducer.linearRegression({numX: 2, numY: 1}));

  var coef = regression.select('coefficients')
    .arrayProject([0])
    .arrayFlatten([['intercept', 'slope']]);

  // Evaluate at TARGET_YEAR
  return coef.select('intercept')
    .add(coef.select('slope').multiply(TARGET_YEAR))
    .rename('mm_sst')
    .toFloat()
    .set('month', month);
}

// ── Compute MM for each month independently ────────────────────────────────────
print('Computing MM climatology month-by-month (1985–2012) ...');

var mmImages = [];
for (var m = 1; m <= 12; m++) {
  mmImages.push(computeMMForMonth(m).rename('mm_' + (m < 10 ? '0' + m : m)));
}

// 12-band image, clipped to ROI
var mmMultiBand = ee.Image.cat(mmImages).clip(ROI);
print('MM Climatology (12 bands):', mmMultiBand);

// ── Maximum Monthly Mean (MMM) ─────────────────────────────────────────────────
var mmm = mmMultiBand.reduce(ee.Reducer.max()).rename('mmm_sst');
print('MMM Climatology:', mmm);

// ── Spot-check at a sample point ───────────────────────────────────────────────
var samplePt = ee.Geometry.Point([146.0, -16.5]);  // near Cairns
print('MM at sample point:', mmMultiBand.reduceRegion({
  reducer: ee.Reducer.first(), geometry: samplePt, scale: 27830}));
print('MMM at sample point:', mmm.reduceRegion({
  reducer: ee.Reducer.first(), geometry: samplePt, scale: 27830}));

// ── Visualization ──────────────────────────────────────────────────────────────
var sstVis = {
  min: 20, max: 32,
  palette: ['0000ff','00ffff','00ff00','ffff00','ff8800','ff0000']
};
Map.centerObject(ROI, 5);
Map.addLayer(mmMultiBand.select('mm_01'), sstVis, 'MM January');
Map.addLayer(mmMultiBand.select('mm_07'), sstVis, 'MM July', false);
Map.addLayer(mmm, sstVis, 'MMM');

// ── Exports ────────────────────────────────────────────────────────────────────
Export.image.toAsset({
  image: mmMultiBand.toFloat(),
  description: 'MM_Climatology_OISST_1985_2012',
  assetId: 'MM_Climatology_OISST_1985_2012',
  region: ROI, scale: 27830, maxPixels: 1e10
});
Export.image.toAsset({
  image: mmm.toFloat(),
  description: 'MMM_Climatology_OISST_1985_2012',
  assetId: 'MMM_Climatology_OISST_1985_2012',
  region: ROI, scale: 27830, maxPixels: 1e10
});
Export.image.toDrive({
  image: mmMultiBand.toFloat(),
  description: 'MM_Climatology_Drive',
  fileNamePrefix: 'MM_Climatology_OISST_1985_2012',
  region: ROI, scale: 27830, maxPixels: 1e10, fileFormat: 'GeoTIFF'
});
Export.image.toDrive({
  image: mmm.toFloat(),
  description: 'MMM_Climatology_Drive',
  fileNamePrefix: 'MMM_Climatology_OISST_1985_2012',
  region: ROI, scale: 27830, maxPixels: 1e10, fileFormat: 'GeoTIFF'
});

print('──────────────────────────────────────────────');
print('Run Export tasks in the Tasks tab.');
print('Assets are needed by subsequent scripts.');
print('──────────────────────────────────────────────');
