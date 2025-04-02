// Provides: plonk_wasm
var plonk_wasm = require('./plonk_wasm.js');
var plonk_neon = require('./plonk_neon.node');
plonk_wasm.caml_pasta_fp_poseidon_block_cipher = plonk_neon.caml_pasta_fp_poseidon_block_cipher;
plonk_wasm.caml_pasta_fq_poseidon_block_cipher = plonk_neon.caml_pasta_fq_poseidon_block_cipher;
