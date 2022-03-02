/* eslint-env node */
let fs = require("fs");
let path = require("path");

let dir = path.dirname(__filename);
let resolve = (file) => path.resolve(dir, file);
let build = "../../../../_build/default";
let wasmPath = resolve(`${build}/src/lib/crypto/kimchi_bindings/js/node_js`);
let clientSdkPath = resolve(`${build}/src/app/client_sdk/client_sdk.bc.js`);
let nodeModules = "node_modules";
let nodeModulesExists = fs.existsSync(nodeModules);

// set up node_modules
if (!nodeModulesExists) {
  fs.mkdirSync(nodeModules);
  fs.mkdirSync(`${nodeModules}/env`);
  fs.writeFileSync(`${nodeModules}/env/index.js`, "module.exports = {};");
  fs.mkdirSync(`${nodeModules}/client_sdk`);
}
// copy over js artifacts
try {
  fs.cpSync(clientSdkPath, "node_modules/client_sdk/index.js");
} catch (err) {
  console.log(
    "Error: Cannot find client_sdk.bc.js. Did you forget to run `dune build`?"
  );
  process.exit(1);
}
fs.readdirSync(wasmPath)
  .filter((f) => f.startsWith("plonk_wasm"))
  .forEach((file) => {
    fs.cpSync(`${wasmPath}/${file}`, `${nodeModules}/client_sdk/${file}`);
  });

let clientSDK = require("client_sdk");
if (!nodeModulesExists) fs.rmSync(nodeModules);

let didShutdown = false;

let minaSDK = {
  ...clientSDK.minaSDK,
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
module.exports = { minaSDK };
