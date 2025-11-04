/* global plonk_wasm, tsRustConversionNative */


// Provides: caml_pasta_fq_plonk_verifier_index_shifts
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_verifier_index_shifts = function (log2_size) {
  return tsRustConversionNative.fq.shiftsFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_shifts(log2_size)
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_shifts
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_verifier_index_shifts = function (log2_size) {
  return tsRustConversionNative.fp.shiftsFromRust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_shifts(log2_size)
  );
};
