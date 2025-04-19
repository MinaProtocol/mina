// Provides: wrap_wasm_gate_vector
function wrap_wasm_gate_vector(plonk_wasm,plonk_intf,tsRustConversion){

  plonk_intf.caml_pasta_fp_plonk_gate_vector_add = function (v, x) {
    return plonk_wasm.caml_pasta_fp_plonk_gate_vector_add(
      v,
      tsRustConversion.fp.gateToRust(x)
    );
  };

  plonk_intf.caml_pasta_fp_plonk_gate_vector_get = function (v, i) {
    return tsRustConversion.fp.gateFromRust(
      plonk_wasm.caml_pasta_fp_plonk_gate_vector_get(v, i)
    );
  };

  plonk_intf.caml_pasta_fp_plonk_gate_vector_wrap = function (v, x, y) {
    return plonk_wasm.caml_pasta_fp_plonk_gate_vector_wrap(
        v,
        tsRustConversion.wireToRust(x),
        tsRustConversion.wireToRust(y)
    );
  };

  plonk_intf.caml_pasta_fq_plonk_gate_vector_add = function (v, x) {
    return plonk_wasm.caml_pasta_fq_plonk_gate_vector_add(
      v,
      tsRustConversion.fq.gateToRust(x)
    );
  };

  plonk_intf.caml_pasta_fq_plonk_gate_vector_get = function (v, i) {
    return tsRustConversion.fq.gateFromRust(
      plonk_wasm.caml_pasta_fq_plonk_gate_vector_get(v, i)
    );
  };

  plonk_intf.caml_pasta_fq_plonk_gate_vector_wrap = function (v, x, y) {
    return plonk_wasm.caml_pasta_fq_plonk_gate_vector_wrap(
        v,
        tsRustConversion.wireToRust(x),
        tsRustConversion.wireToRust(y)
    );
  };

}
