/* global plonk_wasm, tsRustConversionNative */

// Provides: caml_pasta_fp_plonk_verifier_index_create
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_verifier_index_create = function (x) {
  console.log("jsoo caml_pasta_fp_plonk_verifier_index_create x", x);
  var vk = plonk_wasm.caml_pasta_fp_plonk_verifier_index_create(x);
  console.log("vk", vk)
  return tsRustConversionNative.fp.verifierIndexFromRust(vk);
};

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

// Provides: caml_pasta_fp_plonk_verifier_index_read
// Requires: plonk_wasm, caml_jsstring_of_string, tsRustConversionNative
var caml_pasta_fp_plonk_verifier_index_read = function (offset, urs, path) {
  console.log("caml_pasta_fp_plonk_verifier_index_read")

  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return tsRustConversionNative.fp.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_read(
      offset,
      urs,
      caml_jsstring_of_string(path)
    )
  );
};

// Provides: caml_pasta_fp_plonk_verifier_index_write
// Requires: plonk_wasm, caml_jsstring_of_string, tsRustConversionNative
var caml_pasta_fp_plonk_verifier_index_write = function (append, t, path) {
  console.log("caml_pasta_fp_plonk_verifier_index_write")

  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_pasta_fp_plonk_verifier_index_write(
    append,
    tsRustConversionNative.fp.verifierIndexToRust(t),
    caml_jsstring_of_string(path)
  );
};


// Provides: caml_pasta_fp_plonk_verifier_index_dummy
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_verifier_index_dummy = function () {
  console.log("caml_pasta_fp_plonk_verifier_index_dummy")

  var res = plonk_wasm.caml_pasta_fp_plonk_verifier_index_dummy();
  return tsRustConversionNative.fp.verifierIndexFromRust(res);
};

// Provides: caml_pasta_fp_plonk_verifier_index_deep_copy
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_verifier_index_deep_copy = function (x) {
  console.log("caml_pasta_fp_plonk_verifier_index_deep_copy")
  return tsRustConversionNative.fp.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_deep_copy(
      tsRustConversionNative.fp.verifierIndexToRust(x)
    )
  );
};


// Provides: caml_pasta_fq_plonk_verifier_index_create
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_verifier_index_create = function (x) {
  console.log("caml_pasta_fq_plonk_verifier_index_create")
  return tsRustConversionNative.fq.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_create(x)
  );
};


// Provides: caml_pasta_fp_plonk_verifier_index_shifts
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_verifier_index_shifts = function (log2_size) {
  return tsRustConversionNative.fp.shiftsFromRust(
    plonk_wasm.caml_pasta_fp_plonk_verifier_index_shifts(log2_size)
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_read
// Requires: plonk_wasm, caml_jsstring_of_string, tsRustConversionNative
var caml_pasta_fq_plonk_verifier_index_read = function (offset, urs, path) {
  console.log("caml_pasta_fq_plonk_verifier_index_read")
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return tsRustConversionNative.fq.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_read(
      offset,
      urs,
      caml_jsstring_of_string(path)
    )
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_write
// Requires: plonk_wasm, caml_jsstring_of_string, tsRustConversionNative
var caml_pasta_fq_plonk_verifier_index_write = function (append, t, path) {
  console.log("caml_pasta_fq_plonk_verifier_index_write")
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_pasta_fq_plonk_verifier_index_write(
    append,
    tsRustConversionNative.fq.verifierIndexToRust(t),
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_dummy
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_verifier_index_dummy = function () {
  console.log("caml_pasta_fq_plonk_verifier_index_dummy")
  return tsRustConversionNative.fq.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_dummy()
  );
};

// Provides: caml_pasta_fq_plonk_verifier_index_deep_copy
// Requires: plonk_wasm, tsRustConversionNative, tsRustConversionNative
var caml_pasta_fq_plonk_verifier_index_deep_copy = function (x) {
  console.log("caml_pasta_fq_plonk_verifier_index_deep_copy")
  return tsRustConversionNative.fq.verifierIndexFromRust(
    plonk_wasm.caml_pasta_fq_plonk_verifier_index_deep_copy(
      tsRustConversionNative.fq.verifierIndexToRust(x)
    )
  );
};