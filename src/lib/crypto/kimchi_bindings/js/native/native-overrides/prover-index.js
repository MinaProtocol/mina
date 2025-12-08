/* global plonk_wasm, tsRustConversionNative, caml_jsstring_of_string */

// Provides: caml_pasta_fp_plonk_index_max_degree
// Requires: plonk_wasm
function caml_pasta_fp_plonk_index_max_degree(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_fp_deserialize(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object
  
  return plonk_wasm.caml_pasta_fp_plonk_index_max_degree(index);
}

// Provides: caml_pasta_fp_plonk_index_public_inputs
// Requires: plonk_wasm
function caml_pasta_fp_plonk_index_public_inputs(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_fp_deserialize(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object

  return plonk_wasm.caml_pasta_fp_plonk_index_public_inputs(index);
}

// Provides: caml_pasta_fp_plonk_index_domain_d1_size
// Requires: plonk_wasm
function caml_pasta_fp_plonk_index_domain_d1_size(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_fp_deserialize(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object

  return plonk_wasm.caml_pasta_fp_plonk_index_domain_d1_size(index);
}

// Provides: caml_pasta_fp_plonk_index_domain_d4_size
// Requires: plonk_wasm
function caml_pasta_fp_plonk_index_domain_d4_size(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_fp_deserialize(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object

  return plonk_wasm.caml_pasta_fp_plonk_index_domain_d4_size(index);
}

// Provides: caml_pasta_fp_plonk_index_domain_d8_size
// Requires: plonk_wasm
function caml_pasta_fp_plonk_index_domain_d8_size(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_fp_deserialize(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object

  return plonk_wasm.caml_pasta_fp_plonk_index_domain_d8_size(index);
}


//////// FQ ////////


// Provides: caml_pasta_fq_plonk_index_max_degree
// Requires: plonk_wasm
function caml_pasta_fq_plonk_index_max_degree(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_fq_deserialize(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object

  return plonk_wasm.caml_pasta_fq_plonk_index_max_degree(index);
}

// Provides: caml_pasta_fq_plonk_index_public_inputs
// Requires: plonk_wasm
function caml_pasta_fq_plonk_index_public_inputs(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_fq_deserialize(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object

  return plonk_wasm.caml_pasta_fq_plonk_index_public_inputs(index);
}

// Provides: caml_pasta_fq_plonk_index_domain_d1_size
// Requires: plonk_wasm
function caml_pasta_fq_plonk_index_domain_d1_size(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_fq_deserialize(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object

  return plonk_wasm.caml_pasta_fq_plonk_index_domain_d1_size(index);
}

// Provides: caml_pasta_fq_plonk_index_domain_d4_size
// Requires: plonk_wasm
function caml_pasta_fq_plonk_index_domain_d4_size(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_fq_deserialize(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object

  return plonk_wasm.caml_pasta_fq_plonk_index_domain_d4_size(index);
}

// Provides: caml_pasta_fq_plonk_index_domain_d8_size
// Requires: plonk_wasm
function caml_pasta_fq_plonk_index_domain_d8_size(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_fq_deserialize(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object

  return plonk_wasm.caml_pasta_fq_plonk_index_domain_d8_size(index);
}


// Provides: caml_pasta_fp_plonk_index_serialize
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_serialize = function (index) {
  // Workaround for napi issue where methods on External objects are not accessible
  if (typeof index.serialize === 'function') {
    return index.serialize();
  }
  return plonk_wasm.prover_index_fp_serialize(index);
};

// Provides: caml_pasta_fp_plonk_index_deserialize
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_deserialize = function (index) {
  // Workaround for napi issue where methods on External objects are not accessible
  if (typeof index.deserialize === 'function') {
    return index.deserialize();
  }
  return plonk_wasm.prover_index_fp_deserialize(index);
};

// Provides: caml_pasta_fp_plonk_index_create
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fp_plonk_index_create = function (
  gates,
  public_inputs,
  caml_lookup_tables,
  caml_runtime_table_cfgs,
  prev_challenges,
  urs,
  lazy_mode
) {
  console.log('passing through wasm lookup tables')
  var wasm_lookup_tables =
    tsRustConversionNative.fp.lookupTablesToRust(caml_lookup_tables);
  var wasm_runtime_table_cfgs = tsRustConversionNative.fp.runtimeTableCfgsToRust(
    caml_runtime_table_cfgs
  );
  console.time("conversion plonk index create")
  var gate_vec = plonk_wasm.caml_pasta_fp_plonk_gate_vector_from_bytes(gates.serialize());
  var urs_ser = plonk_wasm.caml_fp_srs_from_bytes_external(urs.serialize())
  console.timeEnd("conversion plonk index create")

  console.time("index_create")
  var t = plonk_wasm.caml_pasta_fp_plonk_index_create(
    gate_vec,
    public_inputs,
    wasm_lookup_tables,
    wasm_runtime_table_cfgs,
    prev_challenges,
    urs_ser, 
    lazy_mode
  );
  console.timeEnd("index_create");

  return t;
};

// Provides: caml_pasta_fp_plonk_index_create_bytecode
// Requires: caml_pasta_fp_plonk_index_create
var caml_pasta_fp_plonk_index_create_bytecode = function (
  gates,
  public_inputs,
  caml_lookup_tables,
  caml_runtime_table_cfgs,
  prev_challenges,
  urs,
  lazy_mode
) {
  return caml_pasta_fp_plonk_index_create(
    gates,
    public_inputs,
    caml_lookup_tables,
    caml_runtime_table_cfgs,
    prev_challenges,
    urs,
    lazy_mode
  );
};

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

// Provides: caml_pasta_fq_plonk_index_serialize
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_serialize = function (index) {
  // Workaround for napi issue where methods on External objects are not accessible
  if (typeof index.serialize === 'function') {
    return index.serialize();
  }
  return plonk_wasm.prover_index_fq_serialize(index);
};

// Provides: caml_pasta_fq_plonk_index_deserialize
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_deserialize = function (index) {
  // Workaround for napi issue where methods on External objects are not accessible
  if (typeof index.deserialize === 'function') {
    return index.deserialize();
  }
  return plonk_wasm.prover_index_fq_deserialize(index);
};

// Provides: caml_pasta_fq_plonk_index_create
// Requires: plonk_wasm, tsRustConversionNative
var caml_pasta_fq_plonk_index_create = function (
  gates,
  public_inputs,
  caml_lookup_tables,
  caml_runtime_table_cfgs,
  prev_challenges,
  urs,
  lazy_mode
) {
  console.log("anais: 1");
  var wasm_lookup_tables =
    tsRustConversionNative.fq.lookupTablesToRust(caml_lookup_tables);
    console.log("anais: 2");
  var wasm_runtime_table_cfgs = tsRustConversionNative.fq.runtimeTableCfgsToRust(
    caml_runtime_table_cfgs
  );
  console.log("anais: 3");

  console.time("conversion")
  var gate_vec = plonk_wasm.caml_pasta_fq_plonk_gate_vector_deserialize(gates.serialize());
  var urs_ser = plonk_wasm.caml_fq_srs_from_bytes_external(urs.serialize())
  console.timeEnd("conversion")
  console.log("anais: 4");

  console.time("index_create")
  var t = plonk_wasm.caml_pasta_fq_plonk_index_create(
    gate_vec,
    public_inputs,
    wasm_lookup_tables,
    wasm_runtime_table_cfgs,
    prev_challenges,
    urs_ser, 
    lazy_mode
  );
  console.timeEnd("index_create");

  return t;
}; 

// Provides: caml_pasta_fq_plonk_index_create_bytecode
// Requires: caml_pasta_fq_plonk_index_create
var caml_pasta_fq_plonk_index_create_bytecode = function (
  gates,
  public_inputs,
  caml_lookup_tables,
  caml_runtime_table_cfgs,
  prev_challenges,
  urs,
  lazy_mode
) {
  return caml_pasta_fq_plonk_index_create(
    gates,
    public_inputs,
    caml_lookup_tables,
    caml_runtime_table_cfgs,
    prev_challenges,
    urs,
    lazy_mode
  );
};

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