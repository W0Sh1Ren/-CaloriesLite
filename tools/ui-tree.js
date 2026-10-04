/*
 * Show the UI node hierarchy around a piece of text, with bounds and flags.
 * Used to work out why a control is not receiving taps.
 *
 * Usage: node tools\ui-tree.js <text>
 */
const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const HDC = 'D:\\DevEco26\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';
const REMOTE = '/data/local/tmp/ui-tree.json';
const LOCAL = path.join(os.tmpdir(), 'ui-tree.json');

execFileSync(HDC, ['shell', 'uitest', 'dumpLayout', '-p', REMOTE]);
execFileSync(HDC, ['file', 'recv', REMOTE, LOCAL]);
const root = JSON.parse(fs.readFileSync(LOCAL, 'utf8').replace(/^\uFEFF/, ''));

const needle = process.argv.slice(2).join(' ');

function boundsOf(a) {
  const m = /^\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]$/.exec(a.bounds || '');
  return m ? `[${m[1]},${m[2]}][${m[3]},${m[4]}]` : '(none)';
}

// Walk the tree keeping the ancestor chain so a match can be printed with context.
function walk(node, chain) {
  const a = node.attributes || {};
  const here = chain.concat([node]);
  if (a.text && a.text.includes(needle)) {
    console.log(`--- match: "${a.text}"`);
    here.forEach((n, i) => {
      const at = n.attributes || {};
      const pad = '  '.repeat(i);
      console.log(
        `${pad}${(at.type || '?').padEnd(12)} bounds=${boundsOf(at).padEnd(26)}` +
        ` clickable=${at.clickable} enabled=${at.enabled} hitTest=${at.hitTestBehavior}` +
        ` id=${at.id || '-'}`
      );
    });
    console.log('');
  }
  (node.children || []).forEach((c) => walk(c, here));
}

walk(root, []);
