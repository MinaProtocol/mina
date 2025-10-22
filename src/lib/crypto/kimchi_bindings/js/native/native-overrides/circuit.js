/* global plonk_wasm */


// Provides: prover_to_json
// Requires: plonk_wasm
function prover_to_json(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_fp_from_bytes(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object
  
  return plonk_wasm.prover_to_json(index);
}
