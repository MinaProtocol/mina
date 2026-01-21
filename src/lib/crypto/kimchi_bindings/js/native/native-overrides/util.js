/* global plonk_wasm, tsRustConversionNative, getTsBindings, tsBindings */

// Provides: tsRustConversionNative
// Requires: tsBindings, plonk_wasm, getTsBindings
plonk_wasm.__kimchi_use_native = true;
var tsRustConversionNative = tsBindings.rustConversion(plonk_wasm);
