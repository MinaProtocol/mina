// Provides: plonk_wasm
var plonk_wasm = globalThis.plonk_wasm;

//Provides: plonk_intf
//Requires: plonk_wasm,wrap_wasm
var plonk_intf = wrap_wasm(plonk_wasm);

// TODO stop exporting tsRustConversion when possible

//Provides: tsRustConversion
//Requires: plonk_intf
var tsRustConversion = plonk_intf.tsRustConversion;
