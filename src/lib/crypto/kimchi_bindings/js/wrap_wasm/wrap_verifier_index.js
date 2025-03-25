// Provides: wrap_wasm_verifier_index
// Requires: caml_jsstring_of_string
function wrap_wasm_verifier_index(plonk_wasm,plonk_intf,tsRustConversion){

  plonk_intf.caml_pasta_fp_plonk_verifier_index_create = function (x) {
    var vk = plonk_wasm.caml_pasta_fp_plonk_verifier_index_create(x);
    return tsRustConversion.fp.verifierIndexFromRust(vk);
  };

  plonk_intf.caml_pasta_fp_plonk_verifier_index_read = function (offset, urs, path) {
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

  plonk_intf.caml_pasta_fp_plonk_verifier_index_write = function (append, t, path) {
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

  plonk_intf.caml_pasta_fp_plonk_verifier_index_shifts = function (log2_size) {
    return tsRustConversion.fp.shiftsFromRust(
      plonk_wasm.caml_pasta_fp_plonk_verifier_index_shifts(log2_size)
    );
  };

  plonk_intf.caml_pasta_fp_plonk_verifier_index_dummy = function () {
    var res = plonk_wasm.caml_pasta_fp_plonk_verifier_index_dummy();
    return tsRustConversion.fp.verifierIndexFromRust(res);
  };

  plonk_intf.caml_pasta_fp_plonk_verifier_index_deep_copy = function (x) {
    return tsRustConversion.fp.verifierIndexFromRust(
      plonk_wasm.caml_pasta_fp_plonk_verifier_index_deep_copy(
        tsRustConversion.fp.verifierIndexToRust(x)
      )
    );
  };

  plonk_intf.caml_pasta_fq_plonk_verifier_index_create = function (x) {
    return tsRustConversion.fq.verifierIndexFromRust(
      plonk_wasm.caml_pasta_fq_plonk_verifier_index_create(x)
    );
  };

  plonk_intf.caml_pasta_fq_plonk_verifier_index_read = function (offset, urs, path) {
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

  plonk_intf.caml_pasta_fq_plonk_verifier_index_write = function (append, t, path) {
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

  plonk_intf.caml_pasta_fq_plonk_verifier_index_shifts = function (log2_size) {
    return tsRustConversion.fq.shiftsFromRust(
      plonk_wasm.caml_pasta_fq_plonk_verifier_index_shifts(log2_size)
    );
  };

  plonk_intf.caml_pasta_fq_plonk_verifier_index_dummy = function () {
    return tsRustConversion.fq.verifierIndexFromRust(
      plonk_wasm.caml_pasta_fq_plonk_verifier_index_dummy()
    );
  };

  plonk_intf.caml_pasta_fq_plonk_verifier_index_deep_copy = function (x) {
    return tsRustConversion.fq.verifierIndexFromRust(
      plonk_wasm.caml_pasta_fq_plonk_verifier_index_deep_copy(
        tsRustConversion.fq.verifierIndexToRust(x)
      )
    );
  };
}
