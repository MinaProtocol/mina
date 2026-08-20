/* global kimchi_ffi, caml_string_of_jsstring */

// The `fp/fq_linearization_tokens` externals
// (Kimchi_bindings.Protocol.Linearization). The Rust side returns the token
// streams as one JSON string in which every variant already carries its
// js_of_ocaml tag (see `kimchi/src/linearization_tokens.rs` in
// proof-systems); here we only convert strings to OCaml strings and add the
// array/tuple framing for the OCaml result type
// `polish_token array * (string * polish_token array) array`.

// Provides: caml_decode_linearization_tokens
// Requires: caml_string_of_jsstring
var caml_decode_linearization_tokens = function (json) {
  var decoded = JSON.parse(json);
  // A token is either an integer (constant constructor) or a block
  // `[tag, arg, ...]`. Nested enum arguments arrive pre-encoded and contain
  // no strings; only the `Literal` hex string needs converting.
  function token(t) {
    if (typeof t === 'number') return t;
    var block = [t[0]];
    for (var i = 1; i < t.length; i++) {
      var arg = t[i];
      block.push(typeof arg === 'string' ? caml_string_of_jsstring(arg) : arg);
    }
    return block;
  }
  // OCaml arrays are blocks with tag 0.
  function tokens(list) {
    var arr = [0];
    for (var i = 0; i < list.length; i++) arr.push(token(list[i]));
    return arr;
  }
  var constant = tokens(decoded[0]);
  var indexTerms = [0];
  for (var i = 0; i < decoded[1].length; i++) {
    var pair = decoded[1][i];
    indexTerms.push([0, caml_string_of_jsstring(pair[0]), tokens(pair[1])]);
  }
  return [0, constant, indexTerms];
};

// Provides: fp_linearization_tokens
// Requires: kimchi_ffi, caml_decode_linearization_tokens
var fp_linearization_tokens = function () {
  return caml_decode_linearization_tokens(kimchi_ffi.fp_linearization_tokens());
};

// Provides: fq_linearization_tokens
// Requires: kimchi_ffi, caml_decode_linearization_tokens
var fq_linearization_tokens = function () {
  return caml_decode_linearization_tokens(kimchi_ffi.fq_linearization_tokens());
};
