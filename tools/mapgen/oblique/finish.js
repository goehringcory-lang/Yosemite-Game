const G = require('./gen.js');
const L = require('./lib.js');
const fs = require('fs');
const { W, H, NR, Es, HS, EB, T0, img, cls, scrY } = G;
const { ctx, sprites } = require('./post.js');
const { objs, project, CLS, getPx, setPx, mix, shade, P, V, drawSprite, R } = ctx;
const hex = L.hex;

// ---------------------------------------------------------------- waterfalls (drawn on the wall faces)
function fall(lon, lat, hm, opt = {}) {
  const p = opt.at || project(lon, lat);
  const len = Math.max(4, Math.round(hm * HS * (opt.stretch || 1)) + 1);
  const x0 = Math.round(p.x), y0 = Math.round(p.y);
  const wide = opt.wide || 1;
  const white = hex('#ffffff'), pale = hex('#e2f5fc'), sky = hex('#a4d9f0'), deep = hex('#78bde3'), edge = hex('#5d7fae');
  for (let k = 0; k < len; k++) {
    const y = y0 + k;
    const x = x0 + (opt.sway ? Math.round(Math.sin(k * 0.8 + 1) * opt.sway) : 0);
    const taper = k < 1 ? 0 : 1;
    if (wide > 1) {
      setPx(x - 2, y, edge, CLS.fall);
      setPx(x - 1, y, k % 2 ? pale : white, CLS.fall); setPx(x, y, white, CLS.fall);
      setPx(x + 1, y, k % 3 === 0 ? sky : pale, CLS.fall);
      setPx(x + 2, y, edge, CLS.fall);
    } else {
      setPx(x - 1, y, edge, CLS.fall);
      setPx(x, y, k % 3 === 2 ? pale : white, CLS.fall);
      setPx(x + 1, y, edge, CLS.fall);
    }
  }
  const fy = y0 + len, fx = x0;
  setPx(x0 - 1, y0 - 1, edge, CLS.fall); setPx(x0, y0 - 1, sky, CLS.fall); setPx(x0 + 1, y0 - 1, edge, CLS.fall);
  const mist = [[-2, 0, pale], [-1, 0, white], [0, 0, white], [1, 0, white], [2, 0, pale], [-1, 1, sky], [0, 1, pale], [1, 1, sky], [-3, 1, deep], [3, 1, deep], [0, -1, white]];
  for (const [dx, dy, c] of mist) setPx(fx + dx, fy + dy - 1, c, CLS.fall);
  return { x: fx, y: fy, top: y0 };
}
const falls = {};
if (!process.env.NOFALLS) {
  const up = fall(-119.5968, 37.7570, 440, { wide: 2 });
  fall(-119.59735, 37.7543, 206, { sway: 1 });
  falls.yosemite = fall(-119.5971, 37.7514, 98, { wide: 2 });
  falls.bridalveil = fall(-119.6468, 37.7168, 188, { wide: 2, stretch: 1.2 });
  fall(-119.6478, 37.7360, 491, { sway: 1 });           // Ribbon Fall
  fall(-119.6282, 37.7313, 470);                         // Horsetail
  fall(-119.5710, 37.7496, 380);                         // Royal Arch Cascade
  fall(-119.5965, 37.7249, 590);                         // Sentinel Fall
  fall(-119.5749, 37.7350, 310);                         // Staircase
  fall(-119.5437, 37.7276, 97, { wide: 2 });             // Vernal
  fall(-119.5334, 37.7249, 181, { wide: 2 });            // Nevada
  fall(-119.5349, 37.7655, 650);                         // Snow Creek
}

// ---------------------------------------------------------------- special places
const S = { camp: [], lodge: [], chapel: [], orchard: [] };
const at = (n) => ctx.where(n);
function place(name, type, lonlat) {
  const c = lonlat || at(name); if (!c) { console.log('missing', name); return null; }
  const p = project(c.lon, c.lat);
  objs.push({ y: p.y + 0.4, kind: type, x: p.x, name });
  return p;
}
place('Camp 4', 'camp'); place('Upper Pines Campground', 'camp'); place('Lower Pines Campground', 'camp'); place('North Pines Campground', 'camp'); place('Housekeeping Camp', 'camp');
place('Ahwahnee Hotel', 'lodge'); place('Yosemite Valley Lodge', 'lodge');
place('Yosemite Valley Chapel', 'chapel');
place('Lamon Orchard', 'orchard', { lon: -119.5672, lat: 37.7352 });

