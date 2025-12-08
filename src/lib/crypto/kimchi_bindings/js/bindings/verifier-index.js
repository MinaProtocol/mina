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