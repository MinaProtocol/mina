/* global plonk_wasm, tsRustConversionNative
 */


// Provides: caml_pasta_fp_plonk_proof_create
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_proof_create = function (
  index,
  witness_cols,
  caml_runtime_tables,
  prev_challenges,
  prev_sgs
) {
  var w = new plonk_wasm.WasmVecVecFp(witness_cols.length - 1);
  for (var i = 1; i < witness_cols.length; i++) {
    w.push(tsRustConversionNative.fp.vectorToRust(witness_cols[i]));
  }
  witness_cols = w;
  prev_challenges = tsRustConversionNative.fp.vectorToRust(prev_challenges);
  var wasm_runtime_tables =
    tsRustConversionNative.fp.runtimeTablesToRust(caml_runtime_tables);
  prev_sgs = tsRustConversionNative.fp.pointsToRust(prev_sgs);
    /*w.push(tsRustConversion.fp.vectorToRust(witness_cols[i]));
  }
  witness_cols = w;
  prev_challenges = tsRustConversion.fp.vectorToRust(prev_challenges);
  var wasm_runtime_tables =
    tsRustConversion.fp.runtimeTablesToRust(caml_runtime_tables);
  prev_sgs = tsRustConversion.fp.pointsToRust(prev_sgs);
  */
  var proof = plonk_wasm.caml_pasta_fp_plonk_proof_create(
    index,
    witness_cols,
    wasm_runtime_tables,
    prev_challenges,
    prev_sgs
  );
  return tsRustConversionNative.fp.proofFromRust(proof);
  /*   return tsRustConversion.fp.proofFromRust(proof); */
};

// Provides: caml_pasta_fp_plonk_proof_verify
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_proof_verify = function (index, proof) {
  index = tsRustConversionNative.fp.verifierIndexToRust(index);
  proof = tsRustConversionNative.fp.proofToRust(proof);
  return plonk_wasm.caml_pasta_fp_plonk_proof_verify(index, proof);
};

// Provides: caml_pasta_fp_plonk_proof_batch_verify
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_proof_batch_verify = function (indexes, proofs) {
  indexes = tsRustConversionNative.mapMlArrayToRustVector(
    indexes,
    tsRustConversionNative.fp.verifierIndexToRust
  );
  proofs = tsRustConversionNative.mapMlArrayToRustVector(
    proofs,
    tsRustConversionNative.fp.proofToRust
  );
  return plonk_wasm.caml_pasta_fp_plonk_proof_batch_verify(indexes, proofs);
};

// Provides: caml_pasta_fp_plonk_proof_dummy
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_proof_dummy = function () {
  return tsRustConversionNative.fp.proofFromRust(
    plonk_wasm.caml_pasta_fp_plonk_proof_dummy()
  );
};

// Provides: caml_pasta_fp_plonk_proof_deep_copy
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_proof_deep_copy = function (proof) {
  return tsRustConversionNative.fp.proofFromRust(
    plonk_wasm.caml_pasta_fp_plonk_proof_deep_copy(
      tsRustConversionNative.fp.proofToRust(proof)
    )
  );
};

// Provides: caml_pasta_fq_plonk_proof_create
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_proof_create = function (
  index,
  witness_cols,
  caml_runtime_tables,
  prev_challenges,
  prev_sgs
) {
  var w = new plonk_wasm.WasmVecVecFq(witness_cols.length - 1);
  for (var i = 1; i < witness_cols.length; i++) {
    w.push(tsRustConversionNative.fq.vectorToRust(witness_cols[i]));
  }
  witness_cols = w;
  prev_challenges = tsRustConversionNative.fq.vectorToRust(prev_challenges);
  var wasm_runtime_tables =
    tsRustConversionNative.fq.runtimeTablesToRust(caml_runtime_tables);
  prev_sgs = tsRustConversionNative.fq.pointsToRust(prev_sgs);
  var proof = plonk_wasm.caml_pasta_fq_plonk_proof_create(
    index,
    witness_cols,
    wasm_runtime_tables,
    prev_challenges,
    prev_sgs
  );
  return tsRustConversionNative.fq.proofFromRust(proof);
};

// Provides: caml_pasta_fq_plonk_proof_verify
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_proof_verify = function (index, proof) {
  index = tsRustConversionNative.fq.verifierIndexToRust(index);
  proof = tsRustConversionNative.fq.proofToRust(proof);
  return plonk_wasm.caml_pasta_fq_plonk_proof_verify(index, proof);
};

// Provides: caml_pasta_fq_plonk_proof_batch_verify
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_proof_batch_verify = function (indexes, proofs) {
  indexes = tsRustConversionNative.mapMlArrayToRustVector(
    indexes,
    tsRustConversionNatsRustConversionNativetive.fq.verifierIndexToRust
  );
  proofs = tsRustConversionNative.mapMlArrayToRustVector(
    proofs,
    tsRustConversionNative.fq.proofToRust
  );
  return plonk_wasm.caml_pasta_fq_plonk_proof_batch_verify(indexes, proofs);
};

// Provides: caml_pasta_fq_plonk_proof_dummy
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_proof_dummy = function () {
  return tsRustConversionNative.fq.proofFromRust(
    plonk_wasm.caml_pasta_fq_plonk_proof_dummy()
  );
};

// Provides: caml_pasta_fq_plonk_proof_deep_copy
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_proof_deep_copy = function (proof) {
  return tsRustConversionNative.fq.proofFromRust(
    plonk_wasm.caml_pasta_fq_plonk_proof_deep_copy(
      tsRustConversionNative.fq.proofToRust(proof)
    )
  );
};

