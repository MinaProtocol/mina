/* global plonk_wasm, tsRustConversionNative,*/

// Provides: caml_pasta_fq_plonk_proof_create
// Requires: plonk_napi, tsRustConversionNative
var caml_pasta_fq_plonk_proof_create = function (
  index,
  witness_cols,
  caml_runtime_tables,
  prev_challenges,
  prev_sgs
) {
  console.log("overriding wasm caml_pasta_fq_plonk_proof_create with native")
  
  var proof = plonk_napi.caml_pasta_fq_plonk_proof_create(
    index,
    witness_cols,
    caml_runtime_tables,
    prev_challenges,
    prev_sgs
  );

  return tsRustConversion.fq.proofFromRust(proof);
};