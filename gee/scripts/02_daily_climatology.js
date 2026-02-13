// =============================================================================
// Script 2: Daily Climatology (DC) via Linear Interpolation of MM
// =============================================================================
// Following: Skirving et al. 2020
//
// Method: Each MM value is assigned to the 15th of its respective month.
//         Days between anchors are linearly interpolated.  Wraps Dec → Jan.
//         Produces a 366-band image (dc_001 … dc_366).
//
// PREREQUISITE: Export MM asset from Script 1, OR use inline computation below.
// =============================================================================

// ── Configuration ──────────────────────────────────────────────────────────────
var ROI = ee.Geometry.Rectangle([141.0958, -24.70584, 153.2032, -8.926405]);

// ── Load or compute MM ─────────────────────────────────────────────────────────
// OPTION A – from asset (recommended; uncomment and set your path):
// var mmMultiBand = ee.Image('users/YOUR_USERNAME/MM_Climatology_OISST_1985_2012');

// OPTION B – recompute inline (memory-safe, one month at a time):
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
for (var m = 1; m <= 12; m++) {
  mmBands.push(computeMMForMonth(m));
}
// -- End inline MM computation --

print('MM images computed (12).');

// ── DOY anchor points (15th of each month, non-leap year) ──────────────────────
var anchorDOYs = [15, 46, 74, 105, 135, 166, 196, 227, 258, 288, 319, 349];
// Extended for wrap-around:
var anchorExt  = [-16].concat(anchorDOYs).concat([380]);
var monthIdx   = [11, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0];

// ── Linear interpolation for one DOY ───────────────────────────────────────────
function interpolateDC(doy) {
  var lo = 0;
  for (var k = 0; k < anchorExt.length - 1; k++) {
    if (doy >= anchorExt[k] && doy < anchorExt[k + 1]) { lo = k; break; }
  }
  var frac = (doy - anchorExt[lo]) / (anchorExt[lo + 1] - anchorExt[lo]);
  var mmLo = mmBands[monthIdx[lo]];
  var mmHi = mmBands[monthIdx[lo + 1]];
  return mmLo.add(mmHi.subtract(mmLo).multiply(frac)).rename('dc_sst');
}

// ── Build 366-band Daily Climatology ───────────────────────────────────────────
print('Interpolating 366-day daily climatology …');

var dcBandList = [];
for (var d = 1; d <= 366; d++) {
  var pad = d < 100 ? (d < 10 ? '00' : '0') : '';
  dcBandList.push(interpolateDC(d).rename('dc_' + pad + d));
}
var dcImage = ee.Image.cat(dcBandList).clip(ROI);
print('Daily Climatology image (366 bands):', dcImage);

// ── Visualization ──────────────────────────────────────────────────────────────
var sstVis = {min:20, max:32,
  palette:['0000ff','00ffff','00ff00','ffff00','ff8800','ff0000']};
Map.centerObject(ROI, 5);
Map.addLayer(dcImage.select('dc_015'), sstVis, 'DC Jan 15');
Map.addLayer(dcImage.select('dc_196'), sstVis, 'DC Jul 15', false);

// ── Export ──────────────────────────────────────────────────────────────────────
Export.image.toAsset({
  image: dcImage.toFloat(),
  description: 'Daily_Climatology_OISST_366bands',
  assetId: 'Daily_Climatology_OISST_366bands',
  region: ROI, scale: 27830, maxPixels: 1e10
});

print('Export the 366-band DC asset for use in Scripts 3–5.');
