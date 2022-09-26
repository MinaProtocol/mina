/* eslint-env node */
let fs = require("fs");
let path = require("path");
let childProcess = require("child_process");

let dir = path.dirname(__filename);
let resolve = (file) => path.resolve(dir, file);
let build = "../../../../_build/default";
let wasmPath = resolve(`${build}/src/lib/crypto/kimchi_bindings/js/node_js`);
let clientSdkPath = resolve(`${build}/src/app/client_sdk/client_sdk.bc.js`);

// set up node_modules
let nodeModules = "node_modules";
let nodeModulesExists = fs.existsSync(nodeModules);
if (!nodeModulesExists) {
  fs.mkdirSync(nodeModules);
}
if (!nodeModulesExists || !fs.existsSync(`${nodeModules}/client_sdk`)) {
  fs.mkdirSync(`${nodeModules}/client_sdk`);
}
if (!nodeModulesExists || !fs.existsSync(`${nodeModules}/env`)) {
  fs.mkdirSync(`${nodeModules}/env`);
}
if (!nodeModulesExists || !fs.existsSync(`${nodeModules}/env/index.js`)) {
  fs.writeFileSync(`${nodeModules}/env/index.js`, "module.exports = {};");
}

function copy(source, target) {
  if (fs.existsSync(target)) fs.unlinkSync(target);
  return childProcess.execSync(`cp -R ${source} ${target}`);
}

// copy over js artifacts
try {
  copy(clientSdkPath, `${nodeModules}/client_sdk/index.js`);
} catch (err) {
  console.log(
    "Error: Cannot find client_sdk.bc.js. Did you forget to run `dune build`?"
  );
  console.log(err);
  throw err;
}
fs.readdirSync(wasmPath)
  .filter((f) => f.startsWith("plonk_wasm"))
  .forEach((file) => {
    copy(`${wasmPath}/${file}`, `${nodeModules}/client_sdk/${file}`);
  });

let clientSDK = require("client_sdk");

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
