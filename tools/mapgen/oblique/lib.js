// Shared helpers: DEM sampling, OSM parsing, raster drawing, PNG output.
const fs = require('fs'), cp = require('child_process');
const CACHE = require('path').join(__dirname, '..', 'cache');

// ---------------------------------------------------------------- DEM
const Z = 13, N = 256 << Z;
const tiles = new Map();
function tile(tx, ty) {
  const k = tx + '_' + ty;
  if (tiles.has(k)) return tiles.get(k);
  const f = `${CACHE}/dem/${Z}_${tx}_${ty}.png`;
  const buf = cp.execFileSync('magick', [f, '-depth', '8', 'rgb:-'], { maxBuffer: 1 << 26 });
  const a = new Float32Array(256 * 256);
  for (let i = 0; i < 256 * 256; i++) a[i] = buf[i * 3] * 256 + buf[i * 3 + 1] + buf[i * 3 + 2] / 256 - 32768;
  tiles.set(k, a);
  return a;
}
function px(x, y) { return tile(Math.floor(x / 256), Math.floor(y / 256))[((y % 256 + 256) % 256) * 256 + ((x % 256 + 256) % 256)]; }
function elev(lon, lat) {
  const gx = (lon + 180) / 360 * N - 0.5;
  const gy = (1 - Math.asinh(Math.tan(lat * Math.PI / 180)) / Math.PI) / 2 * N - 0.5;
  const x0 = Math.floor(gx), y0 = Math.floor(gy), fx = gx - x0, fy = gy - y0;
  const a = px(x0, y0), b = px(x0 + 1, y0), c = px(x0, y0 + 1), d = px(x0 + 1, y0 + 1);
  return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy;
}

// ---------------------------------------------------------------- OSM
function loadOsm() {
  const j = JSON.parse(fs.readFileSync(`${CACHE}/osm/yosemite_valley.json`));
  return j.elements;
}
const key = p => p.lat.toFixed(7) + ',' + p.lon.toFixed(7);
// Joins open ways into closed rings.
function stitch(ways) {
  const rings = [];
  const pool = ways.filter(w => w && w.length > 1).map(w => w.slice());
  while (pool.length) {
    let ring = pool.pop();
    let guard = 0;
    while (key(ring[0]) !== key(ring[ring.length - 1]) && guard++ < 500) {
      const end = key(ring[ring.length - 1]);
      let i = pool.findIndex(w => key(w[0]) === end);
      if (i >= 0) { ring = ring.concat(pool.splice(i, 1)[0].slice(1)); continue; }
      i = pool.findIndex(w => key(w[w.length - 1]) === end);
      if (i >= 0) { ring = ring.concat(pool.splice(i, 1)[0].reverse().slice(1)); continue; }
      break;
    }
    rings.push(ring);
  }
  return rings;
}

// ---------------------------------------------------------------- PNG out
function savePng(file, w, h, rgba) {
  cp.execFileSync('magick', ['-size', `${w}x${h}`, '-depth', '8', 'rgba:-', file], { input: Buffer.from(rgba.buffer, rgba.byteOffset, rgba.length) });
}

// ---------------------------------------------------------------- misc
function hash2(x, y, s = 0) {
  let h = (x * 374761393 + y * 668265263 + s * 2147483647) | 0;
  h = (h ^ (h >>> 13)) * 1274126177 | 0;
  h = h ^ (h >>> 16);
  return (h >>> 0) / 4294967296;
}
function rng(seed) {
  let s = seed >>> 0;
  return () => { s = (s + 0x6D2B79F5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
function vnoise(x, y, s = 0) {
  const x0 = Math.floor(x), y0 = Math.floor(y), fx = x - x0, fy = y - y0;
  const u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy);
  const a = hash2(x0, y0, s), b = hash2(x0 + 1, y0, s), c = hash2(x0, y0 + 1, s), d = hash2(x0 + 1, y0 + 1, s);
  return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v;
}
const hex = h => { h = h.replace('#', ''); return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)]; };

module.exports = { elev, loadOsm, stitch, savePng, hash2, rng, vnoise, hex };
