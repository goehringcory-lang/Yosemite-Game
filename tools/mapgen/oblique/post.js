// Second pass: overlays, sprites, waterfalls, grade. Runs after render.js has painted terrain.
const G = require('./gen.js');
const L = require('./lib.js');
const fs = require('fs');
const { W, H, NR, Es, slope, ovl, land, OV, ID, HS, EB, T0, img, cls, scrY, runInfo, baseType, T, el, tag, ringsOf } = G;
const { P } = require('./render.js');
const hex = L.hex;
const R = L.rng(20260928);

const getPx = (x, y) => { const i = (y * W + x) * 4; return [img[i], img[i + 1], img[i + 2]]; };
const setPx = (x, y, c, k) => { if (x < 0 || y < 0 || x >= W || y >= H) return; const i = (y * W + x) * 4; img[i] = c[0]; img[i + 1] = c[1]; img[i + 2] = c[2]; img[i + 3] = 255; if (k !== undefined) cls[y * W + x] = k; };
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const shade = (c, f) => [c[0] * f, c[1] * f, c[2] * f];
const projY = (sy, e) => sy - T0 - (e - EB) * HS;
const project = (lon, lat, e) => {
  const sx = G.lon2x(lon), sy = G.lat2y(lat);
  const ee = e === undefined ? Es[Math.max(0, Math.min(NR - 1, Math.round(sy))) * W + Math.max(0, Math.min(W - 1, Math.round(sx)))] : e;
  return { x: sx, y: projY(sy, ee), sx, sy, e: ee };
};
const CLS = { water: 20, road: 21, house: 22, tree: 23, fall: 24, path: 25 };
const hard = new Uint8Array(W * H); // 1 = keep trees off

// ---------------------------------------------------------------- overlays
for (let sy = 0; sy < NR; sy++) for (let x = 0; x < W; x++) {
  const i = sy * W + x, o = ovl[i];
  if (!o || scrY[i] < -9000) continue;
  const ys = scrY[i], len = runInfo[i];
  if (len > 3 || slope[i] > 0.9) continue;
  const rows = Math.min(len, 2);
  for (let k = 0; k < rows; k++) {
    const y = ys + k;
    let c, kk = CLS.road;
    switch (o) {
      case OV.water: {
        const n = L.hash2(x, sy, 21);
        c = n > 0.93 ? P.water[0] : n > 0.55 ? P.water[1] : P.water[2];
        if (((x + sy) & 3) === 0 && n > 0.3) c = P.water[1];
        kk = CLS.water; break;
      }
      case OV.stream: if (Es[i] > 1400) continue; c = P.water[1]; kk = CLS.water; break;
      case OV.road: c = P.road; hard[y * W + x] = 1; break;
      case OV.road2: c = P.road2; hard[y * W + x] = 1; break;
      case OV.path: if (L.hash2(x, sy, 3) < 0.55) { c = P.path; kk = CLS.path; } else continue; break;
      case OV.parking: c = P.parking; hard[y * W + x] = 1; break;
      default: continue;
    }
    if (o === OV.water || o === OV.stream) hard[y * W + x] = 1;
    setPx(x, y, c, kk);
  }
}
// banks & road edges
{
  const snap = Uint8Array.from(cls);
  for (let y = 0; y < H - 1; y++) for (let x = 0; x < W; x++) {
    const k = snap[y * W + x];
    if (k === CLS.water) {
      for (const [dx, dy] of [[0, 1], [-1, 0], [1, 0], [0, -1]]) {
        const xx = x + dx, yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
        const kn = snap[yy * W + xx];
        if (kn !== CLS.water && kn !== CLS.fall) { const c = getPx(xx, yy); if (dy >= 0) setPx(xx, yy, shade(mix(c, [40, 70, 50], 0.35), 0.86)); }
      }
    }
    if (k === CLS.road && snap[(y + 1) * W + x] !== CLS.road && snap[(y + 1) * W + x] !== CLS.water) {
      setPx(x, y + 1, shade(getPx(x, y + 1), 0.72));
    }
  }
  // shallow highlight on water top rows
  for (let y = 1; y < H; y++) for (let x = 0; x < W; x++) if (snap[y * W + x] === CLS.water && snap[(y - 1) * W + x] !== CLS.water) setPx(x, y, mix(getPx(x, y), P.water[0], 0.35));
}

