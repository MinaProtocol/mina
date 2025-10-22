/* global plonk_wasm, caml_string_of_jsstring */


// Provides: caml_pasta_fp_plonk_circuit_serialize
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_pasta_fp_plonk_circuit_serialize = function (
  public_input_size,
  gate_vector
) {
  var t = plonk_wasm.caml_pasta_fp_plonk_circuit_serialize(
    plonk_wasm.caml_pasta_fp_plonk_gate_vector_from_bytes(gate_vector.serialize()),
    public_input_size
  );

  console.log(t);
  return caml_string_of_jsstring(
    t
  );
};


// Provides: caml_pasta_fq_plonk_circuit_serialize
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_pasta_fq_plonk_circuit_serialize = function (
  public_input_size,
  gate_vector
) {

  var t = plonk_wasm.caml_pasta_fq_plonk_circuit_serialize(
    plonk_wasm.caml_pasta_fq_plonk_gate_vector_from_bytes(gate_vector.serialize()),
    public_input_size
  );
  console.log(t)
  return caml_string_of_jsstring(
    t
  );
};