const fs = require("fs");
const path = require("path");
const p = "D:\\CaloriesApp\\tools\\.hvigorhome\\project_caches\\221398b964fd65e34029bf0bd41e3e16\\workspace\\node_modules\\@ohos\\hvigor\\bin\\hvigor.js";
console.log("existsSync      :", fs.existsSync(p));
console.log("lstatSync       :", (() => { try { return fs.lstatSync(p).isFile(); } catch (e) { return "ERR " + e.code; } })());
console.log("realpathSync    :", (() => { try { return fs.realpathSync(p); } catch (e) { return "ERR " + e.code + " " + e.message; } })());
console.log("statSync        :", (() => { try { return fs.statSync(p).size; } catch (e) { return "ERR " + e.code; } })());
console.log("readFileSync ok :", (() => { try { return fs.readFileSync(p).length; } catch (e) { return "ERR " + e.code; } })());