// ---------------------------------------------------------------- sprites
const OUTL = hex('#1d2c22');
function makeSprite(w, h) { return { w, h, d: new Array(w * h).fill(null) }; }
function put(s, x, y, c) { if (x >= 0 && y >= 0 && x < s.w && y < s.h) s.d[y * s.w + x] = c; }
function outline(s, col = OUTL) {
  const o = makeSprite(s.w + 2, s.h + 2);
  for (let y = 0; y < s.h; y++) for (let x = 0; x < s.w; x++) if (s.d[y * s.w + x]) o.d[(y + 1) * o.w + x + 1] = s.d[y * s.w + x];
  const out = o.d.slice();
  for (let y = 0; y < o.h; y++) for (let x = 0; x < o.w; x++) {
    if (o.d[y * o.w + x]) continue;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const xx = x + dx, yy = y + dy;
      if (xx >= 0 && yy >= 0 && xx < o.w && yy < o.h && o.d[yy * o.w + xx]) { out[y * o.w + x] = col; break; }
    }
  }
  o.d = out; return o;
}
const TREEPAL = {
  fir:   { l: hex('#6bb055'), m: hex('#48914a'), d: hex('#326f40'), t: hex('#6b4a2f') },
  dfir:  { l: hex('#5aa04c'), m: hex('#3d8244'), d: hex('#2a6039'), t: hex('#5a3f2a') },
  pine:  { l: hex('#78ad55'), m: hex('#54903f'), d: hex('#3b7035'), t: hex('#7a5535') },
  oak:   { l: hex('#95cf58'), m: hex('#6bad41'), d: hex('#478436'), t: hex('#6b4a2f') },
  oakg:  { l: hex('#f2cf5a'), m: hex('#e0a63a'), d: hex('#b8762c'), t: hex('#6b4a2f') },
  cot:   { l: hex('#b6df6d'), m: hex('#8fc655'), d: hex('#5f9f44'), t: hex('#8a6a45') },
  apple: { l: hex('#95cf58'), m: hex('#6bad41'), d: hex('#478436'), t: hex('#6b4a2f') },
};
function conifer(w, h, pal, rnd) {
  const s = makeSprite(w, h), cx = (w - 1) / 2, trunk = h >= 9 ? 2 : 1;
  const bodyH = h - trunk;
  for (let y = 0; y < bodyH; y++) {
    const t = y / Math.max(1, bodyH - 1);
    const tier = ((y + 1) % 3 === 0) ? 0.6 : 0;
    const hw = Math.min(cx, 0.35 + (cx - 0.1) * t + tier * (t > 0.2 ? 1 : 0));
    for (let x = 0; x < w; x++) {
      const d = x - cx;
      if (Math.abs(d) <= hw) put(s, x, y, d < -hw * 0.25 ? pal.l : d > hw * 0.35 ? pal.d : pal.m);
    }
  }
  for (let y = bodyH; y < h; y++) put(s, Math.round(cx), y, pal.t);
  return outline(s);
}
function roundTree(r, pal, rnd, trunkH = 2) {
  const w = r * 2 + 1, h = r * 2 + trunkH, s = makeSprite(w, h);
  for (let y = 0; y < r * 2; y++) for (let x = 0; x < w; x++) {
    const dx = (x - r) / (r + 0.35), dy = (y - r + 0.5) / (r + 0.2);
    if (dx * dx + dy * dy > 1) continue;
    const lit = -dx * 0.6 - dy * 0.8 + (rnd() - 0.5) * 0.35;
    put(s, x, y, lit > 0.4 ? pal.l : lit > -0.3 ? pal.m : pal.d);
  }
  for (let y = r * 2; y < h; y++) put(s, r, y, pal.t);
  return outline(s);
}
function makeVariants() {
  const v = {};
  const mk = (name, n, f) => { v[name] = Array.from({ length: n }, (_, i) => f(i)); };
  mk('firS', 4, i => conifer(3 + (i & 1), 5 + (i >> 1), TREEPAL.dfir, R));
  mk('firM', 4, i => conifer(5, 8 + (i & 1), TREEPAL.fir, R));
  mk('firL', 4, i => conifer(5 + (i & 1), 10 + (i >> 1), TREEPAL.fir, R));
  mk('pine', 3, i => conifer(5, 11 + (i & 1), TREEPAL.pine, R));
  mk('oak', 4, i => roundTree(2 + (i & 1), TREEPAL.oak, R));
  mk('oakg', 2, i => roundTree(2, TREEPAL.oakg, R));
  mk('cot', 3, i => roundTree(2, TREEPAL.cot, R, 3));
  mk('apple', 1, () => { const s = roundTree(3, TREEPAL.apple, R); const c = hex('#e04a3c'); [[2, 2], [5, 3], [3, 5]].forEach(([x, y]) => s.d[(y + 1) * s.w + x + 1] = c); return s; });
  return v;
}
const V = makeVariants();
function drawSprite(s, bx, by) { // bx = center x, by = base row
  const ox = Math.round(bx - s.w / 2), oy = Math.round(by - s.h + 1);
  for (let y = 0; y < s.h; y++) for (let x = 0; x < s.w; x++) { const c = s.d[y * s.w + x]; if (c) setPx(ox + x, oy + y, c, CLS.tree); }
}
module.exports.sprites = { V, drawSprite, makeSprite, put, outline, TREEPAL };

