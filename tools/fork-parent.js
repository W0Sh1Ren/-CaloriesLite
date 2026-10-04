const { fork, spawn } = require("child_process");
const path = require("path");
const childPath = path.join(__dirname, "fork-child.js");
console.log("--- testing fork (piped stdio + IPC) ---");
try {
  const c = fork(childPath, ["a", "b"], { env: process.env });
  let got = false;
  c.stdout.on("data", (d) => { got = true; console.log("fork stdout:", d.toString().trim()); });
  c.stderr.on("data", (d) => { console.log("fork stderr:", d.toString().trim()); });
  c.on("error", (e) => { console.log("fork ERROR:", e.code, e.message); process.exit(0); });
  c.on("exit", (code) => { console.log("fork exit code:", code, "captured:", got); process.exit(0); });
  setTimeout(() => { console.log("fork timeout (no exit)"); process.exit(0); }, 8000);
} catch (e) {
  console.log("fork THREW:", e.code, e.message);
  process.exit(0);
}
