/* global plonk_intf, tsRustConversion,
 */

// Provides: fp_oracles_create
// Requires: plonk_intf
var fp_oracles_create = plonk_intf.fp_oracles_create

// Provides: fp_oracles_create_no_public
// Requires: fp_oracles_create
var fp_oracles_create_no_public = function (lgr_comm, verifier_index, proof) {
  return fp_oracles_create(lgr_comm, verifier_index, [0, 0, proof]);
};

// Provides: fp_oracles_dummy
// Requires: plonk_intf
var fp_oracles_dummy = plonk_intf.fp_oracles_dummy;

// Provides: fp_oracles_deep_copy
// Requires: plonk_intf
var fp_oracles_deep_copy = plonk_intf.fp_oracles_deep_copy;

// Provides: fq_oracles_create
// Requires: plonk_intf
var fq_oracles_create = plonk_intf.fq_oracles_create;

// Provides: fq_oracles_create_no_public
// Requires: fq_oracles_create
var fq_oracles_create_no_public = function (lgr_comm, verifier_index, proof) {
  return fq_oracles_create(lgr_comm, verifier_index, [0, 0, proof]);
};

// Provides: fq_oracles_dummy
// Requires: plonk_intf, tsRustConversion
var fq_oracles_dummy = plonk_intf.fq_oracles_dummy;

// Provides: fq_oracles_deep_copy
// Requires: plonk_intf, tsRustConversion
var fq_oracles_deep_copy = plonk_intf.fq_oracles_deep_copy;

// This is fake -- parameters are only needed on the Rust side, so no need to return something meaningful
// Provides: caml_pasta_fp_poseidon_params_create
function caml_pasta_fp_poseidon_params_create() {
  return [0];
}
// Provides: caml_pasta_fq_poseidon_params_create
function caml_pasta_fq_poseidon_params_create() {
  return [0];
}

// Provides: caml_pasta_fp_poseidon_block_cipher
// Requires: plonk_intf
function caml_pasta_fp_poseidon_block_cipher(_fake_params, fp_vector) {
  plonk_intf.caml_pasta_fp_poseidon_block_cipher(_fake_params, fp_vector);
}

// Provides: caml_pasta_fq_poseidon_block_cipher
// Requires: plonk_intf
function caml_pasta_fq_poseidon_block_cipher(_fake_params, fq_vector) {
  plonk_intf.caml_pasta_fq_poseidon_block_cipher(_fake_params, fq_vector);
}
