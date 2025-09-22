// Provides: plonk_wasm
var plonk_wasm = require('./plonk_wasm.js');
var native = null;
try { 
    native = require('../native/plonk_neon.node'); 
} catch (e) {
    // native not available, keep WASM
}

// Overwrite only the functions that are already available in native
if (native && native.caml_pasta_fp_poseidon_block_cipher) {
  plonk_wasm.caml_pasta_fp_poseidon_block_cipher = native.caml_pasta_fp_poseidon_block_cipher;
}
if (native && native.caml_pasta_fq_poseidon_block_cipher) {
  plonk_wasm.caml_pasta_fq_poseidon_block_cipher = native.caml_pasta_fq_poseidon_block_cipher;
}