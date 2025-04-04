/* eslint-disable no-unused-vars */
/* global plonk_intf, caml_string_of_jsstring,
    free_on_finalize, caml_bytes_of_uint8array
*/

// Provides: caml_pasta_fp_plonk_gate_vector_create
// Requires: plonk_intf, free_on_finalize
var caml_pasta_fp_plonk_gate_vector_create = function () {
  return free_on_finalize(plonk_intf.caml_pasta_fp_plonk_gate_vector_create());
};

// Provides: caml_pasta_fp_plonk_gate_vector_add
// Requires: plonk_intf
var caml_pasta_fp_plonk_gate_vector_add = plonk_intf.caml_pasta_fp_plonk_gate_vector_add;

// Provides: caml_pasta_fp_plonk_gate_vector_get
// Requires: plonk_intf
var caml_pasta_fp_plonk_gate_vector_get = plonk_intf.caml_pasta_fp_plonk_gate_vector_get;

// Provides: caml_pasta_fp_plonk_gate_vector_len
// Requires: plonk_intf
var caml_pasta_fp_plonk_gate_vector_len = function (v) {
  return plonk_intf.caml_pasta_fp_plonk_gate_vector_len(v);
};

// Provides: caml_pasta_fp_plonk_gate_vector_wrap
// Requires: plonk_intf
var caml_pasta_fp_plonk_gate_vector_wrap = plonk_intf.caml_pasta_fp_plonk_gate_vector_wrap;

// Provides: caml_pasta_fp_plonk_gate_vector_digest
// Requires: plonk_intf, caml_bytes_of_uint8array
var caml_pasta_fp_plonk_gate_vector_digest = function (
  public_input_size,
  gate_vector
) {
  var uint8array = plonk_intf.caml_pasta_fp_plonk_gate_vector_digest(
    public_input_size,
    gate_vector
  );
  return caml_bytes_of_uint8array(uint8array);
};

// Provides: caml_pasta_fp_plonk_circuit_serialize
// Requires: plonk_intf, caml_string_of_jsstring
var caml_pasta_fp_plonk_circuit_serialize = function (
  public_input_size,
  gate_vector
) {
  return caml_string_of_jsstring(
    plonk_intf.caml_pasta_fp_plonk_circuit_serialize(
      public_input_size,
      gate_vector
    )
  );
};

// Provides: caml_pasta_fq_plonk_gate_vector_create
// Requires: plonk_intf, free_on_finalize
var caml_pasta_fq_plonk_gate_vector_create = function () {
  return free_on_finalize(plonk_intf.caml_pasta_fq_plonk_gate_vector_create());
};

// Provides: caml_pasta_fq_plonk_gate_vector_add
// Requires: plonk_intf
var caml_pasta_fq_plonk_gate_vector_add = plonk_intf.caml_pasta_fq_plonk_gate_vector_add;

// Provides: caml_pasta_fq_plonk_gate_vector_get
// Requires: plonk_intf
var caml_pasta_fq_plonk_gate_vector_get = plonk_intf.caml_pasta_fq_plonk_gate_vector_get;

// Provides: caml_pasta_fq_plonk_gate_vector_len
// Requires: plonk_intf
var caml_pasta_fq_plonk_gate_vector_len = function (v) {
  return plonk_intf.caml_pasta_fq_plonk_gate_vector_len(v);
};

// Provides: caml_pasta_fq_plonk_gate_vector_wrap
// Requires: plonk_intf
var caml_pasta_fq_plonk_gate_vector_wrap = plonk_intf.caml_pasta_fq_plonk_gate_vector_wrap;

// Provides: caml_pasta_fq_plonk_gate_vector_digest
// Requires: plonk_intf, caml_bytes_of_uint8array
var caml_pasta_fq_plonk_gate_vector_digest = function (
  public_input_size,
  gate_vector
) {
  var uint8array = plonk_intf.caml_pasta_fq_plonk_gate_vector_digest(
    public_input_size,
    gate_vector
  );
  return caml_bytes_of_uint8array(uint8array);
};
