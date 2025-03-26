// Requires: caml_string_of_jsstring, free_on_finalize
// Provides: wrap_wasm_prover_index
function wrap_wasm_prover_index(plonk_wasm,plonk_intf,tsRustConversion){
  plonk_intf.caml_pasta_fq_plonk_circuit_serialize = function (
    public_input_size,
    gate_vector
  ) {
    return caml_string_of_jsstring(
      plonk_wasm.caml_pasta_fq_plonk_circuit_serialize(
        public_input_size,
        gate_vector
      )
    );
  };


  plonk_intf.caml_pasta_fp_plonk_index_create = function (
    gates,
    public_inputs,
    caml_lookup_tables,
    caml_runtime_table_cfgs,
    prev_challenges,
    urs
  ) {
    var wasm_lookup_tables =
      tsRustConversion.fp.lookupTablesToRust(caml_lookup_tables);
    var wasm_runtime_table_cfgs = tsRustConversion.fp.runtimeTableCfgsToRust(
      caml_runtime_table_cfgs
    );

    var t = plonk_wasm.caml_pasta_fp_plonk_index_create(
      gates,
      public_inputs,
      wasm_lookup_tables,
      wasm_runtime_table_cfgs,
      prev_challenges,
      urs
    );
    return free_on_finalize(t);
  };

  plonk_intf.caml_pasta_fq_plonk_index_create = function (
    gates,
    public_inputs,
    caml_lookup_tables,
    caml_runtime_table_cfgs,
    prev_challenges,
    urs
  ) {
    var wasm_lookup_tables =
      tsRustConversion.fq.lookupTablesToRust(caml_lookup_tables);
    var wasm_runtime_table_cfgs = tsRustConversion.fq.runtimeTableCfgsToRust(
      caml_runtime_table_cfgs
    );

    return free_on_finalize(
      plonk_wasm.caml_pasta_fq_plonk_index_create(
        gates,
        public_inputs,
        wasm_lookup_tables,
        wasm_runtime_table_cfgs,
        prev_challenges,
        urs
      )
    );
  };


}
