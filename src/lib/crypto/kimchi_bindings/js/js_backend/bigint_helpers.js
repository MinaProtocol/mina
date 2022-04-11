/* global joo_global_object, caml_create_bytes, caml_bytes_unsafe_set, caml_bytes_unsafe_get, caml_ml_bytes_length
*/

// Provides: BigInt_
var BigInt_ = joo_global_object.BigInt;
// Provides: Uint8Array_
var Uint8Array_ = joo_global_object.Uint8Array;
// Provides: _0n
var _0n = joo_global_object.BigInt(0);
// Provides: _1n
var _1n = joo_global_object.BigInt(1);
// Provides: _2n
var _2n = joo_global_object.BigInt(2);
// Provides: _8n
var _8n = joo_global_object.BigInt(8);
// Provides: _32n
var _32n = joo_global_object.BigInt(32);

// Provides: caml_bigint_to_bytes
// Requires: BigInt_, Uint8Array_, _8n
function caml_bigint_to_bytes(x, length) {
  var bytes = [];
  for (; x > 0; x >>= _8n) {
    bytes.push(Number(x & BigInt_(0xff)));
  }
  var array = new Uint8Array_(bytes);
  if (length === undefined) return array;
  if (array.length > length)
    throw Error("bigint doesn't fit into" + length + " bytes.");
  var sizedArray = new Uint8Array_(length);
  sizedArray.set(array);
  return sizedArray;
}

// Provides: caml_bigint_of_bytes
// Requires: BigInt_, _0n, _8n
function caml_bigint_of_bytes(bytes) {
  var x = _0n;
  var bitPosition = _0n;
  for (var i = 0; i < bytes.length; i++) {
    x += BigInt_(bytes[i]) << bitPosition;
    bitPosition += _8n;
  }
  return x;
}

// Provides: caml_bytes_of_uint8array
// Requires: caml_create_bytes, caml_bytes_unsafe_set
var caml_bytes_of_uint8array = function(uint8array) {
  var length = uint8array.length;
  var ocaml_bytes = caml_create_bytes(length);
  for (var i = 0; i < length; i++) {
    // No need to convert here: OCaml Char.t is just an int under the hood.
    caml_bytes_unsafe_set(ocaml_bytes, i, uint8array[i]);
  }
  return ocaml_bytes;
};

// Provides: caml_bytes_to_uint8array
// Requires: caml_ml_bytes_length, caml_bytes_unsafe_get
var caml_bytes_to_uint8array = function(ocaml_bytes) {
  var length = caml_ml_bytes_length(ocaml_bytes);
  var bytes = new joo_global_object.Uint8Array(length);
  for (var i = 0; i < length; i++) {
    // No need to convert here: OCaml Char.t is just an int under the hood.
    bytes[i] = caml_bytes_unsafe_get(ocaml_bytes, i);
  }
  return bytes;
};
