// Provides: kimchi_ffi
var kimchi_ffi = (function () {
  // The kimchi FFI module (kimchi-napi, either the native .node build or the
  // wasm32-wasip1-threads build of the same crate) is loaded and installed on
  // this global by the o1js backend loaders (src/bindings/js/node/*.js) before
  // the compiled OCaml artifact is evaluated.
  var ffi = typeof globalThis !== 'undefined' && globalThis.__o1js_kimchi_ffi;
  if (!ffi) {
    throw new Error(
      'o1js internal error: kimchi FFI module is not initialized. ' +
        'A backend must be loaded via initializeBindings() before the compiled OCaml code runs.'
    );
  }
  if (typeof globalThis !== 'undefined') {
    globalThis.__kimchi_backend = ffi.__kimchi_backend;
  }
  return ffi;
})();
