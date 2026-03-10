/* global plonk_wasm, tsRustConversion,
    
 */

// Provides: fp_oracles_create
// Requires: plonk_wasm, tsRustConversion
var fp_oracles_create = function (lgr_comm, verifier_index, proof) {
  return tsRustConversion.fp.oraclesFromRust(
    plonk_wasm.fp_oracles_create(
      tsRustConversion.fp.polyCommsToRust(lgr_comm),
      tsRustConversion.fp.verifierIndexToRust(verifier_index),
      tsRustConversion.fp.proofToRust(proof)
    )
  );
};

// Provides: fp_oracles_create_no_public
// Requires: fp_oracles_create
var fp_oracles_create_no_public = function (lgr_comm, verifier_index, proof) {
  return fp_oracles_create(lgr_comm, verifier_index, [0, 0, proof]);
};

// Provides: fp_oracles_dummy
// Requires: plonk_wasm, tsRustConversion
var fp_oracles_dummy = function () {
  return tsRustConversion.fp.oraclesFromRust(plonk_wasm.fp_oracles_dummy());
};

// Provides: fp_oracles_deep_copy
// Requires: plonk_wasm, tsRustConversion
var fp_oracles_deep_copy = function (x) {
  return tsRustConversion.fp.oraclesFromRust(
    plonk_wasm.fp_oracles_deep_copy(tsRustConversion.fp.oraclesToRust(x))
  );
};

// Provides: fq_oracles_create
// Requires: plonk_wasm, tsRustConversion
var fq_oracles_create = function (lgr_comm, verifier_index, proof) {
  return tsRustConversion.fq.oraclesFromRust(
    plonk_wasm.fq_oracles_create(
      tsRustConversion.fq.polyCommsToRust(lgr_comm),
      tsRustConversion.fq.verifierIndexToRust(verifier_index),
      tsRustConversion.fq.proofToRust(proof)
    )
  );
};

// Provides: fq_oracles_create_no_public
// Requires: fq_oracles_create
var fq_oracles_create_no_public = function (lgr_comm, verifier_index, proof) {
  return fq_oracles_create(lgr_comm, verifier_index, [0, 0, proof]);
};

// Provides: fq_oracles_dummy
// Requires: plonk_wasm, tsRustConversion
var fq_oracles_dummy = function () {
  return tsRustConversion.fq.oraclesFromRust(plonk_wasm.fq_oracles_dummy());
};

// Provides: fq_oracles_deep_copy
// Requires: plonk_wasm, tsRustConversion
var fq_oracles_deep_copy = function (x) {
  return tsRustConversion.fq.oraclesFromRust(
    plonk_wasm.fq_oracles_deep_copy(tsRustConversion.fq.oraclesToRust(x))
  );
};

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
// Requires: plonk_wasm, tsRustConversion, tsRustConversion
function caml_pasta_fp_poseidon_block_cipher(_fake_params, fp_vector) {
  // 1. get permuted field vector from rust
  var wasm_flat_vector = plonk_wasm.caml_pasta_fp_poseidon_block_cipher(
    tsRustConversion.fp.vectorToRust(fp_vector)
  );
  var new_fp_vector = tsRustConversion.fp.vectorFromRust(wasm_flat_vector);
  // 2. write back modified field vector to original one
  new_fp_vector.forEach(function (a, i) {
    fp_vector[i] = a;
  });
}

// Provides: caml_pasta_fq_poseidon_block_cipher
// Requires: plonk_wasm, tsRustConversion, tsRustConversion
function caml_pasta_fq_poseidon_block_cipher(_fake_params, fq_vector) {
  // 1. get permuted field vector from rust
  var wasm_flat_vector = plonk_wasm.caml_pasta_fq_poseidon_block_cipher(
    tsRustConversion.fq.vectorToRust(fq_vector)
  );
  var new_fq_vector = tsRustConversion.fq.vectorFromRust(wasm_flat_vector);
  // 2. write back modified field vector to original one
  new_fq_vector.forEach(function (a, i) {
    fq_vector[i] = a;
  });
}
