/* global plonk_wasm, tsRustConversionNative */


// Provides: prover_to_json
// Requires: plonk_wasm, tsRustConversionNative
function prover_to_json(prover_index) {
  var bytes = prover_index.serialize()
  var index = plonk_wasm.prover_index_from_bytes(bytes);
  // TODO: ^ remove the round trip when napi has direct access to the object
  
  return plonk_wasm.prover_to_json(index);
}
