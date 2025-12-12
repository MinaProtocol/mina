// Provides: plonk_wasm
var plonk_wasm = (function () {
  var wasm = require('./plonk_wasm.js');

  try {
    var native = require('@o1js/native-' + process.platform + '-' + process.arch)

    // THIS IS A RUNTIME OVERRIDE
    // YOU HAVE TO RUN IT TO SEE IF IT BREAKS
    // IT WON'T CRASH UNLESS O1JS_REQUIRE_NATIVE_BINDINGS
    // IS SET
    var overrides = [
      "prover_to_json",
      "prover_index_fp_deserialize",
      "prover_index_fq_deserialize",
      "prover_index_fp_serialize",
      "prover_index_fq_serialize",
      "WasmPastaFpPlonkIndex",
      "WasmPastaFqPlonkIndex",
      "caml_pasta_fp_poseidon_block_cipher",
      "caml_pasta_fq_poseidon_block_cipher",
      "caml_pasta_fp_plonk_proof_create",
      "WasmFpPlonkVerifierIndex",
      "WasmFqPlonkVerifierIndex",
      "WasmFpDomain",
      "WasmFqDomain",
      "WasmFpShifts",
      "WasmFqShifts",
      "WasmFpLookupSelectors",
      "WasmFqLookupSelectors",
      "WasmFpLookupVerifierIndex",
      "WasmFqLookupVerifierIndex",
      "WasmFpPlonkVerificationEvals",
      "WasmFqPlonkVerificationEvals",
      "WasmFpPlonkLookupVerifierIndex",
      "WasmFqPlonkLookupVerifierIndex",
      "caml_pasta_fp_plonk_verifier_index_create",
      "caml_pasta_fq_plonk_verifier_index_create",
      "caml_pasta_fp_plonk_verifier_index_read",
      "caml_pasta_fq_plonk_verifier_index_read",
      "caml_pasta_fp_plonk_verifier_index_write",
      "caml_pasta_fq_plonk_verifier_index_write",
      "caml_pasta_fp_plonk_verifier_index_dummy",
      "caml_pasta_fq_plonk_verifier_index_dummy",
      "caml_pasta_fp_plonk_verifier_index_serialize",
      "caml_pasta_fq_plonk_verifier_index_serialize",
      "caml_pasta_fp_plonk_verifier_index_deserialize",
      "caml_pasta_fq_plonk_verifier_index_deserialize",
      "caml_pasta_fp_plonk_verifier_index_deep_copy",
      "caml_pasta_fq_plonk_verifier_index_deep_copy",
      "caml_pasta_fp_plonk_verifier_index_shifts",
      "caml_pasta_fq_plonk_verifier_index_shifts",
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
      "caml_fp_srs_to_bytes_external",
      "caml_fq_srs_to_bytes_external",
      "caml_fp_srs_from_bytes_external",
      "caml_fq_srs_from_bytes_external",
      "caml_fp_srs_to_bytes",
      "caml_fq_srs_to_bytes",
      "WasmFpSrs",
      "caml_fp_srs_create",
      "caml_fp_srs_create_parallel",
      "caml_fp_srs_get",
      "caml_fp_srs_set",
      "caml_fp_srs_lagrange_commitment",
      "caml_fp_srs_maybe_lagrange_commitment",
      "caml_fp_srs_lagrange_commitments_whole_domain_ptr",
      "caml_fp_srs_set_lagrange_basis",
      "caml_fp_srs_get_lagrange_basis",
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
      "caml_fq_srs_lagrange_commitment",
      "caml_fq_srs_maybe_lagrange_commitment",
      "caml_fq_srs_lagrange_commitments_whole_domain_ptr",
      "caml_fq_srs_set_lagrange_basis",
      "caml_fq_srs_get_lagrange_basis",
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
      "caml_pasta_fp_plonk_proof_create",
      "caml_pasta_fp_plonk_proof_verify",
      "caml_pasta_fq_plonk_proof_create",
      "caml_pasta_fq_plonk_proof_verify",
      "fp_oracles_create",
      "fp_oracles_create_no_public",
      "fp_oracles_dummy",
      "fp_oracles_deep_copy",
      "fq_oracles_create",
      "fq_oracles_create_no_public",
      "fq_oracles_dummy",
      "fq_oracles_deep_copy",
      "WasmFpOpeningProof",
      "WasmFqOpeningProof",
      "WasmFpLookupCommitments",
      "WasmFqLookupCommitments",
      "WasmFpProverProof",
      "WasmFqProverProof",
      "WasmFpProofEvaluations",
      "WasmFqProofEvaluations",
      "WasmFpProverCommitments",
      "WasmFqProverCommitments",
      "WasmFpRuntimeTable",
      "WasmFqRuntimeTable",
    ];

    // These are constructor overrides, meant for full napi classes.
    // Otherwise, if treated as a normal override, it would return the whole
    // object itself, not an instance.
    var ctorOverrides = new Set([
      "WasmVecVecFp",
      "WasmVecVecFq",
    ]);

    overrides.forEach(function (override) {
      wasm[override] = function (x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12) {
        console.log("calling native override:", override);
        return native[override](x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12);
      }
    });
    ctorOverrides.forEach(function (override) {
      wasm[override] = function (x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12) {
        console.log("calling class native override:", override);
        return new native[override](x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12);
      }
    });
    wasm.native = true;
  } catch (e) {
    if (process.env.O1JS_REQUIRE_NATIVE_BINDINGS) {
      throw e
    }
  }
  return wasm
})()
