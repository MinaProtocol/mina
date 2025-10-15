// Provides: plonk_wasm
var plonk_wasm = require('./plonk_wasm.js');
var native = null;
try {
  native = require('../native/plonk_napi.node');
} catch (e) {
  // native not available, keep WASM
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
override('caml_pasta_fp_poseidon_block_cipher');
override('caml_pasta_fq_poseidon_block_cipher');
override('prover_to_json');
override('prover_index_fp_from_bytes');
override('prover_index_fq_from_bytes'); 
override('prover_index_fp_to_bytes');
override('prover_index_fq_to_bytes');
override('caml_pasta_fp_plonk_index_max_degree');
override('caml_pasta_fq_plonk_index_max_degree');
override('caml_pasta_fp_plonk_index_public_inputs');
override('caml_pasta_fq_plonk_index_public_inputs');
override('caml_pasta_fp_plonk_index_domain_d1_size');
override('caml_pasta_fq_plonk_index_domain_d1_size');
override('caml_pasta_fp_plonk_index_domain_d4_size');
override('caml_pasta_fq_plonk_index_domain_d4_size');
override('caml_pasta_fp_plonk_index_domain_d8_size');
override('caml_pasta_fq_plonk_index_domain_d8_size');