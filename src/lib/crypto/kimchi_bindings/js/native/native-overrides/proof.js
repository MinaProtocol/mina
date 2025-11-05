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
