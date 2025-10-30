/* global plonk_wasm, tsRustConversionNative,*/


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
