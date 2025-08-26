/* global plonk_wasm, tsRustConversion
 */

// Provides: caml_pasta_fp_plonk_proof_create
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_proof_create = function (
  index,
  witness_cols,
  caml_runtime_tables,
  prev_challenges,
  prev_sgs
) {
  var w = new plonk_wasm.WasmVecVecFp(witness_cols.length - 1);
  for (var i = 1; i < witness_cols.length; i++) {
    w.push(tsRustConversion.fp.vectorToRust(witness_cols[i]));
  }
  witness_cols = w;
  prev_challenges = tsRustConversion.fp.vectorToRust(prev_challenges);
  var wasm_runtime_tables =
    tsRustConversion.fp.runtimeTablesToRust(caml_runtime_tables);
  prev_sgs = tsRustConversion.fp.pointsToRust(prev_sgs);
  var proof = plonk_wasm.caml_pasta_fp_plonk_proof_create(
    index,
    witness_cols,
    wasm_runtime_tables,
    prev_challenges,
    prev_sgs
  );
  return tsRustConversion.fp.proofFromRust(proof);
};

// Provides: caml_pasta_fp_plonk_proof_verify
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_proof_verify = function (index, proof) {
  index = tsRustConversion.fp.verifierIndexToRust(index);
  proof = tsRustConversion.fp.proofToRust(proof);
  return plonk_wasm.caml_pasta_fp_plonk_proof_verify(index, proof);
};

// Provides: caml_pasta_fp_plonk_proof_batch_verify
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_proof_batch_verify = function (indexes, proofs) {
  indexes = tsRustConversion.mapMlArrayToRustVector(
    indexes,
    tsRustConversion.fp.verifierIndexToRust
  );
  proofs = tsRustConversion.mapMlArrayToRustVector(
    proofs,
    tsRustConversion.fp.proofToRust
  );
  return plonk_wasm.caml_pasta_fp_plonk_proof_batch_verify(indexes, proofs);
};

// Provides: caml_pasta_fp_plonk_proof_dummy
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_proof_dummy = function () {
  return tsRustConversion.fp.proofFromRust(
    plonk_wasm.caml_pasta_fp_plonk_proof_dummy()
  );
};

// Provides: caml_pasta_fp_plonk_proof_deep_copy
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_proof_deep_copy = function (proof) {
  return tsRustConversion.fp.proofFromRust(
    plonk_wasm.caml_pasta_fp_plonk_proof_deep_copy(
      tsRustConversion.fp.proofToRust(proof)
    )
  );
};

// Provides: caml_pasta_fq_plonk_proof_create
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_proof_create = function (
  index,
  witness_cols,
  caml_runtime_tables,
  prev_challenges,
  prev_sgs
) {
  var w = new plonk_wasm.WasmVecVecFq(witness_cols.length - 1);
  for (var i = 1; i < witness_cols.length; i++) {
    w.push(tsRustConversion.fq.vectorToRust(witness_cols[i]));
  }
  witness_cols = w;
  prev_challenges = tsRustConversion.fq.vectorToRust(prev_challenges);
  var wasm_runtime_tables =
    tsRustConversion.fq.runtimeTablesToRust(caml_runtime_tables);
  prev_sgs = tsRustConversion.fq.pointsToRust(prev_sgs);
  var proof = plonk_wasm.caml_pasta_fq_plonk_proof_create(
    index,
    witness_cols,
    wasm_runtime_tables,
    prev_challenges,
    prev_sgs
  );
  return tsRustConversion.fq.proofFromRust(proof);
};

// Provides: caml_pasta_fq_plonk_proof_verify
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_proof_verify = function (index, proof) {
  index = tsRustConversion.fq.verifierIndexToRust(index);
  proof = tsRustConversion.fq.proofToRust(proof);
  return plonk_wasm.caml_pasta_fq_plonk_proof_verify(index, proof);
};

// Provides: caml_pasta_fq_plonk_proof_batch_verify
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_proof_batch_verify = function (indexes, proofs) {
  indexes = tsRustConversion.mapMlArrayToRustVector(
    indexes,
    tsRustConversion.fq.verifierIndexToRust
  );
  proofs = tsRustConversion.mapMlArrayToRustVector(
    proofs,
    tsRustConversion.fq.proofToRust
  );
  return plonk_wasm.caml_pasta_fq_plonk_proof_batch_verify(indexes, proofs);
};

// Provides: caml_pasta_fq_plonk_proof_dummy
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_proof_dummy = function () {
  return tsRustConversion.fq.proofFromRust(
    plonk_wasm.caml_pasta_fq_plonk_proof_dummy()
  );
};

// Provides: caml_pasta_fq_plonk_proof_deep_copy
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_proof_deep_copy = function (proof) {
  return tsRustConversion.fq.proofFromRust(
    plonk_wasm.caml_pasta_fq_plonk_proof_deep_copy(
      tsRustConversion.fq.proofToRust(proof)
    )
  );
};

// Provides: prover_to_json
// Requires: plonk_wasm
var prover_to_json = plonk_wasm.prover_to_json;
