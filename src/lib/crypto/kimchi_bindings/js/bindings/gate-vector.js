/* eslint-disable no-unused-vars */
/* global plonk_wasm, caml_string_of_jsstring,
    free_on_finalize, tsRustConversion, caml_bytes_of_uint8array
*/

// Provides: caml_pasta_fp_plonk_gate_vector_create
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_fp_plonk_gate_vector_create = function () {
  return free_on_finalize(plonk_wasm.caml_pasta_fp_plonk_gate_vector_create());
};

// Provides: caml_pasta_fp_plonk_gate_vector_add
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_gate_vector_add = function (v, x) {
  return plonk_wasm.caml_pasta_fp_plonk_gate_vector_add(
    v,
    tsRustConversion.fp.gateToRust(x)
  );
};

// Provides: caml_pasta_fp_plonk_gate_vector_get
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_gate_vector_get = function (v, i) {
  return tsRustConversion.fp.gateFromRust(
    plonk_wasm.caml_pasta_fp_plonk_gate_vector_get(v, i)
  );
};

// Provides: caml_pasta_fp_plonk_gate_vector_len
// Requires: plonk_wasm
var caml_pasta_fp_plonk_gate_vector_len = function (v) {
  return plonk_wasm.caml_pasta_fp_plonk_gate_vector_len(v);
};

// Provides: caml_pasta_fp_plonk_gate_vector_wrap
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_gate_vector_wrap = function (v, x, y) {
  return plonk_wasm.caml_pasta_fp_plonk_gate_vector_wrap(
    v,
    tsRustConversion.wireToRust(x),
    tsRustConversion.wireToRust(y)
  );
};

// Provides: caml_pasta_fp_plonk_gate_vector_digest
// Requires: plonk_wasm, caml_bytes_of_uint8array
var caml_pasta_fp_plonk_gate_vector_digest = function (
  public_input_size,
  gate_vector
) {
  var uint8array = plonk_wasm.caml_pasta_fp_plonk_gate_vector_digest(
    public_input_size,
    gate_vector
  );
  return caml_bytes_of_uint8array(uint8array);
};

// Provides: caml_pasta_fp_plonk_circuit_serialize
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_pasta_fp_plonk_circuit_serialize = function (
  public_input_size,
  gate_vector
) {
  return caml_string_of_jsstring(
    plonk_wasm.caml_pasta_fp_plonk_circuit_serialize(
      public_input_size,
      gate_vector
    )
  );
};

// Provides: caml_pasta_fq_plonk_gate_vector_create
// Requires: plonk_wasm, free_on_finalize
var caml_pasta_fq_plonk_gate_vector_create = function () {
  return free_on_finalize(plonk_wasm.caml_pasta_fq_plonk_gate_vector_create());
};

// Provides: caml_pasta_fq_plonk_gate_vector_add
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_gate_vector_add = function (v, x) {
  return plonk_wasm.caml_pasta_fq_plonk_gate_vector_add(
    v,
    tsRustConversion.fq.gateToRust(x)
  );
};

// Provides: caml_pasta_fq_plonk_gate_vector_get
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_gate_vector_get = function (v, i) {
  return tsRustConversion.fq.gateFromRust(
    plonk_wasm.caml_pasta_fq_plonk_gate_vector_get(v, i)
  );
};

// Provides: caml_pasta_fq_plonk_gate_vector_len
// Requires: plonk_wasm
var caml_pasta_fq_plonk_gate_vector_len = function (v) {
  return plonk_wasm.caml_pasta_fq_plonk_gate_vector_len(v);
};

// Provides: caml_pasta_fq_plonk_gate_vector_wrap
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fq_plonk_gate_vector_wrap = function (v, x, y) {
  return plonk_wasm.caml_pasta_fq_plonk_gate_vector_wrap(
    v,
    tsRustConversion.wireToRust(x),
    tsRustConversion.wireToRust(y)
  );
};

// Provides: caml_pasta_fq_plonk_gate_vector_digest
// Requires: plonk_wasm, caml_bytes_of_uint8array
var caml_pasta_fq_plonk_gate_vector_digest = function (
  public_input_size,
  gate_vector
) {
  var uint8array = plonk_wasm.caml_pasta_fq_plonk_gate_vector_digest(
    public_input_size,
    gate_vector
  );
  return caml_bytes_of_uint8array(uint8array);
};
