/*
 * Find a UI node by its text on the connected HarmonyOS device and click it.
 *
 * The device UI dump is UTF-8 JSON, which Windows PowerShell mangles when it
 * decodes the file, so this helper does the parsing in Node instead.
 *
 * Usage:
 *   node tools\ui.js dump                  print nodes that have text
 *   node tools\ui.js find   <text>         print bounds of the first match
 *   node tools\ui.js click  <text>         click the first match (center point)
 *
 * Requires hdc on PATH or at the default DevEco location, and a device
 * connected with USB debugging enabled.
 */

const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const HDC = 'D:\\DevEco26\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';
const REMOTE = '/data/local/tmp/ui-dump.json';

function hdc(args, opts) {
  return execFileSync(HDC, args, Object.assign({ encoding: 'buffer' }, opts || {}));
}

function fetchLayout() {
  hdc(['shell', 'uitest', 'dumpLayout', '-p', REMOTE]);
  const buf = hdc(['file', 'recv', REMOTE, path.join(os.tmpdir(), 'ui-dump.json')]);
  const local = path.join(os.tmpdir(), 'ui-dump.json');
  const txt = fs.readFileSync(local, 'utf8').replace(/^\uFEFF/, '');
  return JSON.parse(txt);
}

function flatten(node, depth, out) {
  const a = node.attributes || {};
  let bounds = null;
  const m = /^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$/.exec(a.bounds || '');
  if (m) {
    bounds = { l: +m[1], t: +m[2], r: +m[3], b: +m[4] };
  }
  out.push({
    depth,
    type: a.type || '',
    text: a.text || '',
    id: a.id || '',
    clickable: a.clickable === 'true',
    bounds,
    window: a.hostWindowId || ''
  });
  (node.children || []).forEach((c) => flatten(c, depth + 1, out));
  return out;
}

function center(b) {
  return { x: Math.round((b.l + b.r) / 2), y: Math.round((b.t + b.b) / 2) };
}

const [, , cmd, ...rest] = process.argv;
const nodes = flatten(fetchLayout(), 0, []);

if (cmd === 'dump') {
  nodes
    .filter((n) => n.text && n.bounds)
    .slice(0, 120)
    .forEach((n) => {
      const c = center(n.bounds);
      console.log(`${n.type.padEnd(10)} center=(${c.x},${c.y}) clickable=${n.clickable} text="${n.text}"`);
    });
} else if (cmd === 'find' || cmd === 'click') {
  const needle = rest.join(' ');
  const hit = nodes.find((n) => n.text === needle && n.bounds) ||
              nodes.find((n) => n.text.includes(needle) && n.bounds);
  if (!hit) {
    console.log(`not found: ${needle}`);
    process.exit(1);
  }
  const c = center(hit.bounds);
  console.log(`match: ${hit.type} bounds=[${hit.bounds.l},${hit.bounds.t}][${hit.bounds.r},${hit.bounds.b}] center=(${c.x},${c.y}) text="${hit.text}"`);
  if (cmd === 'click') {
    const out = execFileSync(HDC, ['shell', 'uitest', 'uiInput', 'click', String(c.x), String(c.y)], { encoding: 'utf8' });
    console.log(`clicked (${c.x},${c.y}): ${out.trim()}`);
  }
} else {
  console.log('usage: node tools\\ui.js dump | find <text> | click <text>');
  process.exit(1);
}
