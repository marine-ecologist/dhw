// =============================================================================
// Script 5: Degree Heating Weeks (DHW) Product
// =============================================================================
// DHW_i = Σ(HS_n / 7)  for n = i−83 to i,  where HS_n ≥ 1 °C
//
// 84-day (12-week) rolling accumulation of daily HotSpot values ≥ 1 °C,
// converted from degree-days to degree-weeks by dividing by 7.
//
// Bleaching thresholds:
//   DHW ≥  4 °C-weeks → significant bleaching likely
//   DHW ≥  8 °C-weeks → severe bleaching & mortality likely
// =============================================================================

// ── Configuration ──────────────────────────────────────────────────────────────
var DHW_START = '2024-01-01';
var DHW_END   = '2024-12-31';
var ROI = ee.Geometry.Rectangle([141.0958, -24.70584, 153.2032, -8.926405]);

var DHW_WINDOW   = 84;   // days
var HS_THRESHOLD = 1;    // °C

// Data must begin 84 days before DHW_START
var dataStart = ee.Date(DHW_START).advance(-DHW_WINDOW, 'day');
print('Data start (incl. 84-day buffer):', dataStart.format('YYYY-MM-dd'));

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

// ── Load SST for full period (analysis + 84-day buffer) ────────────────────────
var dataEnd = ee.Date(DHW_END).advance(1, 'day');
var oisstFull = ee.ImageCollection('NOAA/CDR/OISST/V2_1')
  .select('sst')
  .filterDate(dataStart, dataEnd)
  .filterBounds(ROI)
  .map(function(img) {
    return img.multiply(0.01).copyProperties(img, img.propertyNames());
  });
print('SST images loaded (incl. buffer):', oisstFull.size());

// ── Compute daily HotSpot ──────────────────────────────────────────────────────
var hsCollection = oisstFull.map(function(img) {
  return img.subtract(mmm).max(0).rename('hotspot').clip(ROI)
    .set('system:time_start', img.get('system:time_start'));
});

// ── DHW function for a single target date ──────────────────────────────────────
function computeDHW(targetDate) {
  targetDate = ee.Date(targetDate);
  var windowStart = targetDate.advance(-(DHW_WINDOW - 1), 'day');

  // 84-day window of HS values
  var windowHS = hsCollection.filterDate(windowStart, targetDate.advance(1, 'day'));

  // Zero out HS < 1 °C (only HS ≥ 1 contributes)
  var thresholded = windowHS.map(function(img) {
    return img.updateMask(img.gte(HS_THRESHOLD)).unmask(0);
  });

  // Sum and convert degree-days → degree-weeks
  return thresholded.sum().divide(7).rename('dhw').clip(ROI)
    .set('system:time_start', targetDate.millis())
    .set('date', targetDate.format('YYYY-MM-dd'));
}

// ── Compute DHW for every day in the analysis period ───────────────────────────
// NOTE: This creates ~365 derived images; each triggers an 84-image sum.
// For very long periods or global runs, process in monthly batches or
// export HS first and compute DHW offline.

var dhwStartDate = ee.Date(DHW_START);
var nDays = ee.Date(DHW_END).difference(dhwStartDate, 'day').add(1).round();
print('DHW output days:', nDays);

var dhwDates = ee.List.sequence(0, nDays.subtract(1)).map(function(offset) {
  return dhwStartDate.advance(offset, 'day');
});

var dhwCollection = ee.ImageCollection(dhwDates.map(function(date) {
  return computeDHW(ee.Date(date));
}));
print('DHW collection:', dhwCollection.size());

// ── Visualization ──────────────────────────────────────────────────────────────
var dhwVis = {min:0, max:16,
  palette:['ffffff','ffffcc','ffff00','ffcc00','ff8800',
           'ff4400','ff0000','cc0000','880000']};
Map.centerObject(ROI, 5);

var maxDHW = dhwCollection.select('dhw').max();
Map.addLayer(maxDHW, dhwVis, 'Max DHW 2024');
Map.addLayer(maxDHW.gte(4).selfMask(), {palette:['orange']},
  'DHW ≥ 4 (Warning)', false);
Map.addLayer(maxDHW.gte(8).selfMask(), {palette:['red']},
  'DHW ≥ 8 (Alert Lvl 2)', false);

// ── Chart at a point ───────────────────────────────────────────────────────────
var pt = ee.Geometry.Point([146.0, -16.5]);
print(ui.Chart.image.series({
  imageCollection: dhwCollection.select('dhw'),
  region: pt, reducer: ee.Reducer.mean(), scale: 27830
}).setOptions({
  title:'Degree Heating Weeks (DHW)',
  vAxis:{title:'DHW (°C-weeks)', minValue:0},
  lineWidth:2, pointSize:0, series:{0:{color:'#cc0000'}}
}));

// ── Exports ────────────────────────────────────────────────────────────────────
Export.image.toDrive({
  image: maxDHW.toFloat(),
  description: 'Max_DHW_2024',
  fileNamePrefix: 'Max_DHW_2024',
  region: ROI, scale: 27830, maxPixels: 1e10
});

// Optional: export a specific date
var singleDate = '2024-03-15';
Export.image.toDrive({
  image: computeDHW(ee.Date(singleDate)).toFloat(),
  description: 'DHW_' + singleDate.replace(/-/g,''),
  fileNamePrefix: 'DHW_' + singleDate.replace(/-/g,''),
  region: ROI, scale: 27830, maxPixels: 1e10
});

print('──────────────────────────────────────────────────');
print('DHW = Σ(HS/7) over 84-day window, HS ≥ 1 °C only');
print('DHW ≥ 4 → Bleaching Warning');
print('DHW ≥ 8 → Bleaching Alert Level 2');
print('──────────────────────────────────────────────────');
