/* global plonk_intf, caml_string_of_jsstring,
    free_on_finalize, caml_jsstring_of_string
 */

// Provides: caml_pasta_fq_plonk_circuit_serialize
// Requires: plonk_intf
var caml_pasta_fq_plonk_circuit_serialize = plonk_intf.caml_pasta_fq_plonk_circuit_serialize;

// Provides: caml_pasta_fp_plonk_index_create
// Requires: plonk_intf
var caml_pasta_fp_plonk_index_create = plonk_intf.caml_pasta_fp_plonk_index_create;

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
// Requires: plonk_intf
var caml_pasta_fp_plonk_index_max_degree =
  plonk_intf.caml_pasta_fp_plonk_index_max_degree;

// Provides: caml_pasta_fp_plonk_index_public_inputs
// Requires: plonk_intf
var caml_pasta_fp_plonk_index_public_inputs =
  plonk_intf.caml_pasta_fp_plonk_index_public_inputs;

// Provides: caml_pasta_fp_plonk_index_domain_d1_size
// Requires: plonk_intf
var caml_pasta_fp_plonk_index_domain_d1_size =
  plonk_intf.caml_pasta_fp_plonk_index_domain_d1_size;

// Provides: caml_pasta_fp_plonk_index_domain_d4_size
// Requires: plonk_intf
var caml_pasta_fp_plonk_index_domain_d4_size =
  plonk_intf.caml_pasta_fp_plonk_index_domain_d4_size;

// Provides: caml_pasta_fp_plonk_index_domain_d8_size
// Requires: plonk_intf
var caml_pasta_fp_plonk_index_domain_d8_size =
  plonk_intf.caml_pasta_fp_plonk_index_domain_d8_size;

// Provides: caml_pasta_fp_plonk_index_read
// Requires: plonk_intf, caml_jsstring_of_string
var caml_pasta_fp_plonk_index_read = function (offset, urs, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return plonk_intf.caml_pasta_fp_plonk_index_read(
    offset,
    urs,
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fp_plonk_index_write
// Requires: plonk_intf, caml_jsstring_of_string
var caml_pasta_fp_plonk_index_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_intf.caml_pasta_fp_plonk_index_write(
    append,
    t,
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fq_plonk_index_create
// Requires: plonk_intf, free_on_finalize
var caml_pasta_fq_plonk_index_create = plonk_intf.caml_pasta_fq_plonk_index_create;

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
// Requires: plonk_intf
var caml_pasta_fq_plonk_index_max_degree =
  plonk_intf.caml_pasta_fq_plonk_index_max_degree;

// Provides: caml_pasta_fq_plonk_index_public_inputs
// Requires: plonk_intf
var caml_pasta_fq_plonk_index_public_inputs =
  plonk_intf.caml_pasta_fq_plonk_index_public_inputs;

// Provides: caml_pasta_fq_plonk_index_domain_d1_size
// Requires: plonk_intf
var caml_pasta_fq_plonk_index_domain_d1_size =
  plonk_intf.caml_pasta_fq_plonk_index_domain_d1_size;

// Provides: caml_pasta_fq_plonk_index_domain_d4_size
// Requires: plonk_intf
var caml_pasta_fq_plonk_index_domain_d4_size =
  plonk_intf.caml_pasta_fq_plonk_index_domain_d4_size;

// Provides: caml_pasta_fq_plonk_index_domain_d8_size
// Requires: plonk_intf
var caml_pasta_fq_plonk_index_domain_d8_size =
  plonk_intf.caml_pasta_fq_plonk_index_domain_d8_size;

// Provides: caml_pasta_fq_plonk_index_read
// Requires: plonk_intf, caml_jsstring_of_string
var caml_pasta_fq_plonk_index_read = function (offset, urs, path) {
  if (offset === 0) {
    offset = undefined;
  } else {
    offset = offset[1];
  }
  return plonk_intf.caml_pasta_fq_plonk_index_read(
    offset,
    urs,
    caml_jsstring_of_string(path)
  );
};

// Provides: caml_pasta_fq_plonk_index_write
// Requires: plonk_intf, caml_jsstring_of_string
var caml_pasta_fq_plonk_index_write = function (append, t, path) {
  if (append === 0) {
    append = undefined;
  } else {
    append = append[1];
  }
  return plonk_intf.caml_pasta_fq_plonk_index_write(
    append,
    t,
    caml_jsstring_of_string(path)
  );
};
