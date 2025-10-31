// Provides: plonk_wasm
var plonk_wasm = (function() {
  var wasm = require('./plonk_wasm.js');

  try {
    var native =  require('@o1js/native-' + process.platform + '-' + process.arch)

    wasm["caml_pasta_fp_poseidon_block_cipher"] = native["caml_pasta_fp_poseidon_block_cipher"]
    wasm["caml_pasta_fq_poseidon_block_cipher"] = native["caml_pasta_fq_poseidon_block_cipher"]
  } catch (e) {
    console.error(e)
    console.log("native didn't load")
    process.exit(1);
  }

  return wasm
})()

