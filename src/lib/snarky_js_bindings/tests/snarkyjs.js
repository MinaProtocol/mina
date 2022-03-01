/* eslint-env node */
let fs = require("fs");
let path = require("path");

let dir = path.dirname(__filename);
let resolve = (file) => path.resolve(dir, file);
let build = "../../../../_build/default";
let wasmPath = resolve(`${build}/src/lib/crypto/kimchi_bindings/js/node_js`);
let snarkyPath = resolve(
  `${build}/src/lib/snarky_js_bindings/snarky_js_node.bc.js`
);
let nodeModules = resolve("node_modules");

// set up node_modules
if (!fs.existsSync(nodeModules)) {
  fs.mkdirSync(nodeModules);
  fs.mkdirSync(`${nodeModules}/env`);
  fs.writeFileSync(`${nodeModules}/env/index.js`, "module.exports = {};");
  fs.mkdirSync(`${nodeModules}/snarkyjs`);
}
// copy over js artifacts
try {
  fs.cpSync(snarkyPath, "node_modules/snarkyjs/index.js");
} catch (err) {
  console.log(
    "Error: Cannot find snarky_js_node.bc.js. Did you forget to run `dune build`?"
  );
  process.exit(1);
}
fs.readdirSync(wasmPath)
  .filter((f) => f.startsWith("plonk_wasm"))
  .forEach((file) => {
    fs.cpSync(`${wasmPath}/${file}`, `${nodeModules}/snarkyjs/${file}`);
  });

module.exports = require("snarkyjs");
