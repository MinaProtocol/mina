/* global plonk_wasm, caml_jsstring_of_string
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
// Requires: plonk_intf
var caml_pasta_fp_plonk_verifier_index_create = plonk_intf.caml_pasta_fp_plonk_verifier_index_create;

// Provides: caml_pasta_fp_plonk_verifier_index_read
// Requires: plonk_intf
var caml_pasta_fp_plonk_verifier_index_read = plonk_intf.caml_pasta_fp_plonk_verifier_index_read;

// Provides: caml_pasta_fp_plonk_verifier_index_write
// Requires: plonk_intf
var caml_pasta_fp_plonk_verifier_index_write = plonk_intf.caml_pasta_fp_plonk_verifier_index_write;

// Provides: caml_pasta_fp_plonk_verifier_index_shifts
// Requires: plonk_intf
var caml_pasta_fp_plonk_verifier_index_shifts = plonk_intf.caml_pasta_fp_plonk_verifier_index_shifts;

// Provides: caml_pasta_fp_plonk_verifier_index_dummy
// Requires: plonk_intf
var caml_pasta_fp_plonk_verifier_index_dummy = plonk_intf.caml_pasta_fp_plonk_verifier_index_dummy;

// Provides: caml_pasta_fp_plonk_verifier_index_deep_copy
// Requires: plonk_intf
var caml_pasta_fp_plonk_verifier_index_deep_copy = plonk_intf.caml_pasta_fp_plonk_verifier_index_deep_copy;

// Provides: caml_pasta_fq_plonk_verifier_index_create
// Requires: plonk_intf
var caml_pasta_fq_plonk_verifier_index_create = plonk_intf.caml_pasta_fq_plonk_verifier_index_create;

// Provides: caml_pasta_fq_plonk_verifier_index_read
// Requires: plonk_intf
var caml_pasta_fq_plonk_verifier_index_read = plonk_intf.caml_pasta_fq_plonk_verifier_index_read;

// Provides: caml_pasta_fq_plonk_verifier_index_write
// Requires: plonk_intf
var caml_pasta_fq_plonk_verifier_index_write = plonk_intf.caml_pasta_fq_plonk_verifier_index_write;

// Provides: caml_pasta_fq_plonk_verifier_index_shifts
// Requires: plonk_intf
var caml_pasta_fq_plonk_verifier_index_shifts = plonk_intf.caml_pasta_fq_plonk_verifier_index_shifts;

// Provides: caml_pasta_fq_plonk_verifier_index_dummy
// Requires: plonk_intf
var caml_pasta_fq_plonk_verifier_index_dummy = plonk_intf.caml_pasta_fq_plonk_verifier_index_dummy;

// Provides: caml_pasta_fq_plonk_verifier_index_deep_copy
// Requires: plonk_intf
var caml_pasta_fq_plonk_verifier_index_deep_copy = plonk_intf.caml_pasta_fq_plonk_verifier_index_deep_copy;
