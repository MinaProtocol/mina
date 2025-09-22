// Provides: plonk_wasm
// Provides: rust_intf

// Load the neon addon compiled by build.sh (Neon/NAPI -> .node)
var rust_intf = require('./plonk_neon.node');

// Back-compatible during migration: keep the old symbol
var plonk_wasm = rust_intf;