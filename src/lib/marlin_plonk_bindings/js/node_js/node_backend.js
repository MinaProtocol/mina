// Provides: rayon_js_stubs_path
var rayon_js_stubs_path = "./../../../../external/wasm-bindgen-rayon/src/workerHelpers.no-modules.js";

// Provides: rayon_js_stubs
// Requires: rayon_js_stubs_path
var rayon_js_stubs = require(rayon_js_stubs_path);

// Provides: plonk_wasm
// Requires: rayon_js_stubs, rayon_js_stubs_path
var plonk_wasm = (function() {
    // Expose this globally so that it can be referenced from WASM.
    joo_global_object.startWorkers = rayon_js_stubs.startWorkers;
    var env = require("env");
    env.memory =
        rayon_js_stubs.memory ?
            rayon_js_stubs.memory :
            new joo_global_object.WebAssembly.Memory({
                initial: 18,
                maximum: 16384,
                shared: true});
    joo_global_object.startWorkers = rayon_js_stubs.startWorkers;
    var plonk_wasm = require("./plonk_wasm.js");
    // TODO: This shouldn't live here.
    // TODO: js_of_ocaml is unhappy about __filename here, but it's in the
    // global scope, yet not attached to the global object, so we can't access
    // it differently.
    if (!rayon_js_stubs.memory) {
        plonk_wasm.initThreadPool(3, __filename);
    }
    rayon_js_stubs.wasm_ready(plonk_wasm);
    return plonk_wasm;
})();
