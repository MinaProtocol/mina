/* global plonk_wasm, tsRustConversion,*/

// This is fake -- parameters are only needed on the Rust side, so no need to return something meaningful
// Provides: caml_pasta_fp_poseidon_params_create
function caml_pasta_fp_poseidon_params_create() {
  return [0];
}

// Provides: fp_oracles_create
// Requires: plonk_wasm, tsRustConversionNative
var fp_oracles_create = function (lgr_comm, verifier_index, proof) {
  return tsRustConversionNative.fp.oraclesFromRust(
    plonk_wasm.fp_oracles_create(
      tsRustConversionNative.fp.polyCommsToRust(lgr_comm),
      tsRustConversionNative.fp.verifierIndexToRust(verifier_index),
      tsRustConversionNative.fp.proofToRust(proof)
    )
  );
};

// Provides: fp_oracles_create_no_public
// Requires: fp_oracles_create
var fp_oracles_create_no_public = function (lgr_comm, verifier_index, proof) {
  return fp_oracles_create(lgr_comm, verifier_index, [0, 0, proof]);
};

// Provides: fp_oracles_dummy
// Requires: plonk_wasm, tsRustConversionNative
var fp_oracles_dummy = function () {
  return tsRustConversionNative.fp.oraclesFromRust(plonk_wasm.fp_oracles_dummy());
};

// Provides: fp_oracles_deep_copy
// Requires: plonk_wasm, tsRustConversionNative
var fp_oracles_deep_copy = function (x) {
  return tsRustConversionNative.fp.oraclesFromRust(
    plonk_wasm.fp_oracles_deep_copy(tsRustConversionNative.fp.oraclesToRust(x))
  );
};

// Provides: caml_pasta_fq_poseidon_params_create
function caml_pasta_fq_poseidon_params_create() {
  return [0];
}

// Provides: fq_oracles_create
// Requires: plonk_wasm, tsRustConversionNative
var fq_oracles_create = function (lgr_comm, verifier_index, proof) {
  return tsRustConversionNative.fq.oraclesFromRust(
    plonk_wasm.fq_oracles_create(
      tsRustConversionNative.fq.polyCommsToRust(lgr_comm),
      tsRustConversionNative.fq.verifierIndexToRust(verifier_index),
      tsRustConversionNative.fq.proofToRust(proof)
    )
  );
};

// Provides: fq_oracles_create_no_public
// Requires: fq_oracles_create
var fq_oracles_create_no_public = function (lgr_comm, verifier_index, proof) {
  return fq_oracles_create(lgr_comm, verifier_index, [0, 0, proof]);
};

// Provides: fq_oracles_dummy
// Requires: plonk_wasm, tsRustConversionNative
var fq_oracles_dummy = function () {
  return tsRustConversionNative.fq.oraclesFromRust(plonk_wasm.fq_oracles_dummy());
};

// Provides: fq_oracles_deep_copy
// Requires: plonk_wasm, tsRustConversionNative
var fq_oracles_deep_copy = function (x) {
  return tsRustConversionNative.fq.oraclesFromRust(
    plonk_wasm.fq_oracles_deep_copy(tsRustConversionNative.fq.oraclesToRust(x))
  );
};

// Provides: caml_pasta_fq_poseidon_block_cipher
// Requires: plonk_wasm, tsRustConversionNative
function caml_pasta_fq_poseidon_block_cipher(_fake_params, fq_vector) {
  // 1. get permuted field vector from rust
  var wasm_flat_vector = plonk_wasm.caml_pasta_fq_poseidon_block_cipher(
    tsRustConversionNative.fq.vectorToRust(fq_vector)
  );
  var new_fq_vector = tsRustConversionNative.fq.vectorFromRust(wasm_flat_vector);
  // 2. write back modified field vector to original one
  new_fq_vector.forEach(function (a, i) {
    fq_vector[i] = a;
  });
}


// Provides: caml_pasta_fp_poseidon_block_cipher
// Requires: plonk_wasm, tsRustConversionNative
function caml_pasta_fp_poseidon_block_cipher(_fake_params, fp_vector) {
  // 1. get permuted field vector from rust
  var wasm_flat_vector = plonk_wasm.caml_pasta_fp_poseidon_block_cipher(
    tsRustConversionNative.fp.vectorToRust(fp_vector)
  );
  var new_fp_vector = tsRustConversionNative.fp.vectorFromRust(wasm_flat_vector);
  // 2. write back modified field vector to original one
  new_fp_vector.forEach(function (a, i) {
    fp_vector[i] = a;
  });
}

