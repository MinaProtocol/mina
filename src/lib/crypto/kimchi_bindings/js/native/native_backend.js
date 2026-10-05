// Provides: kimchi_ffi
var kimchi_ffi =
  require('@o1js/native-' + globalThis.process.platform + '-' + globalThis.process.arch)
kimchi_ffi.__kimchi_backend = 'native';
if (typeof globalThis !== 'undefined') {
  globalThis.__kimchi_backend = 'native';
}