function drawObj(o) {
  const x = Math.round(o.x), y = Math.round(o.y);
  switch (o.kind) {
    case 'tree': drawSprite(V[o.sp][Math.floor(L.hash2(x, y, 1) * V[o.sp].length)], o.x, o.y + 1); break;
    case 'house': ctx.drawHouse ? ctx.drawHouse(o) : null; break;
    case 'camp': {
      const tents = [[-3, 0, '#e8873a', '#b8602a'], [1, -1, '#4b86c8', '#33639e'], [4, 1, '#e8c23a', '#b8962a']];
      for (const [dx, dy, c, d] of tents) {
        const tx = x + dx, ty = y + dy;
        setPx(tx, ty - 3, hex('#2b2018')); setPx(tx - 1, ty - 2, hex('#2b2018')); setPx(tx + 1, ty - 2, hex('#2b2018'));
        setPx(tx, ty - 2, hex(c)); setPx(tx - 2, ty - 1, hex('#2b2018')); setPx(tx + 2, ty - 1, hex('#2b2018'));
        setPx(tx - 1, ty - 1, hex(c)); setPx(tx, ty - 1, hex(d)); setPx(tx + 1, ty - 1, hex(d));
        for (let k = -2; k <= 2; k++) setPx(tx + k, ty, hex('#2b2018'));
      }
      break;
    }
    case 'lodge': {
      const c = { wall: hex('#b9a98d'), roof: hex('#7e3f2f'), roof2: hex('#a44f38'), ink: hex('#2b2018') };
      for (let dx = -5; dx <= 5; dx++) { setPx(x + dx, y - 5, c.ink); setPx(x + dx, y + 1, c.ink); }
      for (let dx = -4; dx <= 4; dx++) { setPx(x + dx, y - 4, c.roof2); setPx(x + dx, y - 3, c.roof); }
      for (let dx = -5; dx <= 5; dx++) { setPx(x + dx, y - 2, c.wall); setPx(x + dx, y - 1, shade(c.wall, 0.86)); setPx(x + dx, y, shade(c.wall, 0.72)); }
      setPx(x - 5, y - 4, c.ink); setPx(x + 5, y - 4, c.ink); setPx(x - 5, y - 3, c.ink); setPx(x + 5, y - 3, c.ink); setPx(x - 5, y - 2, c.ink); setPx(x + 5, y - 2, c.ink); setPx(x - 5, y - 1, c.ink); setPx(x + 5, y - 1, c.ink); setPx(x - 5, y, c.ink); setPx(x + 5, y, c.ink);
      for (const dx of [-3, -1, 1, 3]) setPx(x + dx, y - 1, hex('#3d3a44'));
      break;
    }
    case 'chapel': {
      const ink = hex('#2b2018');
      setPx(x, y - 7, ink); setPx(x - 1, y - 6, ink); setPx(x + 1, y - 6, ink); setPx(x, y - 6, hex('#f3ecd8'));
      for (let dy = -5; dy <= -3; dy++) { setPx(x - 1, dy + y, ink); setPx(x + 1, dy + y, ink); setPx(x, dy + y, hex('#f3ecd8')); }
      for (let dx = -3; dx <= 3; dx++) { setPx(x + dx, y - 2, ink); setPx(x + dx, y + 1, ink); setPx(x + dx, y - 1, dx < 0 ? hex('#f3ecd8') : hex('#d9cfb4')); setPx(x + dx, y, dx < 0 ? hex('#e6dcc0') : hex('#c9bf9f')); }
      setPx(x - 3, y - 1, ink); setPx(x + 3, y - 1, ink); setPx(x - 3, y, ink); setPx(x + 3, y, ink);
      break;
    }
    case 'orchard': {
      for (const [dx, dy] of [[-8, -2], [-4, 2], [8, 1], [4, -3], [-1, 4], [11, -2]]) drawSprite(V.apple[0], x + dx, y + dy);
      // homestead cabin
      const ink = hex('#2b2018');
      for (let dx = -3; dx <= 3; dx++) { setPx(x + dx, y - 4, ink); setPx(x + dx, y + 1, ink); }
      for (let dx = -2; dx <= 2; dx++) { setPx(x + dx, y - 3, hex('#c96b3f')); setPx(x + dx, y - 2, hex('#a4512d')); setPx(x + dx, y - 1, hex('#a8794a')); setPx(x + dx, y, hex('#8c5f37')); }
      for (const dy of [-3, -2, -1, 0]) { setPx(x - 3, y + dy, ink); setPx(x + 3, y + dy, ink); }
      setPx(x, y, hex('#3a2818')); setPx(x, y - 1, hex('#3a2818'));
      break;
    }
  }
}
// house drawing lives in post.js scope; re-declare here
ctx.drawHouse = function (o) {
  const x = Math.round(o.x), y = Math.round(o.y);
  const ROOFS = ['#b5533c', '#8f4634', '#a06a3c', '#6f4a3a', '#c2703f'].map(hex);
  const CANVAS = ['#f3e8c8', '#e6d7ad', '#dcd0b0'].map(hex);
  if (o.hotel) {
    for (let dx = -3; dx <= 3; dx++) { setPx(x + dx, y, hex('#8a7f70'), CLS.house); setPx(x + dx, y - 1, hex('#b6a992'), CLS.house); setPx(x + dx, y - 2, hex('#a4472f'), CLS.house); }
    for (let dx = -2; dx <= 2; dx++) setPx(x + dx, y - 3, hex('#c05a3c'), CLS.house);
    for (let dx = -3; dx <= 3; dx++) setPx(x + dx, y + 1, hex('#3a2c22'), CLS.house);
    return;
  }
  if (o.tent) {
    setPx(x, y - 1, CANVAS[0], CLS.house); setPx(x + 1, y - 1, CANVAS[1], CLS.house);
    setPx(x, y, CANVAS[2], CLS.house); setPx(x + 1, y, shade(CANVAS[2], 0.8), CLS.house);
    setPx(x, y + 1, hex('#5a4634'), CLS.house); setPx(x + 1, y + 1, hex('#5a4634'), CLS.house);
    return;
  }
  const roof = ROOFS[Math.floor(L.hash2(x, y, 4) * ROOFS.length)];
  const w = o.big ? 3 : 2;
  for (let dx = 0; dx < w; dx++) { setPx(x + dx, y - 1, roof, CLS.house); setPx(x + dx, y, shade(roof, 0.82), CLS.house); setPx(x + dx, y + 1, hex('#3a2c22'), CLS.house); }
  setPx(x, y - 1, mix(roof, [255, 230, 190], 0.25), CLS.house);
};

