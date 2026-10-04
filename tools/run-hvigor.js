/**
 * hvigor launch shim (DSH sandbox).
 *
 * Why this exists
 * ---------------
 * The sandbox forbids named pipes, so any child process created with piped
 * stdio fails with "spawn EPERM". hvigor forks/spawns helpers during a build,
 * so running it directly always aborts. This shim wraps child_process spawn
 * helpers and retries with stdio: "inherit" ONLY for EPERM failures.
 *
 * Usage (called by tools/build.ps1, cwd must be the project root):
 *   node tools/run-hvigor.js <task> --mode module -p product=default ...
 */
'use strict';

const path = require('path');
const cp = require('child_process');

const TOOLS_DIR = __dirname;
const HVIGOR_CLI = path.join(TOOLS_DIR, 'local', 'hvigor', 'bin', 'hvigorw.js');

function isPiped(options) {
  if (!options) {
    return true;
  }
  const stdio = options.stdio;
  if (stdio === 'inherit' || stdio === 'ignore') {
    return false;
  }
  if (Array.isArray(stdio)) {
    return stdio.some((s) => s === 'pipe');
  }
  return true;
}

function isEperm(err) {
  if (!err) {
    return false;
  }
  return err.code === 'EPERM' || /EPERM|operation not permitted/i.test(String(err.message || ''));
}

function patchSpawn(name) {
  const original = cp[name];
  if (typeof original !== 'function') {
    return;
  }
  cp[name] = function patched(...args) {
    const optionsIndex = args.findIndex((a) => a && typeof a === 'object' && !Array.isArray(a));
    try {
      return original.apply(this, args);
    } catch (err) {
      if (!isEperm(err) || !isPiped(optionsIndex >= 0 ? args[optionsIndex] : undefined)) {
        throw err;
      }
      const opts = Object.assign({}, optionsIndex >= 0 ? args[optionsIndex] : {}, { stdio: 'inherit' });
      if (optionsIndex >= 0) {
        args[optionsIndex] = opts;
      } else {
        args.push(opts);
      }
      return original.apply(this, args);
    }
  };
}

['spawn', 'spawnSync', 'execFile', 'execFileSync', 'fork'].forEach(patchSpawn);

const args = process.argv.slice(2);

let cli;
try {
  cli = require.resolve(HVIGOR_CLI);
} catch (err) {
  process.stderr.write('[run-hvigor] cannot find hvigor CLI: ' + HVIGOR_CLI + '\n');
  process.stderr.write('[run-hvigor] run tools\\prepare-toolchain.ps1 first.\n');
  process.exit(1);
}

process.argv = [process.argv[0], cli].concat(args);

try {
  require(cli);
} catch (err) {
  process.stderr.write('[run-hvigor] failed to start hvigor: ' + (err && err.stack ? err.stack : err) + '\n');
  process.exit(1);
}