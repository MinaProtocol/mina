// Provides: plonk_wasm
// var plonk_wasm = require('./plonk_wasm.js');

// inject a global plonk_native object into js environment
// //Provides: plonk_native
var plonk_native = require('../../native_prover/index.node'); // TODO: add to dune

console.log('plonk_native', plonk_native);
