// Provides: plonk_wasm
var plonk_wasm = require('./plonk_wasm.js');
var native = null;
try {
  native = require('../native/plonk_napi.node');
} catch (e) {
  // native not available, keep WASM
}

if (native) {
  plonk_wasm.__kimchi_napi = true;
  if (typeof globalThis !== 'undefined') {
    globalThis.__kimchi_napi = true;
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
override('caml_pasta_fp_plonk_index_create');
override('caml_pasta_fq_plonk_index_create');
override('caml_pasta_fp_plonk_gate_vector_from_bytes');
override('caml_pasta_fq_plonk_gate_vector_from_bytes');
override('caml_fp_srs_from_bytes');
override('caml_fq_srs_from_bytes');
override('caml_pasta_fp_plonk_circuit_serialize');
override('caml_pasta_fq_plonk_circuit_serialize');

override('caml_pasta_fp_plonk_index_decode')
override('caml_pasta_fq_plonk_index_decode') 
override('caml_pasta_fp_plonk_index_encode');
override('caml_pasta_fq_plonk_index_encode');
override('caml_pasta_fq_plonk_index_read');
override('caml_pasta_fp_plonk_index_read');

// GateVector 
[ 
  'caml_pasta_fp_plonk_gate_vector_create', 
  'caml_pasta_fq_plonk_gate_vector_create', 
  'caml_pasta_fp_plonk_gate_vector_add',
  'caml_pasta_fq_plonk_gate_vector_add',
  'caml_pasta_fp_plonk_gate_vector_get',
  'caml_pasta_fq_plonk_gate_vector_get',
  'caml_pasta_fp_plonk_gate_vector_len', 
  'caml_pasta_fq_plonk_gate_vector_len',
  'caml_pasta_fp_plonk_gate_vector_wrap',
  'caml_pasta_fq_plonk_gate_vector_wrap',
  'caml_pasta_fp_plonk_gate_vector_digest',
  'caml_pasta_fq_plonk_gate_vector_digest',
  'caml_pasta_fp_plonk_circuit_serialize',
  'caml_pasta_fq_plonk_circuit_serialize',
].forEach(override);

// Poly Commitment, Affine Point conversions
[
  'WasmFpPolyComm',
  'WasmFqPolyComm',
  'WasmGPallas',
  'WasmGVesta',
  'WasmPastaFp',
  'WasmPastaFq',
].forEach(override);

// SRS
[
  'WasmFpSrs',
  'caml_fp_srs_create',
  'caml_fp_srs_create_parallel',
  'caml_fq_srs_get',
  'caml_fq_srs_set',
  'caml_fp_srs_write',
  'caml_fp_srs_read',
  'caml_fp_srs_add_lagrange_basis',
  'caml_fp_srs_commit_evaluations',
  'caml_fp_srs_b_poly_commitment',
  'caml_fp_srs_batch_accumulator_check',
  'caml_fp_srs_batch_accumulator_generate',
  'caml_fp_srs_h',
  'WasmFqSrs',
  'caml_fq_srs_create',
  'caml_fq_srs_create_parallel',
  'caml_fq_srs_get',
  'caml_fq_srs_set',
  'caml_fq_srs_write',
  'caml_fq_srs_read',
  'caml_fq_srs_add_lagrange_basis',
  'caml_fq_srs_commit_evaluations',
  'caml_fq_srs_b_poly_commitment',
  'caml_fq_srs_batch_accumulator_check',
  'caml_fq_srs_batch_accumulator_generate',
  'caml_fq_srs_h',
].forEach(override);
