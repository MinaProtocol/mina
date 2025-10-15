/* global plonk_wasm, tsRustConversionNative */


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
function caml_pasta_fp_plonk_index_domain_d1_size(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_fp_from_bytes(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object

  return plonk_wasm.caml_pasta_fp_plonk_index_domain_d1_size(index);
}

// Provides: caml_pasta_fp_plonk_index_domain_d4_size
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_domain_d4_size =
  plonk_wasm.caml_pasta_fp_plonk_index_domain_d4_size;

// Provides: caml_pasta_fp_plonk_index_domain_d8_size
// Requires: plonk_wasm
var caml_pasta_fp_plonk_index_domain_d8_size =
  plonk_wasm.caml_pasta_fp_plonk_index_domain_d8_size;



//////// FQ ////////


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
function caml_pasta_fq_plonk_index_domain_d1_size(prover_index) {
    var bytes = prover_index.serialize()
    var index = plonk_wasm.prover_index_fq_from_bytes(bytes);
    // TODO: ^ remove the round trip when napi has direct access to the object

    return plonk_wasm.caml_pasta_fq_plonk_index_domain_d1_size(index);
}


// Provides: caml_pasta_fq_plonk_index_domain_d4_size
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_domain_d4_size =
  plonk_wasm.caml_pasta_fq_plonk_index_domain_d4_size;

// Provides: caml_pasta_fq_plonk_index_domain_d8_size
// Requires: plonk_wasm
var caml_pasta_fq_plonk_index_domain_d8_size =
  plonk_wasm.caml_pasta_fq_plonk_index_domain_d8_size;
