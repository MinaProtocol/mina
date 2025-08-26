/* global plonk_wasm, caml_jsstring_of_string, tsRustConversion
 */

// Provides: caml_opt_of_rust
var caml_opt_of_rust = function (value, value_of_rust) {
  if (value === undefined) {
    return 0;
  } else {
    return [0, value_of_rust(value)];
  }
};

// Provides: caml_opt_to_rust
var caml_opt_to_rust = function (caml_optional_value, to_rust) {
  // to_rust expects the parameters of the variant. A `Some vx` is represented
  // as [0, vx]
  if (caml_optional_value === 0) {
    return undefined;
  } else {
    return to_rust(caml_optional_value[1]);
  }
};

// Provides: caml_pasta_fp_plonk_verifier_index_create
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_verifier_index_create = function (x) {
  var vk = plonk_wasm.caml_pasta_fp_plonk_verifier_index_create(x);
  return tsRustConversion.fp.verifierIndexFromRust(vk);
};

// Provides: caml_pasta_fp_plonk_verifier_index_read
// Requires: plonk_wasm, caml_jsstring_of_string, tsRustConversion
var caml_pasta_fp_plonk_verifier_index_read = function (offset, urs, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return tsRustConversion.fp.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_read(
      offset,
      urs,
      caml_jsstring_of_string(path)
    )
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_write
// Requires: plonk_wasm, caml_jsstring_of_string, tsRustConversion
var caml_pasta_fp_plonk_verifier_index_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_pasta_fp_plonk_verifier_index_write(
    append,
    tsRustConversion.fp.verifierIndexToRust(t),
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_shifts
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_verifier_index_shifts = function (log2_size) {
  return tsRustConversion.fp.shiftsFromRust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_shifts(log2_size)
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_dummy
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_verifier_index_dummy = function () {
  var res = plonk_wasm.caml_pasta_fp_plonk_verifier_index_dummy();
  return tsRustConversion.fp.verifierIndexFromRust(res);
};

// Provides: caml_pasta_fp_plonk_verifier_index_deep_copy
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_verifier_index_deep_copy = function (x) {
  return tsRustConversion.fp.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_deep_copy(
      tsRustConversion.fp.verifierIndexToRust(x)
    )
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_create
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_verifier_index_create = function (x) {
  return tsRustConversion.fq.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_create(x)
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_read
// Requires: plonk_wasm, caml_jsstring_of_string, tsRustConversion
var caml_pasta_fq_plonk_verifier_index_read = function (offset, urs, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return tsRustConversion.fq.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_read(
      offset,
      urs,
      caml_jsstring_of_string(path)
    )
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_write
// Requires: plonk_wasm, caml_jsstring_of_string, tsRustConversion
var caml_pasta_fq_plonk_verifier_index_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_pasta_fq_plonk_verifier_index_write(
    append,
    tsRustConversion.fq.verifierIndexToRust(t),
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_shifts
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_verifier_index_shifts = function (log2_size) {
  return tsRustConversion.fq.shiftsFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_shifts(log2_size)
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_dummy
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_verifier_index_dummy = function () {
  return tsRustConversion.fq.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_dummy()
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_deep_copy
// Requires: plonk_wasm, tsRustConversion, tsRustConversion
var caml_pasta_fq_plonk_verifier_index_deep_copy = function (x) {
  return tsRustConversion.fq.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_deep_copy(
      tsRustConversion.fq.verifierIndexToRust(x)
    )
  );
};
