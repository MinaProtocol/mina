// Provides: wrap_wasm_oracles
function wrap_wasm_oracles(plonk_wasm,plonk_intf,tsRustConversion){

  plonk_intf.fp_oracles_create = function (lgr_comm, verifier_index, proof) {
    return tsRustConversion.fp.oraclesFromRust(
      plonk_wasm.fp_oracles_create(
        tsRustConversion.fp.polyCommsToRust(lgr_comm),
        tsRustConversion.fp.verifierIndexToRust(verifier_index),
        tsRustConversion.fp.proofToRust(proof)
      )
    );
  };

  plonk_intf.fp_oracles_dummy = function () {
    return tsRustConversion.fp.oraclesFromRust(plonk_wasm.fp_oracles_dummy());
  };


  plonk_intf.fp_oracles_deep_copy = function (x) {
    return tsRustConversion.fp.oraclesFromRust(
      plonk_wasm.fp_oracles_deep_copy(tsRustConversion.fp.oraclesToRust(x))
    );
  };

  plonk_intf.fq_oracles_create = function (lgr_comm, verifier_index, proof) {
    return tsRustConversion.fq.oraclesFromRust(
      plonk_wasm.fq_oracles_create(
        tsRustConversion.fq.polyCommsToRust(lgr_comm),
        tsRustConversion.fq.verifierIndexToRust(verifier_index),
        tsRustConversion.fq.proofToRust(proof)
      )
    );
  };

  plonk_intf.fq_oracles_dummy = function () {
    return tsRustConversion.fq.oraclesFromRust(plonk_wasm.fq_oracles_dummy());
  };

  plonk_intf.fq_oracles_deep_copy = function (x) {
    return tsRustConversion.fq.oraclesFromRust(
      plonk_wasm.fq_oracles_deep_copy(tsRustConversion.fq.oraclesToRust(x))
    );
  };

  plonk_intf.caml_pasta_fp_poseidon_block_cipher = function(fp_vector) {
    // 1. get permuted field vector from rust
    var wasm_flat_vector = plonk_wasm.caml_pasta_fp_poseidon_block_cipher(
      tsRustConversion.fp.vectorToRust(fp_vector)
    );
    var new_fp_vector = tsRustConversion.fp.vectorFromRust(wasm_flat_vector);
    // 2. write back modified field vector to original one
    new_fp_vector.forEach(function (a, i) {
      fp_vector[i] = a;
    });
  };

  plonk_intf.caml_pasta_fq_poseidon_block_cipher = function(fq_vector) {
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

}