// ---------------------------------------------------------------- landmarks / places
function centroid(e) {
  if (e.type === 'node') return { lon: e.lon, lat: e.lat };
  const g = e.geometry || (e.members && e.members.find(m => m.geometry) || {}).geometry;
  if (!g) return null;
  let a = 0, b = 0; for (const p of g) { a += p.lon; b += p.lat; }
  return { lon: a / g.length, lat: b / g.length };
}
const named = (n, k) => el.find(e => tag(e, 'name') === n && (!k || tag(e, k)));
const where = n => { const e = named(n); return e ? centroid(e) : null; };
G.where = where; G.project = project;

const objs = [];
const occ = [];   // circles of reserved space for trees {x,y,rx,ry}
const reserve = (x, y, rx, ry) => occ.push({ x, y, rx, ry });
function onScreen(x, y) { return x >= 0 && x < W && y >= 0 && y < H; }

// buildings clustered onto a 2px grid so the village reads as houses
{
  const cells = new Map();
  for (const e of el) {
    if (e.type !== 'way' || !e.geometry || !tag(e, 'building')) continue;
    const b = tag(e, 'building'); if (['toilets', 'storage_tank', 'roof', 'shed', 'garage', 'service'].includes(b)) continue;
    const c = centroid(e); const p = project(c.lon, c.lat);
    if (!onScreen(p.x, p.y) || scrY[Math.round(p.sy) * W + Math.round(p.sx)] < -9000) continue;
    const kx = Math.round(p.x / 3), ky = Math.round(p.y / 3);
    const key = kx + ',' + ky, cell = cells.get(key) || { x: 0, y: 0, n: 0, kinds: {} };
    cell.x += p.x; cell.y += p.y; cell.n++; cell.kinds[b] = (cell.kinds[b] || 0) + 1; cells.set(key, cell);
  }
  for (const c of cells.values()) {
    const x = c.x / c.n, y = c.y / c.n;
    const kind = Object.entries(c.kinds).sort((a, b) => b[1] - a[1])[0][0];
    objs.push({ y, kind: 'house', x, big: c.n > 2, tent: kind === 'tent' || kind === 'cabin', hotel: kind === 'hotel', n: c.n });
    reserve(x, y, 3, 2);
  }
}
const ROOFS = ['#b5533c', '#8f4634', '#a06a3c', '#6f4a3a', '#c2703f'].map(hex);
const CANVAS = ['#f3e8c8', '#e6d7ad', '#dcd0b0'].map(hex);
function drawHouse(o) {
  const x = Math.round(o.x), y = Math.round(o.y);
  if (o.hotel) {                         // a bigger stone lodge
    for (let dx = -3; dx <= 3; dx++) { setPx(x + dx, y, hex('#8a7f70'), CLS.house); setPx(x + dx, y - 1, hex('#b6a992'), CLS.house); setPx(x + dx, y - 2, hex('#a4472f'), CLS.house); }
    for (let dx = -2; dx <= 2; dx++) setPx(x + dx, y - 3, hex('#c05a3c'), CLS.house);
    setPx(x - 1, y - 1, hex('#5a4a3a'), CLS.house);
    for (let dx = -3; dx <= 3; dx++) setPx(x + dx, y + 1, hex('#3a2c22'), CLS.house);
    return;
  }
  const r = L.hash2(x, y, 4);
  if (o.tent) {                           // canvas tent-cabin: pale roof + ridge
    setPx(x, y - 1, CANVAS[0], CLS.house); setPx(x + 1, y - 1, CANVAS[1], CLS.house);
    setPx(x, y, CANVAS[2], CLS.house); setPx(x + 1, y, shade(CANVAS[2], 0.8), CLS.house);
    setPx(x, y + 1, hex('#5a4634'), CLS.house); setPx(x + 1, y + 1, hex('#5a4634'), CLS.house);
    return;
  }
  const roof = ROOFS[Math.floor(r * ROOFS.length)];
  const w = o.big ? 3 : 2;
  for (let dx = 0; dx < w; dx++) { setPx(x + dx, y - 1, roof, CLS.house); setPx(x + dx, y, shade(roof, 0.82), CLS.house); setPx(x + dx, y + 1, hex('#3a2c22'), CLS.house); }
  setPx(x, y - 1, mix(roof, [255, 230, 190], 0.25), CLS.house);
}

