/* global caml_js_to_bool, caml_jsstring_of_string, caml_string_of_jsstring,
   caml_bytes_of_uint8array, caml_bytes_to_uint8array,
   caml_bigint_of_bytes, caml_bigint_to_bytes, BigInt_, _1n
*/

// Provides: caml_bigint_256_of_bytes
// Requires: caml_bytes_to_uint8array, caml_bigint_of_bytes
function caml_bigint_256_of_bytes(ocaml_bytes) {
  var bytes = caml_bytes_to_uint8array(ocaml_bytes);
  return [caml_bigint_of_bytes(bytes)];
}

// Provides: caml_bigint_256_of_decimal_string
// Requires: BigInt_, caml_jsstring_of_string
function caml_bigint_256_of_decimal_string(s) {
  return [BigInt_(caml_jsstring_of_string(s))];
}

// Provides: caml_bigint_256_to_bytes
// Requires: caml_bigint_to_bytes, caml_bytes_of_uint8array
function caml_bigint_256_to_bytes(x) {
  var bytes = caml_bigint_to_bytes(x[0], 32);
  return caml_bytes_of_uint8array(bytes);
}

// Provides: caml_bigint_256_to_string
// Requires: caml_string_of_jsstring
function caml_bigint_256_to_string(x) {
  return caml_string_of_jsstring(x[0].toString());
}

// Provides: caml_bigint_256_test_bit
// Requires: _1n, BigInt_, caml_js_to_bool
function caml_bigint_256_test_bit(b, i) {
  var is_set = !!(b[0] & (_1n << BigInt_(i)));
  return caml_js_to_bool(Number(is_set));
}

// Provides: caml_bigint_256_compare
function caml_bigint_256_compare(x, y) {
  x = x[0], y = y[0];
  if (x < y) return -1;
  if (x === y) return 0;
  return 1;
}

// Provides: caml_bigint_256_num_limbs
function caml_bigint_256_num_limbs() {
  return 4;
}
// Provides: caml_bigint_256_bytes_per_limb
function caml_bigint_256_bytes_per_limb() {
  return 8;
}
