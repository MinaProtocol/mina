// Provides: wrap_wasm
// Requires: wrap_wasm_proof
function wrap_wasm(plonk_wasm){
  // jsoo hates the spread operator but this is a shalow coppy
  var plonk_intf = Object.assign({}, plonk_wasm);
  wrap_wasm_proof(plonk_wasm,plonk_intf);
  return plonk_intf
}
