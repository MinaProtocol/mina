/* global plonk_wasm, tsRustConversionNative */


// Provides: caml_pasta_fq_plonk_verifier_index_shifts
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_verifier_index_shifts = function (log2_size) {
  console.log("log2_size", log2_size);
  try {
    var shifts = plonk_wasm.caml_pasta_fq_plonk_verifier_index_shifts(log2_size);
    console.log("shifts", shifts);
    console.log("shiftsFromRust", tsRustConversionNative.fq.shiftsFromRust(
      shifts
    ))
    return tsRustConversionNative.fq.shiftsFromRust(
      shifts
    );
  } catch (e) {
    console.error("Error calling caml_pasta_fq_plonk_verifier_index_shifts:", e);
    throw e;
  }
};

// Provides: caml_pasta_fp_plonk_verifier_index_shifts
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_verifier_index_shifts = function (log2_size) {
  return tsRustConversionNative.fp.shiftsFromRust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_shifts(log2_size)
  );
};