// ---------------------------------------------------------------- trees
// keep a 2px clear margin around roads, water, parking
{
  const d = Uint8Array.from(hard);
  for (let y = 2; y < H - 2; y++) for (let x = 2; x < W - 2; x++) if (d[y * W + x]) for (let dy = -2; dy <= 1; dy++) for (let dx = -2; dx <= 2; dx++) hard[(y + dy) * W + x + dx] = 1;
}
const TREES = [];
{
  const cell = new Map(); // spatial hash for spacing
  const cs = 6;
  const near = (x, y, rx, ry) => {
    for (let cy = Math.floor((y - ry) / cs); cy <= Math.floor((y + ry) / cs); cy++) for (let cx = Math.floor((x - rx) / cs); cx <= Math.floor((x + rx) / cs); cx++) {
      const l = cell.get(cx + ',' + cy); if (!l) continue;
      for (const t of l) { const dx = (t.x - x) / rx, dy = (t.y - y) / ry; if (dx * dx + dy * dy < 1) return true; }
    }
    return false;
  };
  const add = (x, y, ty, sp) => { const k = Math.floor(x / cs) + ',' + Math.floor(y / cs); (cell.get(k) || cell.set(k, []).get(k)).push({ x, y }); TREES.push({ x, y, ty, sp }); };
  const order = []; for (let sy = 0; sy < NR; sy++) for (let x = 0; x < W; x++) order.push(sy * W + x);
  for (let i = order.length - 1; i > 0; i--) { const j = Math.floor(R() * (i + 1)); [order[i], order[j]] = [order[j], order[i]]; }
  const resv = occ.slice();
  for (const i of order) {
    const ys = scrY[i]; if (ys < -9000) continue;
    const t = baseType[i], sx = i % W, sy = (i / W) | 0;
    if (ovl[i] || runInfo[i] > 2 || ys < 1 || ys >= H - 1) continue;
    if (hard[ys * W + sx]) continue;
    const e = Es[i], rn = R();
    let dens, kind;
    if (t === T.vforest) { dens = 0.12; kind = 'wood'; }
    else if (t === T.valley) { dens = 0.012; kind = 'valley'; }
    else if (t === T.forest) { dens = e < 1500 ? 0.09 : e < 2000 ? 0.08 : 0.05; kind = 'slope'; }
    else if (t === T.scrub) { dens = 0.02; kind = 'valley'; }
    else if (t === T.meadow) { dens = 0.004; kind = 'valley'; }
    else if (t === T.dome) { dens = 0.008; kind = 'dome'; }
    else if (t === T.scree) { dens = 0.012; kind = 'dome'; }
    else continue;
    if (rn > dens) continue;
    if (resv.some(o => { const dx = (o.x - sx) / o.rx, dy = (o.y - ys) / o.ry; return dx * dx + dy * dy < 1; })) continue;
    let sp;
    const r2 = R();
    if (kind === 'wood') sp = r2 < 0.34 ? 'oak' : r2 < 0.4 ? 'oakg' : r2 < 0.5 ? 'cot' : r2 < 0.82 ? 'firM' : 'pine';
    else if (kind === 'valley') sp = r2 < 0.55 ? 'oak' : r2 < 0.65 ? 'oakg' : r2 < 0.85 ? 'firM' : 'pine';
    else if (kind === 'slope') {
      sp = e > 2100 ? 'firS' : e > 1650 ? (r2 < 0.5 ? 'firM' : 'firS') : (r2 < 0.12 ? 'pine' : r2 < 0.5 ? 'firM' : 'firS');
      if (e < 1350 && r2 > 0.9) sp = 'oak';
    } else sp = 'firS';
    const big = sp.startsWith('oak') || sp === 'cot' ? [6.5, 5] : (sp === 'firS' ? [3.8, 3.6] : [4.6, 4.6]);
    if (near(sx, ys, big[0], big[1])) continue;
    add(sx, ys, kind, sp);
  }
}
for (const t of TREES) objs.push({ y: t.y, kind: 'tree', x: t.x, sp: t.sp });

// meadow details: flowers & grass tufts painted on the ground before sprites
for (let sy = 0; sy < NR; sy++) for (let x = 0; x < W; x++) {
  const i = sy * W + x, ys = scrY[i]; if (ys < 0 || ys >= H) continue;
  if (ovl[i] || runInfo[i] > 1) continue;
  const t = baseType[i], n = L.hash2(x, sy, 33);
  if (t === T.meadow) {
    if (n < 0.03) setPx(x, ys, [hex('#fff6d8'), hex('#ffd96a'), hex('#ffb1c8'), hex('#c9a5ff')][Math.floor(L.hash2(x, sy, 2) * 4)]);
    else if (n < 0.1) setPx(x, ys, hex('#5c9e3a'));
  } else if ((t === T.valley) && n < 0.05) setPx(x, ys, hex('#3f7833'));
}

module.exports.ctx = { objs, project, projY, named, where, centroid, CLS, hard, getPx, setPx, mix, shade, P, V, drawSprite, R };
require('./finish.js');
