// Provides: wrap_wasm
// Requires: wrap_wasm_proof,wrap_wasm_oracles,wrap_wasm_prover_index,tsBindings,wrap_wasm_verifier_index,wrap_wasm_srs,wrap_wasm_gate_vector
function wrap_wasm(plonk_wasm){
  // jsoo hates the spread operator but this is a shalow coppy
  var plonk_intf = Object.assign({}, plonk_wasm);
  var tsRustConversion = tsBindings.rustConversion(plonk_wasm);

  wrap_wasm_proof(plonk_wasm,plonk_intf,tsRustConversion);
  wrap_wasm_oracles(plonk_wasm,plonk_intf,tsRustConversion);
  wrap_wasm_prover_index(plonk_wasm,plonk_intf,tsRustConversion);
  wrap_wasm_srs(plonk_wasm,plonk_intf,tsRustConversion);
  wrap_wasm_verifier_index(plonk_wasm,plonk_intf,tsRustConversion);
  wrap_wasm_gate_vector(plonk_wasm,plonk_intf,tsRustConversion);

  return plonk_intf
}

