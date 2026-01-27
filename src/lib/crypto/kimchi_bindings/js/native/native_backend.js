// Provides: kimchi_napi
// Requires: process
var kimchi_napi = require('@o1js/native-' + process.platform + '-' + process.arch)
kimchi_napi.native = true;

// Requires: kimchi_napi
// Provides: kimchi_ffi
var kimchi_ffi = kimchi_napi
