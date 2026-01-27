/* global kimchi_ffi, tsRustConversionNative */


// Provides: prover_to_json
// Requires: kimchi_ffi, tsRustConversionNative
function prover_to_json(prover_index) {
  var bytes = prover_index.serialize()
  var index = kimchi_ffi.prover_index_fp_from_bytes(bytes);
  return kimchi_ffi.prover_to_json(index);
}
