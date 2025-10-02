// Provides: plonk_wasm
var plonk_wasm = require('./plonk_wasm.js');
var native = null;
try {
  native = require('../native/plonk_napi.node');
} catch (e) {
  // native not available, keep WASM
}

if (native) {
  plonk_wasm.__native_backend = true;
  if (typeof globalThis !== 'undefined') {
    globalThis.__native_backend = true;
  }
}

function snakeToCamel(name) {
  return name.replace(/_([a-z])/g, function (_match, ch) {
    return ch.toUpperCase();
  });
}

function override(functionName) {
  if (!native) return;
  var camel = snakeToCamel(functionName);
  var impl = native[functionName] || native[camel];
  if (typeof impl === 'function') {
    plonk_wasm[functionName] = impl;
  }
}

// Overwrite only the functions that are already available in native
[
  'caml_pasta_fp_poseidon_block_cipher', // Poseidon
  'caml_pasta_fq_poseidon_block_cipher', // Poseidon 
  //'WasmFpPolyComm', // PolyComm
  //'WasmFqPolyComm', // PolyComm
 // 'WasmGPallas', // Group
  //'WasmGVesta', // Group
 // 'WasmVecVecFp', // Vector
  //'WasmVecVecFq', // Vector
].forEach(override);
