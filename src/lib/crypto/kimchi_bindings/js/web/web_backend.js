// Provides: kimchi_ffi
var kimchi_ffi = globalThis.kimchi_wasm;
if (kimchi_ffi) {
  kimchi_ffi.__kimchi_backend = 'wasm';
  if (typeof globalThis !== 'undefined') {
    globalThis.__kimchi_backend = 'wasm';
  }
}
