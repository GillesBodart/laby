// Turns the generated low-resolution art into smooth HD art.
//
// Each PNG under assets/ is upscaled 4x with the xBR edge-directed filter
// (smooth, anti-aliased contours instead of stair-stepped pixels), then
// box-filtered down to 2x. The Laby HD Texture importer
// (addons/laby_hd_texture) imports the result at its logical size, so
// gameplay code, atlas regions and tile sets keep their units.
//
// Run after tools/generate_placeholder_art.gd, then reimport:
//   cd tools/smooth_art && npm install && node smooth_art.mjs
//   godot --headless --path . --import
//
// manifest.json records the hash of every HD output, so files that are
// already smooth are skipped and only freshly generated art is processed.

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';
import { PNG } from 'pngjs';
import { xbr4x } from 'xbr-js/src/index.js';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../..');
const ASSETS = path.join(ROOT, 'assets');
const MANIFEST = path.join(HERE, 'manifest.json');
const PAD = 3;

// Sheets whose cells must not bleed into each other: [cell w, cell h].
const GRIDS = {
  'assets/tilesets/clearing_tiles.png': [32, 32],
  'assets/sprites/characters/player.png': [48, 48],
  'assets/sprites/environment/campfire.png': [32, 32],
  'assets/sprites/structures/roof.png': [32, 32],
  'assets/ui/icons/time_icons.png': [9, 9],
};

// Survivor walk strips (idle + 4 walk poses) are 48 px cells too.
const gridOf = (rel) => GRIDS[rel] ?? (/characters\/survivors\/.*_walk\.png$/.test(rel) ? [48, 48] : undefined);

// Drawn through their RID in texture pixels (StyleBoxTexture 9-slice), so
// they keep their logical resolution; linear filtering smooths them.
const KEEP = new Set(['assets/ui/frame.png']);

const sha1 = (buf) => crypto.createHash('sha1').update(buf).digest('hex');

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.png')) out.push(p);
  }
  return out;
}

// Copies a cell into a buffer padded by PAD pixels of edge clamp, so
// contours touching the border stay straight (walls, tiles, joins).
function cut(src, sw, x0, y0, w, h) {
  const W = w + PAD * 2, H = h + PAD * 2;
  const out = new Uint8Array(W * H * 4);
  for (let y = 0; y < H; y++) {
    const sy = y0 + Math.min(Math.max(y - PAD, 0), h - 1);
    for (let x = 0; x < W; x++) {
      const sx = x0 + Math.min(Math.max(x - PAD, 0), w - 1);
      const i = (sy * sw + sx) * 4, j = (y * W + x) * 4;
      out[j] = src[i]; out[j + 1] = src[i + 1]; out[j + 2] = src[i + 2]; out[j + 3] = src[i + 3];
    }
  }
  return { data: out, w: W, h: H };
}

// Gives transparent pixels the colour of their opaque neighbours, so the
// filter's blends along a silhouette never pull in black.
function bleed(img) {
  const { data, w, h } = img;
  for (let pass = 0; pass < 3; pass++) {
    const src = Uint8Array.from(data);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const j = (y * w + x) * 4;
      if (src[j + 3] !== 0) continue;
      let r = 0, g = 0, b = 0, n = 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        const k = (ny * w + nx) * 4;
        if (src[k + 3] === 0 && (src[k] | src[k + 1] | src[k + 2]) === 0) continue;
        r += src[k]; g += src[k + 1]; b += src[k + 2]; n++;
      }
      if (n) { data[j] = r / n; data[j + 1] = g / n; data[j + 2] = b / n; }
    }
  }
}

// xBR 4x of a padded cell, box-filtered (alpha-weighted) to 2x, written
// into `dst` at (dx, dy) in 2x units.
function smoothCell(cell, w, h, dst, dw, dx, dy) {
  bleed(cell);
  const src = new Uint32Array(cell.data.buffer);
  const big = new Uint8Array(xbr4x(src, cell.w, cell.h, { blendColors: true, scaleAlpha: true }).buffer);
  const BW = cell.w * 4;
  for (let y = 0; y < h * 2; y++) for (let x = 0; x < w * 2; x++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (let sy = 0; sy < 2; sy++) for (let sx = 0; sx < 2; sx++) {
      const i = ((PAD * 4 + y * 2 + sy) * BW + PAD * 4 + x * 2 + sx) * 4;
      const al = big[i + 3];
      r += big[i] * al; g += big[i + 1] * al; b += big[i + 2] * al; a += al;
    }
    const j = ((dy + y) * dw + dx + x) * 4;
    if (a > 0) { dst[j] = Math.round(r / a); dst[j + 1] = Math.round(g / a); dst[j + 2] = Math.round(b / a); }
    dst[j + 3] = Math.round(a / 4);
  }
}

function smooth(png, grid) {
  const { width: w, height: h } = png;
  const [cw, ch] = grid && w % grid[0] === 0 && h % grid[1] === 0 ? grid : [w, h];
  const out = new PNG({ width: w * 2, height: h * 2 });
  for (let y = 0; y < h; y += ch) for (let x = 0; x < w; x += cw) {
    smoothCell(cut(png.data, w, x, y, cw, ch), cw, ch, out.data, w * 2, x * 2, y * 2);
  }
  return PNG.sync.write(out);
}

// Points the file at the HD importer, keeping its uid so scenes still resolve.
// Godot rewrites the .import of files it opens before the plugin is loaded,
// so this runs for every HD file, processed or not.
function retarget(file) {
  const imp = file + '.import';
  let uid = '';
  if (fs.existsSync(imp)) {
    const text = fs.readFileSync(imp, 'utf8');
    if (/^importer="laby\.hd_texture"/m.test(text) && /^type="Texture2D"/m.test(text)) return false;
    const m = text.match(/^uid="([^"]+)"/m);
    if (m) uid = m[1];
  }
  const lines = ['[remap]', '', 'importer="laby.hd_texture"', 'type="Texture2D"'];
  if (uid) lines.push(`uid="${uid}"`);
  fs.writeFileSync(imp, lines.join('\n') + '\n');
  return true;
}

const manifest = fs.existsSync(MANIFEST) ? JSON.parse(fs.readFileSync(MANIFEST, 'utf8')) : {};
let done = 0, skipped = 0, retargeted = 0;
for (const file of walk(ASSETS).sort()) {
  const rel = path.relative(ROOT, file).split(path.sep).join('/');
  if (KEEP.has(rel)) { delete manifest[rel]; continue; }
  const bytes = fs.readFileSync(file);
  if (manifest[rel] === sha1(bytes)) {
    skipped++;
  } else {
    const hd = smooth(PNG.sync.read(bytes), gridOf(rel));
    fs.writeFileSync(file, hd);
    manifest[rel] = sha1(hd);
    done++;
  }
  if (retarget(file)) retargeted++;
}
const sorted = Object.fromEntries(Object.keys(manifest).sort().map((k) => [k, manifest[k]]));
fs.writeFileSync(MANIFEST, JSON.stringify(sorted, null, 1) + '\n');
console.log(`Smoothed ${done} file(s), ${skipped} already HD, ${retargeted} import file(s) updated.`);