// cliff outlines: a dark, slightly violet line along rock edges makes the walls cut out like painted tiles
{
  const snap = Uint8Array.from(cls);
  const rock = k => k === 3 || k === 4;
  for (let y = 1; y < H - 1; y++) for (let x = 1; x < W - 1; x++) {
    const k = snap[y * W + x];
    if (!rock(k) && k !== 8) continue;
    const up = snap[(y - 1) * W + x], dn = snap[(y + 1) * W + x], lf = snap[y * W + x - 1], rt = snap[y * W + x + 1];
    const edge = (n) => !rock(n) && n !== 8 && n !== CLS.fall;
    if (edge(dn) || (edge(up) && k !== 8)) {
      const c = getPx(x, y); setPx(x, y, [c[0] * 0.52 + 14, c[1] * 0.5 + 8, c[2] * 0.6 + 24]);
    } else if (edge(lf) || edge(rt)) {
      const c = getPx(x, y); setPx(x, y, [c[0] * 0.78, c[1] * 0.76, c[2] * 0.84]);
    }
  }
}
objs.sort((a, b) => a.y - b.y);
for (const o of objs) drawObj(o);

// ---------------------------------------------------------------- grade: warm light, distance haze, soft vignette
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const i = (y * W + x) * 4;
  let r = img[i], g = img[i + 1], b = img[i + 2];
  const lum = (r + g + b) / 3;
  const warm = 0.045 * (lum / 255);
  r = r * (1 + warm) + 2; b = b * (1 - warm * 0.9);
  // gentle vignette
  const dx = (x / W - 0.5) * 2, dy = (y / H - 0.5) * 2;
  const v = 1 - 0.12 * Math.pow(Math.max(0, Math.hypot(dx * 0.9, dy) - 0.6), 1.5);
  const hz = Math.max(0, 1 - y / 70) * 0.22;                 // aerial perspective toward the rim
  r = r * (1 - hz) + 196 * hz; g = g * (1 - hz) + 214 * hz; b = b * (1 - hz) + 226 * hz;
  img[i] = Math.max(0, Math.min(255, r * v)); img[i + 1] = Math.max(0, Math.min(255, g * v)); img[i + 2] = Math.max(0, Math.min(255, b * v));
}

L.savePng(G.OUT + '/yosemite_valley.png', W, H, img);

