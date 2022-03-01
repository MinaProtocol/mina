let fs = require("fs");
let path = require("path");

let dir = path.dirname(__filename);
let wasmPath = path.resolve(
  dir,
  "../../../../_build/default/src/lib/crypto/kimchi_bindings/js/node_js"
);
let snarkyPath = path.resolve(
  dir,
  "../../../../_build/default/src/lib/snarky_js_bindings/snarky_js_node.bc.js"
);

// set up node_modules
if (!fs.existsSync("node_modules")) {
  fs.mkdirSync("node_modules");
  fs.mkdirSync("node_modules/env");
  fs.writeFileSync("node_modules/env/index.js", "module.exports = {};");
  fs.mkdirSync("node_modules/snarkyjs");
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
    fs.cpSync(`${wasmPath}/${file}`, `node_modules/snarkyjs/${file}`);
  });

let snarkyjs = require("snarkyjs");

module.exports = snarkyjs;
