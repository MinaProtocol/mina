/* eslint-disable no-unused-vars */
/* global plonk_wasm, caml_jsstring_of_string, caml_string_of_jsstring,
    caml_create_bytes, caml_bytes_unsafe_set, caml_bytes_unsafe_get, caml_ml_bytes_length,
    UInt64, caml_int64_of_int32, tsRustConversion,tsSrs,free_on_finalize,caml_bytes_of_uint8array
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

// prover index

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

// Provides: caml_pasta_fq_plonk_circuit_serialize
// Requires: plonk_wasm, caml_string_of_jsstring
var caml_pasta_fq_plonk_circuit_serialize = function (
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

// Provides: caml_pasta_fp_plonk_index_create
// Requires: plonk_wasm, free_on_finalize, tsRustConversion
var caml_pasta_fp_plonk_index_create = function (
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

// Provides: caml_pasta_fp_plonk_index_create_bytecode
// Requires: caml_pasta_fp_plonk_index_create
var caml_pasta_fp_plonk_index_create_bytecode = function (
  gates,
  public_inputs,
  caml_lookup_tables,
  caml_runtime_table_cfgs,
  prev_challenges,
  urs
) {
  return caml_pasta_fp_plonk_index_create(
    gates,
    public_inputs,
    caml_lookup_tables,
    caml_runtime_table_cfgs,
    prev_challenges,
    urs
  );
};

// Provides: caml_pasta_fp_plonk_index_max_degree
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_max_degree =
  plonk_wasm.caml_pasta_fp_plonk_index_max_degree;

// Provides: caml_pasta_fp_plonk_index_public_inputs
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_public_inputs =
  plonk_wasm.caml_pasta_fp_plonk_index_public_inputs;

// Provides: caml_pasta_fp_plonk_index_domain_d1_size
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_domain_d1_size =
  plonk_wasm.caml_pasta_fp_plonk_index_domain_d1_size;

// Provides: caml_pasta_fp_plonk_index_domain_d4_size
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_domain_d4_size =
  plonk_wasm.caml_pasta_fp_plonk_index_domain_d4_size;

// Provides: caml_pasta_fp_plonk_index_domain_d8_size
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_domain_d8_size =
  plonk_wasm.caml_pasta_fp_plonk_index_domain_d8_size;

// Provides: caml_pasta_fp_plonk_index_read
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fp_plonk_index_read = function (offset, urs, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return plonk_wasm.caml_pasta_fp_plonk_index_read(
    offset,
    urs,
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fp_plonk_index_write
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fp_plonk_index_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_pasta_fp_plonk_index_write(
    append,
    t,
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fq_plonk_index_create
// Requires: plonk_wasm, free_on_finalize, tsRustConversion
var caml_pasta_fq_plonk_index_create = function (
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

// Provides: caml_pasta_fq_plonk_index_create_bytecode
// Requires: caml_pasta_fq_plonk_index_create
var caml_pasta_fq_plonk_index_create_bytecode = function (
  gates,
  public_inputs,
  caml_lookup_tables,
  caml_runtime_table_cfgs,
  prev_challenges,
  urs
) {
  return caml_pasta_fq_plonk_index_create(
    gates,
    public_inputs,
    caml_lookup_tables,
    caml_runtime_table_cfgs,
    prev_challenges,
    urs
  );
};

// Provides: caml_pasta_fq_plonk_index_max_degree
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_max_degree =
  plonk_wasm.caml_pasta_fq_plonk_index_max_degree;

// Provides: caml_pasta_fq_plonk_index_public_inputs
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_public_inputs =
  plonk_wasm.caml_pasta_fq_plonk_index_public_inputs;

// Provides: caml_pasta_fq_plonk_index_domain_d1_size
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_domain_d1_size =
  plonk_wasm.caml_pasta_fq_plonk_index_domain_d1_size;

// Provides: caml_pasta_fq_plonk_index_domain_d4_size
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_domain_d4_size =
  plonk_wasm.caml_pasta_fq_plonk_index_domain_d4_size;

// Provides: caml_pasta_fq_plonk_index_domain_d8_size
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_domain_d8_size =
  plonk_wasm.caml_pasta_fq_plonk_index_domain_d8_size;

// Provides: caml_pasta_fq_plonk_index_read
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fq_plonk_index_read = function (offset, urs, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return plonk_wasm.caml_pasta_fq_plonk_index_read(
    offset,
    urs,
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fq_plonk_index_write
// Requires: plonk_wasm, caml_jsstring_of_string
var caml_pasta_fq_plonk_index_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_wasm.caml_pasta_fq_plonk_index_write(
    append,
    t,
    caml_jsstring_of_string(path)
  );
};
