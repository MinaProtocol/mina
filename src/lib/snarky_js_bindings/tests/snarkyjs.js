/* eslint-env node */
let fs = require("fs");
let path = require("path");
let childProcess = require("child_process");

let dir = path.dirname(__filename);
let resolve = (file) => path.resolve(dir, file);
let build = "../../../../_build/default";
let wasmPath = resolve(`${build}/src/lib/crypto/kimchi_bindings/js/node_js`);
let snarkyPath = resolve(
  `${build}/src/lib/snarky_js_bindings/snarky_js_node.bc.js`
);
let nodeModules = "node_modules";
let nodeModulesExists = fs.existsSync(nodeModules);

// set up node_modules
if (!nodeModulesExists) {
  fs.mkdirSync(nodeModules);
  fs.mkdirSync(`${nodeModules}/env`);
  fs.writeFileSync(`${nodeModules}/env/index.js`, "module.exports = {};");
  fs.mkdirSync(`${nodeModules}/snarkyjs`);
}

function copy(source, target) {
  return childProcess.execSync(`cp -R ${source} ${target}`);
}

// copy over js artifacts
try {
  copy(snarkyPath, `${nodeModules}/snarkyjs/index.js`);
} catch (err) {
  console.log(
    "Error: Cannot find snarky_js_node.bc.js. Did you forget to run `dune build`?"
  );
  console.log(err);
  throw err;
}
fs.readdirSync(wasmPath)
  .filter((f) => f.startsWith("plonk_wasm"))
  .forEach((file) => {
    copy(`${wasmPath}/${file}`, `${nodeModules}/snarkyjs/${file}`);
  });

let snarkyjs = require("snarkyjs");
if (!nodeModulesExists) fs.rmSync(nodeModules, { recursive: true });

let didShutdown = false;

module.exports = {
  ...snarkyjs,

  shutdown() {
    if (global.wasm_rayon_poolbuilder && !didShutdown) {
      didShutdown = true;
      global.wasm_rayon_poolbuilder.free();
      return Promise.all(
        global.wasm_workers.map(async (worker) => {
          await worker.terminate();
        })
      );
    }
  },
};
