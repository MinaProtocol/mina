/* global tsBindings
*/

// Provides: caml_bigint_256_of_numeral
// Requires: tsBindings
var caml_bigint_256_of_numeral = tsBindings.caml_bigint_256_of_numeral;

// Provides: caml_bigint_256_of_decimal_string
// Requires: tsBindings
var caml_bigint_256_of_decimal_string = tsBindings.caml_bigint_256_of_decimal_string;

// Provides: caml_bigint_256_num_limbs
// Requires: tsBindings
var caml_bigint_256_num_limbs = tsBindings.caml_bigint_256_num_limbs;

// Provides: caml_bigint_256_bytes_per_limb
// Requires: tsBindings
var caml_bigint_256_bytes_per_limb = tsBindings.caml_bigint_256_bytes_per_limb;

// Provides: caml_bigint_256_div
// Requires: tsBindings
var caml_bigint_256_div = tsBindings.caml_bigint_256_div;

// Provides: caml_bigint_256_compare
// Requires: tsBindings
var caml_bigint_256_compare = tsBindings.caml_bigint_256_compare;

// Provides: caml_bigint_256_print
// Requires: tsBindings
var caml_bigint_256_print = tsBindings.caml_bigint_256_print;

// Provides: caml_bigint_256_to_string
// Requires: tsBindings
var caml_bigint_256_to_string = tsBindings.caml_bigint_256_to_string;

// Provides: caml_bigint_256_test_bit
// Requires: tsBindings
var caml_bigint_256_test_bit = tsBindings.caml_bigint_256_test_bit;

// Provides: caml_bigint_256_to_bytes
// Requires: tsBindings
var caml_bigint_256_to_bytes = tsBindings.caml_bigint_256_to_bytes;

// Provides: caml_bigint_256_of_bytes
// Requires: tsBindings
var caml_bigint_256_of_bytes = tsBindings.caml_bigint_256_of_bytes;

// Provides: caml_bigint_256_to_bytes_into
// Requires: tsBindings, caml_ba_set_1, caml_bytes_unsafe_get
function caml_bigint_256_to_bytes_into(x, buf, pos) {
  var bytes = tsBindings.caml_bigint_256_to_bytes(x);
  for (var i = 0; i < 32; i++) {
    caml_ba_set_1(buf, pos + i, caml_bytes_unsafe_get(bytes, i));
  }
  return 0;
}

// Provides: caml_bigint_256_of_bytes_from
// Requires: tsBindings, caml_ba_get_1, caml_create_bytes, caml_bytes_unsafe_set
function caml_bigint_256_of_bytes_from(buf, pos) {
  var bytes = caml_create_bytes(32);
  for (var i = 0; i < 32; i++) {
    caml_bytes_unsafe_set(bytes, i, caml_ba_get_1(buf, pos + i));
  }
  return tsBindings.caml_bigint_256_of_bytes(bytes);
}

// Provides: caml_bigint_256_deep_copy
// Requires: tsBindings
var caml_bigint_256_deep_copy = tsBindings.caml_bigint_256_deep_copy
