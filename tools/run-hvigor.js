/*
 * DSH sandbox compatibility shim for the hvigor build.
 *
 * Problem
 * -------
 * The DSH Windows sandbox forbids opening named pipes, so any child process
 * created with piped stdio fails with `EPERM: spawn EPERM`. The DevEco
 * toolchain hits this in two places:
 *
 *   1) hvigorw.js hands the real build to a child process via
 *      `child_process.fork(...)`, which always uses pipes plus an IPC channel.
 *      Its try/catch then reports the generic "00308003 ENOENT: no such file
 *      ..." message, which misleadingly looks like a missing file.
 *
 *   2) The resource compiler (`CompileResource` -> restool) is invoked with
 *      piped stdio, producing "Tools execution failed. spawn EPERM".
 *
 * Running bin/hvigor.js directly instead of the wrapper is not equivalent: the
 * wrapper's setup phase (toolchain linking, ohpm wiring, project cache) is what
 * the ohos plugin needs, and without it the build fails with "00302013 The root
 * node is not yet available for build".
 *
 * Fix
 * ---
 * Keep the normal hvigor flow, but make every spawn helper retry with
 * `stdio: 'inherit'`, which needs no pipes. Output still reaches this process's
 * stdout/stderr, so the console log stays complete; only the programmatic
 * capture that hvigor does internally is given up.
 *
 * Usage
 * -----
 *     node tools\run-hvigor.js <hvigor tasks and options...>
 *
 * for example
 *
 *     node tools\run-hvigor.js assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
 */

const cp = require('child_process');
const path = require('path');

const WRAPPER = path.resolve(__dirname, 'local', 'hvigor', 'bin', 'hvigorw.js');
const NODE_EXE = process.execPath;

/** True when the failure is the sandbox refusing piped stdio. */
function isPipeDenied(err) {
  if (!err) {
    return false;
  }
  const code = err.code || '';
  const msg = `${err.message || ''}`;
  return code === 'EPERM' && /spawn/i.test(msg);
}

/** Merge stdio: 'inherit' into an options object without mutating the caller's. */
function withInherit(options) {
  const base = options ? Object.assign({}, options) : {};
  // Piped stdio is what the sandbox refuses; inherited stdio needs no pipes.
  // Inherited stdio also has no IPC channel, so any fork-style option that
  // requested one has to go.
  delete base.stdio;
  base.stdio = 'inherit';
  return base;
}

// --------------------------------------------------------------- async spawn
const originalSpawn = cp.spawn;
cp.spawn = function patchedSpawn(command, args, options) {
  const child = originalSpawn.call(cp, command, args, options);
  child.on('error', (err) => {
    if (isPipeDenied(err)) {
      originalSpawn.call(cp, command, args, withInherit(options));
    }
  });
  return child;
};

// -------------------------------------------------------------- sync spawn
const originalSpawnSync = cp.spawnSync;
cp.spawnSync = function patchedSpawnSync(command, args, options) {
  const result = originalSpawnSync.call(cp, command, args, options);
  if (result && isPipeDenied(result.error)) {
    return originalSpawnSync.call(cp, command, args, withInherit(options));
  }
  return result;
};

// --------------------------------------------------------------- exec family
const originalExecFileSync = cp.execFileSync;
cp.execFileSync = function patchedExecFileSync(file, args, options) {
  try {
    return originalExecFileSync.call(cp, file, args, options);
  } catch (err) {
    if (isPipeDenied(err)) {
      return originalExecFileSync.call(cp, file, args, withInherit(options));
    }
    throw err;
  }
};

// ---------------------------------------------------------------------- fork
const originalFork = cp.fork;
cp.fork = function patchedFork(modulePath, args, options) {
  const opts = options || {};
  const result = cp.spawnSync(NODE_EXE, [modulePath].concat(args || []), {
    cwd: opts.cwd || process.cwd(),
    env: opts.env || process.env,
    stdio: 'inherit'
  });

  if (result.error) {
    console.error('[run-hvigor] failed to launch hvigor:', result.error.message);
    process.exit(1);
  }

  // The wrapper waits for an 'exit' event; this path is synchronous, so exit
  // here with the child's real status instead.
  process.exit(result.status === null ? 1 : result.status);
};

cp.fork.original = originalFork;

require(WRAPPER);
