// Provides: plonk_wasm
var plonk_wasm = require('./plonk_wasm.js');
var native = null;
try { 
    native = require('../native/plonk_napi.node'); 
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

// gate vector example
if (native && native.caml_pasta_fp_plonk_gate_vector_create) {
    plonk_wasm.caml_pasta_fp_plonk_gate_vector_create = native.caml_pasta_fp_plonk_gate_vector_create;
    }
if (native && native.caml_pasta_fp_plonk_gate_vector_add) {
    plonk_wasm.caml_pasta_fp_plonk_gate_vector_add = native.caml_pasta_fp_plonk_gate_vector_add;
    }