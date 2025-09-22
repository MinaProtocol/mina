// Provides: plonk_wasm
var plonk_wasm = require('./plonk_wasm.js');
var native = null;
try { 
    native = require('../neon/plonk_neon.node'); 
} catch (e) {
    // neon not available, try napi
    try {
      native = require('../napi/plonk_napi.neon');
    } catch (e) {
      // native not available, use wasm
    }
}

// Overwrite only the functions that are already available in native
if (native && native.caml_pasta_fp_poseidon_block_cipher) {
  plonk_wasm.caml_pasta_fp_poseidon_block_cipher = native.caml_pasta_fp_poseidon_block_cipher;
}
if (native && native.caml_pasta_fq_poseidon_block_cipher) {
  plonk_wasm.caml_pasta_fq_poseidon_block_cipher = native.caml_pasta_fq_poseidon_block_cipher;
}