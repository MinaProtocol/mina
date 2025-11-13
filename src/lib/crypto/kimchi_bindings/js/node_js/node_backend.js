// Provides: plonk_wasm
var plonk_wasm = (function() {
  var wasm = require('./plonk_wasm.js');

  try {
    var native =  require('@o1js/native-' + process.platform + '-' + process.arch)

    // THIS IS A RUNTIME OVERRIDE
    // YOU HAVE TO RUN IT TO SEE IF IT BREAKS
    // IT WON'T CRASH UNLESS O1JS_REQUIRE_NATIVE_BINDINGS
    // IS SET
    var overrides = [
      "prover_to_json",
      "prover_index_fp_from_bytes",
      "prover_index_fq_from_bytes",
      "prover_index_fp_to_bytes",
      "prover_index_fq_to_bytes",
      "caml_pasta_fp_poseidon_block_cipher",
      "caml_pasta_fq_poseidon_block_cipher",
      "caml_pasta_fp_plonk_verifier_index_shifts",
      "caml_pasta_fq_plonk_verifier_index_shifts",
      "WasmFpPolyComm",
      "WasmFqPolyComm",
      "caml_pasta_fp_plonk_gate_vector_create",
      "caml_pasta_fq_plonk_gate_vector_create",
      "caml_pasta_fp_plonk_gate_vector_add",
      "caml_pasta_fq_plonk_gate_vector_add",
      "caml_pasta_fp_plonk_gate_vector_get",
      "caml_pasta_fq_plonk_gate_vector_get",
      "caml_pasta_fp_plonk_gate_vector_len",
      "caml_pasta_fq_plonk_gate_vector_len",
      "caml_pasta_fp_plonk_gate_vector_wrap",
      "caml_pasta_fq_plonk_gate_vector_wrap",
      "caml_pasta_fp_plonk_gate_vector_digest",
      "caml_pasta_fq_plonk_gate_vector_digest",
      "caml_pasta_fp_plonk_gate_vector_from_bytes",
      "caml_pasta_fq_plonk_gate_vector_from_bytes",
      "caml_pasta_fp_plonk_circuit_serialize",
      "caml_pasta_fq_plonk_circuit_serialize",
      "caml_pasta_fp_plonk_index_max_degree",
      "caml_pasta_fq_plonk_index_max_degree",
      "caml_pasta_fp_plonk_index_public_inputs",
      "caml_pasta_fq_plonk_index_public_inputs",
      "caml_pasta_fp_plonk_index_domain_d1_size",
      "caml_pasta_fq_plonk_index_domain_d1_size",
      "caml_pasta_fp_plonk_index_domain_d4_size",
      "caml_pasta_fq_plonk_index_domain_d4_size",
      "caml_pasta_fp_plonk_index_domain_d8_size",
      "caml_pasta_fq_plonk_index_domain_d8_size",
      "caml_pasta_fp_plonk_index_create",
      "caml_pasta_fq_plonk_index_create",
      "caml_pasta_fp_plonk_index_decode",
      "caml_pasta_fq_plonk_index_decode",
      "caml_pasta_fp_plonk_index_encode",
      "caml_pasta_fq_plonk_index_encode",
      "caml_pasta_fp_plonk_index_read",
      "caml_pasta_fq_plonk_index_read",
      "caml_fp_srs_from_bytes",
      "caml_fq_srs_from_bytes",
      "WasmFpSrs",
      "caml_fp_srs_create",
      "caml_fp_srs_create_parallel",
      "caml_fp_srs_get",
      "caml_fp_srs_set",
      "caml_fp_srs_write",
      "caml_fp_srs_read",
      "caml_fp_srs_add_lagrange_basis",
      "caml_fp_srs_commit_evaluations",
      "caml_fp_srs_b_poly_commitment",
      "caml_fp_srs_batch_accumulator_check",
      "caml_fp_srs_batch_accumulator_generate",
      "caml_fp_srs_h",
      "WasmFqSrs",
      "caml_fq_srs_create",
      "caml_fq_srs_create_parallel",
      "caml_fq_srs_get",
      "caml_fq_srs_set",
      "caml_fq_srs_write",
      "caml_fq_srs_read",
      "caml_fq_srs_add_lagrange_basis",
      "caml_fq_srs_commit_evaluations",
      "caml_fq_srs_b_poly_commitment",
      "caml_fq_srs_batch_accumulator_check",
      "caml_fq_srs_batch_accumulator_generate",
      "caml_fq_srs_h",
      "WasmFpPolyComm",
      "WasmFqPolyComm",
      "WasmGPallas",
      "WasmGVesta",
      "WasmPastaFp",
      "WasmPastaFq",
    ];

    overrides.forEach(function (override) {
      wasm[override] = native[override]
    })
    wasm.native = true;
  } catch (e) {
    if (process.env.O1JS_REQUIRE_NATIVE_BINDINGS) {
      throw e
    }
  }
  return wasm
})()
