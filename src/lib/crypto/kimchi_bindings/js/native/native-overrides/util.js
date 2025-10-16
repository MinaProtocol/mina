/* global plonk_wasm, tsRustConversionNative, getTsBindings, tsBindings */


// Provides: tsRustConversionNative
// Requires: tsBindings, plonk_wasm, getTsBindings
var tsRustConversionNative = tsBindings.nativeRustConversion(plonk_wasm);