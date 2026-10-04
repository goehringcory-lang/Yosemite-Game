// Yosemite Valley illustrated map generator (Stardew-style oblique pixel art)
// Data: cached USGS elevation tiles + OpenStreetMap from the game's mapgen cache.
const L = require('./lib.js');
const fs = require('fs');
const OUT = process.env.OUT || require('path').join(__dirname, '..', '..', '..', 'assets', 'map', 'areas');
const S = +(process.env.S || 1);
const W = 468 * S, H = 222 * S;

// ---------------------------------------------------------------- frame
const WEST = +(process.env.WEST || -119.678), EAST = +(process.env.EAST || -119.524);
const LAT0 = 37.7745;                                   // latitude of source row 0
const cosl = Math.cos(37.74 * Math.PI / 180);
const MPP = (EAST - WEST) * 111320 * cosl / W;         // meters per pixel
const DLAT = MPP / 110950;                              // degrees latitude per source row
const NR_REAL = Math.floor((LAT0 - 37.7062) / DLAT);    // source rows with real data
const NR = NR_REAL + 44;                                // plus mirrored rows so the south edge never smears
const HS = +(process.env.HS || 0.028);                  // screen px per meter of elevation (vertical exaggeration)
const EB = 1150;                                        // elevation at "sea level" of the drawing
const T0 = +(process.env.T0 || 28);                     // source row that lands on screen row 0 at EB
const lon2x = lon => (lon - WEST) / (EAST - WEST) * W;
const lat2y = lat => (LAT0 - lat) / DLAT;
const x2lon = x => WEST + (x + 0.5) / W * (EAST - WEST);
const y2lat = y => LAT0 - (y + 0.5) * DLAT;

// ---------------------------------------------------------------- source grids
const E = new Float32Array(W * NR);
for (let y = 0; y < NR; y++) for (let x = 0; x < W; x++) E[y * W + x] = y < NR_REAL ? L.elev(x2lon(x), y2lat(y)) : E[(2 * NR_REAL - 2 - y) * W + x];
const eAt = (x, y) => E[Math.max(0, Math.min(NR - 1, y)) * W + Math.max(0, Math.min(W - 1, x))];
// gentle smoothing to kill DEM noise
const Es = new Float32Array(W * NR);
for (let y = 0; y < NR; y++) for (let x = 0; x < W; x++) {
  let s = 0; for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) s += eAt(x + dx, y + dy) * (dx === 0 && dy === 0 ? 4 : (dx === 0 || dy === 0 ? 2 : 1));
  Es[y * W + x] = s / 16;
}
const slope = new Float32Array(W * NR), lam = new Float32Array(W * NR), nx = new Float32Array(W * NR), ny = new Float32Array(W * NR);
{
  const lx = -0.55, ly = 0.6, lz = 0.58; // light from the south-west, high
  const ll = Math.hypot(lx, ly, lz);
  for (let y = 0; y < NR; y++) for (let x = 0; x < W; x++) {
    const g = (xx, yy) => Es[Math.max(0, Math.min(NR - 1, yy)) * W + Math.max(0, Math.min(W - 1, xx))];
    const dzdx = (g(x + 1, y) - g(x - 1, y)) / (2 * MPP), dzdy = (g(x, y + 1) - g(x, y - 1)) / (2 * MPP);
    slope[y * W + x] = Math.hypot(dzdx, dzdy);
    const n = Math.hypot(dzdx, dzdy, 1);
    nx[y * W + x] = -dzdx / n; ny[y * W + x] = -dzdy / n;
    lam[y * W + x] = Math.max(0, (-dzdx / n * lx + -dzdy / n * ly + 1 / n * lz) / ll);
  }
}

// ---------------------------------------------------------------- OSM rasters
const el = L.loadOsm();
const ID = { none: 0, water: 1, stream: 2, road: 3, road2: 4, path: 5, parking: 6, bridge: 7,
  forest: 1, meadow: 2, wet: 3, sand: 4, rock: 5, scree: 6, scrub: 7, wood: 8 };
const ovl = new Uint8Array(W * NR);   // overlay: water, roads...
const land = new Uint8Array(W * NR);  // OSM land cover
const OV = { water: 1, stream: 2, road: 3, road2: 4, path: 5, parking: 6, bridge: 7 };

