// Provides: plonk_wasm
var plonk_wasm = (function() {
  var wasm = require('./plonk_wasm.js');

  try {
    var native =  require('@o1js/native-' + process.platform + '-' + process.arch)

    // THIS IS A RUNTIME OVERRIDE
    // YOU HAVE TO RUN IT TO SEE IF IT BREAKS
    // IT WON'T CRASH UNLESS O1JS_REQUIRE_NATIVE_BINDINGS
    // IS SET
    var overrides = [
      "prover_to_json",
      "prover_index_from_bytes",
      "prover_index_to_bytes",
      "caml_pasta_fp_poseidon_block_cipher",
      "caml_pasta_fq_poseidon_block_cipher",
      "caml_pasta_fp_plonk_proof_create",
    ]

    overrides.forEach(function (override) {
      wasm[override] = native[override]
    })

    wasm.native = true;
  } catch (e) {
    if (process.env.O1JS_REQUIRE_NATIVE_BINDINGS) {
      console.error(e)
      console.log("native didn't load")
      process.exit(1);
    }
  }

  return wasm
})()
