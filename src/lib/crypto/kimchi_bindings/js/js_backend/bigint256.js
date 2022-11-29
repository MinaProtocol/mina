/* global joo_global_object, caml_js_to_bool, caml_jsstring_of_string, caml_string_of_jsstring,
   caml_ml_bytes_length, caml_bytes_unsafe_get, caml_create_bytes, caml_bytes_unsafe_set
*/

// Provides: BigInt_
var BigInt_ = joo_global_object.BigInt;
// Provides: Uint8Array_
var Uint8Array_ = joo_global_object.Uint8Array;

// Provides: caml_bigint_of_bytes
// Requires: BigInt_
function caml_bigint_of_bytes(bytes) {
  var x = BigInt_(0);
  var bitPosition = BigInt_(0);
  for (var i = 0; i < bytes.length; i++) {
    x += BigInt_(bytes[i]) << bitPosition;
    bitPosition += BigInt_(8);
  }
  return x;
}

// Provides: caml_bigint_256_of_decimal_string
// Requires: BigInt_, caml_jsstring_of_string
function caml_bigint_256_of_decimal_string(s) {
  return [BigInt_(caml_jsstring_of_string(s))];
}

// Provides: caml_bigint_256_of_bytes
// Requires: Uint8Array_, caml_ml_bytes_length, caml_bytes_unsafe_get, BigInt_
function caml_bigint_256_of_bytes(ocamlBytes) {
  var length = caml_ml_bytes_length(ocamlBytes);
  if (length > 32) throw Error(length + " bytes don't fit into bigint256");
  var x = BigInt_(0);
  var bitPosition = BigInt_(0);
  for (var i = 0; i < length; i++) {
    var byte = caml_bytes_unsafe_get(ocamlBytes, i);
    x += BigInt_(byte) << bitPosition;
    bitPosition += BigInt_(8);
  }
  return [x];
}

// Provides: caml_bigint_256_to_bytes
// Requires: caml_create_bytes, BigInt_, caml_bytes_unsafe_set, Uint8Array_, BigInt_
function caml_bigint_256_to_bytes(x) {
  x = x[0];
  var ocamlBytes = caml_create_bytes(32);
  for (var i = 0; x > 0; x >>= BigInt_(8), i++) {
    if (i >= 32)
      throw Error("bigint256 doesn't fit into 32 bytes.");
    var byte = Number(x & BigInt_(0xff));
    caml_bytes_unsafe_set(ocamlBytes, i, byte);
  }
  return ocamlBytes;
}

// Provides: caml_bigint_256_to_string
// Requires: caml_string_of_jsstring
function caml_bigint_256_to_string(x) {
  return caml_string_of_jsstring(x[0].toString());
}

// Provides: caml_bigint_256_test_bit
// Requires: BigInt_, caml_js_to_bool
function caml_bigint_256_test_bit(b, i) {
  var is_set = !!(b[0] & (BigInt_(1) << BigInt_(i)));
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