function toPx(pt) { return [lon2x(pt.lon), lat2y(pt.lat)]; }
function fillRings(rings, layer, val) {
  const P = rings.map(r => r.map(toPx));
  let miny = 1e9, maxy = -1e9;
  for (const r of P) for (const p of r) { miny = Math.min(miny, p[1]); maxy = Math.max(maxy, p[1]); }
  for (let y = Math.max(0, Math.floor(miny)); y <= Math.min(NR - 1, Math.ceil(maxy)); y++) {
    const yy = y + 0.5, xs = [];
    for (const r of P) for (let i = 0; i < r.length - 1; i++) {
      const a = r[i], b = r[i + 1];
      if ((a[1] <= yy && b[1] > yy) || (b[1] <= yy && a[1] > yy)) xs.push(a[0] + (yy - a[1]) / (b[1] - a[1]) * (b[0] - a[0]));
    }
    xs.sort((p, q) => p - q);
    for (let i = 0; i + 1 < xs.length; i += 2)
      for (let x = Math.max(0, Math.round(xs[i])); x < Math.min(W, Math.round(xs[i + 1])); x++) layer[y * W + x] = val;
  }
}
function line(pts, layer, val, r = 0) {
  const P = pts.map(toPx);
  for (let i = 0; i < P.length - 1; i++) {
    let [x0, y0] = P[i], [x1, y1] = P[i + 1];
    const n = Math.ceil(Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0)) * 2) + 1;
    for (let k = 0; k <= n; k++) {
      const x = Math.floor(x0 + (x1 - x0) * k / n), y = Math.floor(y0 + (y1 - y0) * k / n);
      for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
        if (dx * dx + dy * dy > r * r) continue;
        const xx = x + dx, yy = y + dy;
        if (xx >= 0 && yy >= 0 && xx < W && yy < NR) layer[yy * W + xx] = val;
      }
    }
  }
}
const tag = (e, k) => e.tags && e.tags[k];
function ringsOf(e) {
  if (e.type === 'way' && e.geometry) return [e.geometry];
  if (e.type === 'relation' && e.members) {
    const outer = L.stitch(e.members.filter(m => m.role === 'outer' && m.geometry).map(m => m.geometry));
    const inner = L.stitch(e.members.filter(m => m.role === 'inner' && m.geometry).map(m => m.geometry));
    return outer.concat(inner);
  }
  return [];
}
const landVal = e => {
  const n = tag(e, 'natural'), u = tag(e, 'landuse');
  if (n === 'grassland' || u === 'meadow' || u === 'grass') return ID.meadow;
  if (n === 'wetland') return ID.wet;
  if (n === 'beach') return ID.sand;
  if (n === 'bare_rock') return ID.rock;
  if (n === 'scree') return ID.scree;
  if (n === 'scrub') return ID.scrub;
  if (n === 'wood') return ID.wood;
  return 0;
};
// land cover, woods first then the rest so meadows sit on top
for (const pass of [ID.wood, ID.scrub, ID.rock, ID.scree, ID.sand, ID.wet, ID.meadow])
  for (const e of el) if (landVal(e) === pass) { const r = ringsOf(e); if (r.length) fillRings(r, land, pass); }
// water bodies
for (const e of el) if ((tag(e, 'natural') === 'water' || tag(e, 'water')) && (e.type !== 'node')) { const r = ringsOf(e); if (r.length) fillRings(r, ovl, OV.water); }
// waterways
for (const e of el) if (e.type === 'way' && e.geometry && tag(e, 'waterway')) {
  const w = tag(e, 'waterway');
  if (w === 'river') line(e.geometry, ovl, OV.water, (tag(e, 'name') === 'Merced River' || S >= 2) ? 1 : 0);
  else if (w === 'stream') line(e.geometry, ovl, OV.stream, 0);
}
// roads
const roadClass = h => ({ secondary: 3, secondary_link: 3, primary: 3, tertiary: 3, unclassified: 4, residential: 4, living_street: 4, service: 4, track: 5 }[h] || (['path', 'footway', 'cycleway', 'steps', 'pedestrian', 'bridleway'].includes(h) ? 5 : 0));
for (const cls of [5, 4, 3]) for (const e of el) if (e.type === 'way' && e.geometry && tag(e, 'highway') && roadClass(tag(e, 'highway')) === cls) {
  if (cls === 5 && (tag(e, 'highway') === 'cycleway')) continue;
  line(e.geometry, ovl, cls === 3 ? OV.road : cls === 4 ? OV.road2 : OV.path, 0);
}
for (const e of el) if ((tag(e, 'amenity') === 'parking') && e.type === 'way' && e.geometry) fillRings([e.geometry], ovl, OV.parking);

module.exports = { W, H, NR, NR_REAL, WEST, EAST, LAT0, DLAT, E, Es, slope, lam, nx, ny, ovl, land, OV, ID, lon2x, lat2y, x2lon, y2lat, HS, EB, T0, MPP, S, el, tag, ringsOf, toPx, OUT };
if (require.main === module) require('./render.js');
