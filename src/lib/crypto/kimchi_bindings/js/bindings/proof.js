/* global plonk_wasm, tsRustConversion
 */



// Provides: caml_pasta_fp_plonk_proof_deep_copy
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_proof_deep_copy = function (proof) {
  return tsRustConversion.fp.proofFromRust(
    plonk_wasm.caml_pasta_fp_plonk_proof_deep_copy(
      tsRustConversion.fp.proofToRust(proof)
    )
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