// ---------------------------------------------------------------- data the game needs to use the picture
{
  const P0 = require('./points.js');
  const ROUND = v => +v.toFixed(1);
  const pt = (lon, lat) => { const p = project(lon, lat); return [ROUND(p.x), ROUND(p.y)]; };
  const points = P0.points.map(p => {
    const c = p.at ? { lon: p.at[0], lat: p.at[1] } : ctx.where(p.osm);
    if (!c) throw new Error('no OSM match for ' + p.name);
    const out = { id: p.id, name: p.name, tier: p.tier, anchor: pt(c.lon, c.lat), label: p.label, blurb: p.blurb };
    if (p.stop) out.stop = p.stop;
    return out;
  });
  const kiosks = P0.kiosks.map(k => { const c = ctx.where(k.osm); if (!c) throw new Error('no kiosk ' + k.osm); return { name: k.name, anchor: pt(c.lon, c.lat) }; });
  const climbs = P0.climbs.map(k => {
    let lon, lat;
    if (k.pos) { lon = -119.682 + (k.pos[0] / 16 * 45) / 88145.89; lat = 37.762 - (k.pos[1] / 16 * 45) / 110991.47; }
    else { const c = ctx.where(k.osm); lon = c.lon; lat = c.lat; }
    const a = pt(lon, lat);
    return { route: k.route, anchor: [ROUND(a[0] + (k.dx || 0)), ROUND(a[1] + (k.dy || 0))] };
  });
  const view = {
    _note: 'Generated by tools/mapgen/oblique (node gen.js). Do not edit by hand.',
    width: W, height: H, west: G.WEST, east: G.EAST, lat0: G.LAT0, dlat: G.DLAT,
    t0: T0, hs: HS, eb: EB, relief: 'res://assets/map/areas/yosemite_valley_relief.png', relief_base: 1100, relief_step: 8, relief_rows: G.NR_REAL,
    points, kiosks, climbs,
  };
  fs.writeFileSync(G.OUT + '/yosemite_valley_view.json', JSON.stringify(view, null, 1));
  // elevation on the picture's source grid, 8 m per level, so the game can lift a longitude/latitude onto the picture
  const rel = new Uint8Array(W * G.NR_REAL);
  for (let i = 0; i < rel.length; i++) rel[i] = Math.max(0, Math.min(255, Math.round((Es[i] - 1100) / 8)));
  require('child_process').execFileSync('magick', ['-size', `${W}x${G.NR_REAL}`, '-depth', '8', 'gray:-', G.OUT + '/yosemite_valley_relief.png'], { input: Buffer.from(rel.buffer) });
}

// ---------------------------------------------------------------- kit sheet (sprites on parchment)
{
  const bg = hex('#e9d6a3'), bg2 = hex('#e2cd97');
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const i = (y * W + x) * 4; const c = ((x >> 3) + (y >> 3)) & 1 ? bg : bg2; img[i] = c[0]; img[i + 1] = c[1]; img[i + 2] = c[2]; img[i + 3] = 255; }
  const tr = (sp, x, y, n = 0) => drawSprite(V[sp][n % V[sp].length], x, y);
  // row A: trees
  [[20, 0], [32, 1], [44, 2]].forEach(([x, n]) => tr('firS', x, 34, n));
  [[66, 0], [80, 1], [94, 2]].forEach(([x, n]) => tr('firM', x, 34, n));
  [[118, 0], [132, 1]].forEach(([x, n]) => tr('pine', x, 34, n));
  [[160, 0], [174, 1], [188, 2], [204, 3]].forEach(([x, n]) => tr('oak', x, 34, n));
  tr('oakg', 224, 34, 0); tr('cot', 240, 34, 0); tr('apple', 262, 34, 0);
  // row B: buildings
  const H0 = 86;
  ctx.drawHouse({ x: 16, y: H0, big: false }); ctx.drawHouse({ x: 26, y: H0, big: true }); ctx.drawHouse({ x: 40, y: H0, big: false, tent: true });
  ctx.drawHouse({ x: 56, y: H0, hotel: true });
  drawObj({ kind: 'camp', x: 90, y: H0 }); drawObj({ kind: 'lodge', x: 128, y: H0 + 1 }); drawObj({ kind: 'chapel', x: 158, y: H0 }); drawObj({ kind: 'orchard', x: 208, y: H0 });
  // row C: waterfalls
  fall(0, 0, 590, { at: { x: 22, y: 112 }, wide: 2 });
  fall(0, 0, 300, { at: { x: 46, y: 116 } });
  fall(0, 0, 200, { at: { x: 64, y: 118 }, sway: 1 });
  fall(0, 0, 100, { at: { x: 82, y: 120 } });
  // ground swatches drawn as small tiles
  const sw = (x, y, cols) => cols.forEach((c, k) => { for (let dy = 0; dy < 10; dy++) for (let dx = 0; dx < 10; dx++) setPx(x + k * 10 + dx, y + dy, c); });
  sw(110, 108, P.granite); sw(110, 120, P.forest.slice(0, 5)); sw(176, 108, P.meadow); sw(176, 120, P.water); sw(232, 108, P.valley); sw(232, 120, P.sand);
  if (process.env.KIT) L.savePng(process.env.KIT, W, H, img);
}
console.log('done', W, H, 'objs', objs.length);
