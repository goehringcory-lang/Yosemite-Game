const G = require('./gen.js');
const L = require('./lib.js');
const { W, H, NR, Es, slope, lam, ovl, land, OV, ID, HS, EB, T0, S } = G;
const hex = L.hex;

// ---------------------------------------------------------------- palettes (light -> dark)
const P = {
  granite: ['#ece6d6', '#d6cfc1', '#b9b2a8', '#9a93a0', '#7b7488', '#5d566e'].map(hex),
  dome:    ['#f1eada', '#dcd5c4', '#c1baad', '#a49daa'].map(hex),
  forest:  ['#78b453', '#62a047', '#4e8b3b', '#3d7433', '#2f5f2d'].map(hex),
  valley:  ['#a3cf62', '#8bbd52', '#74a745', '#5f9139'].map(hex),
  vforest: ['#6aaa4c', '#59973f', '#487f36', '#376a30'].map(hex),
  meadow:  ['#c4e874', '#a6d55c', '#88c04b', '#6da93f'].map(hex),
  wet:     ['#8bcf9a', '#6db484', '#53996f'].map(hex),
  sand:    ['#f5e6ae', '#e3cf8e', '#c9b06d'].map(hex),
  scree:   ['#c9bfa8', '#aaa08b', '#8b8272', '#6f675b'].map(hex),
  scrub:   ['#a3b45a', '#8a9d49', '#728638'].map(hex),
  water:   ['#c6ecf6', '#7cc4e8', '#55a3da', '#3d80c2', '#2b62a3'].map(hex),
  road:    hex('#ecd09a'), roadEdge: hex('#b98d58'), road2: hex('#e0bf88'), path: hex('#bb8f5c'),
  parking: hex('#c9c3b5'),
  ink: hex('#2b2018'),
};
module.exports.P = P;

const img = new Uint8ClampedArray(W * H * 4);
const cls = new Uint8Array(W * H);          // class buffer for post passes
const scrY = new Int16Array(W * NR).fill(-9999); // screen row of each visible source pixel
const setPx = (x, y, c, k = 0) => { if (x < 0 || y < 0 || x >= W || y >= H) return; const i = (y * W + x) * 4; img[i] = c[0]; img[i + 1] = c[1]; img[i + 2] = c[2]; img[i + 3] = 255; cls[y * W + x] = k; };

const BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
const dith = (x, y) => (BAYER[y & 3][x & 3] + 0.5) / 16;
// pick a tone index from a continuous 0..1 value (1 = lit) with ordered dithering
function tone(ramp, v, x, y, spread = 0.9) {
  const n = ramp.length;
  const t = (1 - Math.max(0, Math.min(1, v))) * (n - 1);
  const i = Math.floor(t), f = t - i;
  const j = f * spread + (1 - spread) / 2 > dith(x, y) ? 1 : 0;
  return ramp[Math.min(n - 1, i + j)];
}

// terrain type of a source pixel (ignores overlays)
const T = { valley: 1, forest: 2, granite: 3, dome: 4, meadow: 5, wet: 6, sand: 7, scree: 8, scrub: 9, vforest: 10 };
const baseType = new Uint8Array(W * NR);
for (let i = 0; i < W * NR; i++) {
  const s = slope[i], e = Es[i], lv = land[i];
  let t;
  if (s > 1.15) t = T.granite;
  else if (lv === ID.rock && s > 0.55) t = T.granite;
  else if (lv === ID.rock && s <= 0.55) t = T.dome;
  else if (s > 0.62 && lv === ID.scree) t = T.scree;
  else if (s > 0.85) t = T.granite;
  else if (lv === ID.scree) t = T.scree;
  else if (e > 2500 && s < 0.5 && lv !== ID.wood) t = T.dome;
  else if (e < 1330 && s < 0.5) t = lv === ID.wood ? T.vforest : T.valley;
  else t = T.forest;
  if (s < 0.28) {
    if (lv === ID.meadow) t = T.meadow;
    else if (lv === ID.wet) t = T.wet;
    else if (lv === ID.sand) t = T.sand;
    else if (lv === ID.scrub && e < 1700) t = T.scrub;
  }
  baseType[i] = t;
}
G.baseType = baseType; G.T = T;

