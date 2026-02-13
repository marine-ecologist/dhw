// =============================================================================
// Script 3: SST Anomaly Product
// =============================================================================
// SST_Anomaly_i = SST_i − DC_d
// where DC_d is the daily climatology for day-of-year d.
// =============================================================================

// ── Configuration ──────────────────────────────────────────────────────────────
var ANALYSIS_START = '2024-01-01';
var ANALYSIS_END   = '2024-12-31';
var ROI = ee.Geometry.Rectangle([141.0958, -24.70584, 153.2032, -8.926405]);

// ── Compute MM (memory-safe, one month at a time) ──────────────────────────────
// Use asset instead if available:
// var mmMultiBand = ee.Image('users/YOUR_USERNAME/MM_Climatology_OISST_1985_2012');

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

var mmBands = [];
for (var m = 1; m <= 12; m++) { mmBands.push(computeMMForMonth(m)); }

// ── Build Daily Climatology (366 bands) ────────────────────────────────────────
var anchorDOYs = [15,46,74,105,135,166,196,227,258,288,319,349];
var anchorExt  = [-16].concat(anchorDOYs).concat([380]);
var monthIdx   = [11,0,1,2,3,4,5,6,7,8,9,10,11,0];

function interpolateDC(doy) {
  var lo = 0;
  for (var k = 0; k < anchorExt.length - 1; k++) {
    if (doy >= anchorExt[k] && doy < anchorExt[k+1]) { lo = k; break; }
  }
  var frac = (doy - anchorExt[lo]) / (anchorExt[lo+1] - anchorExt[lo]);
  var mmLo = mmBands[monthIdx[lo]];
  var mmHi = mmBands[monthIdx[lo+1]];
  return mmLo.add(mmHi.subtract(mmLo).multiply(frac)).rename('dc_sst');
}

// Stack all 366 DC bands into one image for server-side DOY indexing
var dcBandList = [];
for (var d = 1; d <= 366; d++) { dcBandList.push(interpolateDC(d)); }
var dcAllBands = ee.Image.cat(dcBandList).clip(ROI);  // band 0 = DOY 1, band 365 = DOY 366

// ── Load analysis-period SST ───────────────────────────────────────────────────
var oisstAnalysis = ee.ImageCollection('NOAA/CDR/OISST/V2_1')
  .select('sst')
  .filterDate(ANALYSIS_START, ANALYSIS_END)
  .filterBounds(ROI)
  .map(function(img) {
    return img.multiply(0.01).copyProperties(img, img.propertyNames());
  });
print('Analysis SST images:', oisstAnalysis.size());

// ── Compute SST Anomaly ────────────────────────────────────────────────────────
// Use array indexing to pick the correct DC band by DOY server-side.

var dcArray = dcAllBands.toArray();  // 1-D array image, length 366

var sstAnomalyCollection = oisstAnalysis.map(function(img) {
  var date = ee.Date(img.get('system:time_start'));
  var doy  = date.getRelative('day', 'year').add(1).min(366);  // 1-based
  var idx  = doy.subtract(1);

  var dcForDay = dcArray
    .arraySlice(0, idx, idx.add(1))
    .arrayProject([0])
    .arrayFlatten([['dc_sst']]);

  var anomaly = img.subtract(dcForDay).rename('sst_anomaly');

  return anomaly
    .addBands(img.rename('sst'))
    .addBands(dcForDay)
    .clip(ROI)
    .set('system:time_start', img.get('system:time_start'))
    .set('date', date.format('YYYY-MM-dd'));
});

print('SST Anomaly collection:', sstAnomalyCollection.size());

// ── Visualization ──────────────────────────────────────────────────────────────
var anomVis = {min:-3, max:3,
  palette:['0000ff','4444ff','8888ff','ffffff','ff8888','ff4444','ff0000']};
Map.centerObject(ROI, 5);
Map.addLayer(sstAnomalyCollection.select('sst_anomaly').mean(),
  anomVis, 'Mean SST Anomaly');

// ── Chart at a point ───────────────────────────────────────────────────────────
var pt = ee.Geometry.Point([146.0, -16.5]);
print(ui.Chart.image.series({
  imageCollection: sstAnomalyCollection.select('sst_anomaly'),
  region: pt, reducer: ee.Reducer.mean(), scale: 27830
}).setOptions({
  title: 'Daily SST Anomaly', vAxis:{title:'°C'}, lineWidth:1, pointSize:0,
  series:{0:{color:'red'}}
}));

// ── Export ──────────────────────────────────────────────────────────────────────
Export.image.toDrive({
  image: sstAnomalyCollection.select('sst_anomaly').mean().toFloat(),
  description: 'Mean_SST_Anomaly_2024',
  region: ROI, scale: 27830, maxPixels: 1e10
});
