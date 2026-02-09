// Provides: kimchi_ffi
var kimchi_ffi = (function () {
  var preference = (typeof globalThis !== 'undefined' && globalThis.__o1js_backend_preference) || 'wasm';

  if (preference === 'native') {
    // trying toload directly
    var native = require('@o1js/native-' + globalThis.process.platform + '-' + globalThis.process.arch);
    native.__kimchi_backend = 'native';
    if (typeof globalThis !== 'undefined') globalThis.__kimchi_backend = 'native';
    return native;
  }

  // default case wams
  var wasm = require('./kimchi_wasm.js');
  wasm.__kimchi_backend = 'wasm';
  if (typeof globalThis !== 'undefined') globalThis.__kimchi_backend = 'wasm';
  return wasm;
})()