// ---------------------------------------------------------------- oblique painter (front to back)
function colorTop(t, i, x, y, sx, sy, run) {
  const v = lam[i];
  switch (t) {
    case T.granite: {
      const c = tone(P.granite, 0.2 + v * 0.95, sx, sy, 0.5);
      return c;
    }
    case T.dome: return tone(P.dome, 0.2 + v * 0.9, sx, sy);
    case T.forest: {
      const n = L.hash2(sx, sy, 5);
      return tone(P.forest, 0.2 + v * 0.85 - (n > 0.82 ? 0.25 : 0), sx, sy);
    }
    case T.vforest: {
      const n = L.hash2(sx, sy, 8);
      return tone(P.vforest, 0.3 + v * 0.6 - (n > 0.8 ? 0.3 : 0), sx, sy);
    }
    case T.valley: {
      const n = L.hash2(sx, sy, 7);
      return tone(P.valley, 0.3 + v * 0.6 - (n > 0.86 ? 0.3 : 0), sx, sy);
    }
    case T.meadow: {
      const n = L.hash2(sx, sy, 9);
      const c = tone(P.meadow, 0.4 + v * 0.5, sx, sy);
      return c;
    }
    case T.wet: return tone(P.wet, 0.4 + v * 0.5, sx, sy);
    case T.sand: return tone(P.sand, 0.5 + v * 0.5, sx, sy);
    case T.scree: return tone(P.scree, 0.2 + v * 0.9, sx, sy);
    case T.scrub: return tone(P.scrub, 0.3 + v * 0.7, sx, sy);
  }
  return P.ink;
}
function colorFace(t, i, sx, ys, k, len) {
  // vertical face rows below the lip: k = 0 is the lip, k >= 1 the face
  const v = lam[i];
  const streak = L.vnoise(sx * 0.85, ys * 0.06, 3) + (L.hash2(sx, 11, 1) - 0.5) * 0.5;
  switch (t) {
    case T.granite: {
      // vertical water-streaks and broad tonal panels, like Yosemite's real walls
      const panel = L.vnoise(sx * 0.16, ys * 0.035, 8);
      const crack = L.hash2(sx, 3, 2) > 0.9 ? 0.22 : 0;
      let val = 0.10 + v * 0.62 + (panel - 0.5) * 0.36 - (streak > 0.66 ? 0.3 : 0) - crack;
      if (k === 1) val += 0.12;                      // lit lip below the edge
      if (k === len - 1 && len > 2) val -= 0.32;     // shadow at the foot
      return tone(P.granite, val, sx, ys, 0.35);
    }
    case T.dome: return tone(P.dome, 0.15 + v * 0.7 - (streak > 0.7 ? 0.3 : 0), sx, ys, 0.6);
    case T.scree: return tone(P.scree, 0.15 + v * 0.6, sx, ys, 0.6);
    case T.forest: return tone(P.forest, 0.1 + v * 0.7 - 0.12 * (k === len - 1), sx, ys, 0.7);
    default: return tone(P.forest, 0.05 + v * 0.6, sx, ys, 0.7);
  }
}

const runInfo = new Int16Array(W * NR);   // length of the run painted by each source pixel
for (let x = 0; x < W; x++) {
  let top = H;
  for (let sy = NR - 1; sy >= 0; sy--) {
    const i = sy * W + x;
    const ys = Math.round(sy - T0 - (Es[i] - EB) * HS);
    if (ys >= top) continue;
    const y0 = Math.max(0, ys), len = top - ys;
    scrY[i] = ys; runInfo[i] = len;
    const t = baseType[i];
    for (let y = y0; y < top && y < H; y++) {
      const k = y - ys;
      const c = k === 0 ? colorTop(t, i, x, y, x, sy, len) : (len === 1 ? colorTop(t, i, x, y, x, sy, len) : colorFace(t, i, x, y, k, len));
      setPx(x, y, c, t);
    }
    top = ys;
    if (top <= 0) break;
  }
}
G.img = img; G.cls = cls; G.scrY = scrY; G.runInfo = runInfo;

if (process.env.STAGE1) {
  L.savePng(G.OUT + '/stage1.png', W, H, img);
  console.log('saved stage1', W, H, 'NR', NR, 'MPP', G.MPP.toFixed(1));
} else require('./post.js');
