// =============================================================================
// Script 4: Coral Bleaching HotSpot (HS) Product
// =============================================================================
// HS_i = max(SST_i − MMM, 0)
// =============================================================================

// ── Configuration ──────────────────────────────────────────────────────────────
var ANALYSIS_START = '2024-01-01';
var ANALYSIS_END   = '2024-12-31';
var ROI = ee.Geometry.Rectangle([141.0958, -24.70584, 153.2032, -8.926405]);

// ── Compute MMM (memory-safe) ──────────────────────────────────────────────────
// Use asset instead if available:
// var mmm = ee.Image('users/YOUR_USERNAME/MMM_Climatology_OISST_1985_2012');

var CLIM_START = 1985, CLIM_END = 2012, TARGET_YEAR = 1988.2857;

function computeMMForMonth(month) {
  month = ee.Number(month);
  var years = ee.List.sequence(CLIM_START, CLIM_END);
  var yearlyMeans = ee.ImageCollection(years.map(function(year) {
    year = ee.Number(year);
    var t1 = ee.Date.fromYMD(year, month, 1);
    var t2 = t1.advance(1, 'month');
    var meanSST = ee.ImageCollection('NOAA/CDR/OISST/V2_1')
      .select('sst').filterDate(t1, t2).filterBounds(ROI)
      .mean().multiply(0.01);
    return meanSST
      .addBands(ee.Image.constant(1).rename('constant').toFloat())
      .addBands(ee.Image.constant(year).rename('year').toFloat())
      .rename(['sst','constant','year']).set('year', year);
  }));
  var reg = yearlyMeans.select(['constant','year','sst'])
    .reduce(ee.Reducer.linearRegression({numX:2, numY:1}));
  var coef = reg.select('coefficients').arrayProject([0])
    .arrayFlatten([['intercept','slope']]);
  return coef.select('intercept')
    .add(coef.select('slope').multiply(TARGET_YEAR))
    .rename('mm_sst').toFloat();
}

var mmImages = [];
for (var m = 1; m <= 12; m++) { mmImages.push(computeMMForMonth(m)); }
var mmm = ee.Image.cat(mmImages).reduce(ee.Reducer.max()).rename('mmm_sst').clip(ROI);
print('MMM computed.');

// ── Load analysis SST ──────────────────────────────────────────────────────────
var oisstAnalysis = ee.ImageCollection('NOAA/CDR/OISST/V2_1')
  .select('sst')
  .filterDate(ANALYSIS_START, ANALYSIS_END)
  .filterBounds(ROI)
  .map(function(img) {
    return img.multiply(0.01).copyProperties(img, img.propertyNames());
  });
print('Analysis SST images:', oisstAnalysis.size());

// ── Compute HotSpot ────────────────────────────────────────────────────────────
var hotspotCollection = oisstAnalysis.map(function(img) {
  var hs = img.subtract(mmm).max(0).rename('hotspot');
  return hs
    .addBands(img.rename('sst'))
    .clip(ROI)
    .set('system:time_start', img.get('system:time_start'))
    .set('date', ee.Date(img.get('system:time_start')).format('YYYY-MM-dd'));
});
print('HotSpot collection:', hotspotCollection.size());

// ── Visualization ──────────────────────────────────────────────────────────────
var hsVis = {min:0, max:4,
  palette:['ffffff','ffff00','ffaa00','ff5500','ff0000','cc0000','880000']};
Map.centerObject(ROI, 5);
Map.addLayer(mmm, {min:20, max:32,
  palette:['0000ff','00ffff','00ff00','ffff00','ff8800','ff0000']}, 'MMM');
Map.addLayer(hotspotCollection.select('hotspot').max(), hsVis,
  'Max HotSpot 2024');

// ── Chart ──────────────────────────────────────────────────────────────────────
var pt = ee.Geometry.Point([146.0, -16.5]);
print(ui.Chart.image.series({
  imageCollection: hotspotCollection.select('hotspot'),
  region: pt, reducer: ee.Reducer.mean(), scale: 27830
}).setOptions({
  title:'Daily Coral Bleaching HotSpot',
  vAxis:{title:'HS (°C above MMM)', minValue:0},
  lineWidth:1, pointSize:0, series:{0:{color:'#ff4400'}}
}));

// ── Export ──────────────────────────────────────────────────────────────────────
Export.image.toDrive({
  image: hotspotCollection.select('hotspot').max().toFloat(),
  description: 'Max_HotSpot_2024',
  region: ROI, scale: 27830, maxPixels: 1e10
});
