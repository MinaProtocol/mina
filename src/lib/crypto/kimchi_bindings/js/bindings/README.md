**Despite popular belief, the bindings files are not auto-generated, they just look funny.**

In OCaml, we sometimes call out to foreign functions (that is usually indicated by the `external` keyword), here's an example:

```ml
module FunnyLittleModule = struct
  external do_cool_thingies : unit -> unit = "caml_do_cool_thingies"
end
```

This way, when calling the function `FunnyLittleModule.do_cool_thingies`, we tell OCaml that the implementation for `do_cool_thingies` is actually somewhere else, and not in OCaml directly. That other place can, as in our case, be in Rust! So whenever we call `FunnyLittleModule.do_cool_thingies`, we tell OCaml under the hood to look for an external function, in our case somewhere in the Rust bindings, that is called `caml_do_cool_thingies`, and executes it.

We use this for many things. Many things in the code base rely of implementations in Rust. For example, we use Kimchi to generate proofs! So in order to tell OCaml to generate a Kimchi proof, we need to point it to the correct function that's living in the Rust proof-systems repository.

The other side of the `external` keyword is somewhere in the Rust bindings layer, more specifically somewhere in `src/lib/crypto/kimchi_bindings/wasm/src` - in our case where we want to establish bindings between OCaml that has been compiled to JavaScript using JSOO and Rust (compiled to WASM).

For example, the implementation of `caml_do_cool_thingies` could look like this:

```rs
#[wasm_bindgen]
pub fn caml_do_cool_thingies() {
    do_more_funny_things();
}
```

`#[wasm_bindgen]` indicates Rust that we want to compile the code to WASM and use the function there.
`pub fn caml_do_cool_thingies()` is the name of our "external" function that we are looking for in our OCaml module.

There's one step left! Since we are compiling OCaml to JavaScript using JSOO, we need to tell JSOO how to connect these `external` functions and where to look for them. That's where all these funny little bindings files come in. When compiling OCaml, we tell JSOO to "look at these functions for their correct implementation" - this means we have to write these bindings files to "proxy" OCaml's `external` functions to their implementation. These implementations can be in JavaScript directly, for example something like this

```js
// Provides: caml_do_cool_thingies
function caml_do_cool_thingies() {
  assert(1 + 1 === 2);
}
```

The comment above the function actually tells JSOO what `external` function it _provides_! This way JSOO knows how to connect `external` functions to their implementation. The comments used here have their own little syntax, I would recommend you to check it out in the JSOO docs.

In our case, however, the implementation of the function isn't directly in JavaScript - it is in Rust compiled to WASM! So what we have to do is use these bindings files to point the implementation to WASM, we usually do this by injecting a WASM object or proxy into our bindings layer (see `../web/web_backend.js` and `../node_js/node_backend.js` for their web and node implementations respectively).

We then use this WASM object and "inject" it into our proxy in order to use it.

```js
// Provides: caml_do_cool_thingies
// Requires: plonk_wasm
function caml_do_cool_thingies() {
  plonk_wasm.caml_do_cool_thingies();
}
```

So now instead of using the implementation in JavaScript, we directly call into the Rust implementation that has been compiled to WASM! This means, whenever something in OCaml invokes `FunnyLittleModule.do_cool_thingies` it automatically resolves to `caml_do_cool_thingies` in Rust compiled to WASM.

Previously, these bindings were in one single file `bindings.js` which made it hard to understand. Now, bindings are split into separate files, each with their own responsibilities.

Sometimes, these "proxy" functions actually don't call into WASM directly, but do some pre-computation, like this example:

```js
// Provides: caml_pasta_fp_plonk_proof_create
// Requires: plonk_wasm, tsRustConversion
var caml_pasta_fp_plonk_proof_create = function (
  index,
  witness_cols,
  caml_runtime_tables,
  prev_challenges,
  prev_sgs
) {
  var w = new plonk_wasm.WasmVecVecFp(witness_cols.length - 1);
  for (var i = 1; i < witness_cols.length; i++) {
    w.push(tsRustConversion.fp.vectorToRust(witness_cols[i]));
  }
  witness_cols = w;
  prev_challenges = tsRustConversion.fp.vectorToRust(prev_challenges);
  var wasm_runtime_tables =
    tsRustConversion.fp.runtimeTablesToRust(caml_runtime_tables);
  prev_sgs = tsRustConversion.fp.pointsToRust(prev_sgs);
  var proof = plonk_wasm.caml_pasta_fp_plonk_proof_create(
    index,
    witness_cols,
    wasm_runtime_tables,
    prev_challenges,
    prev_sgs
  );
  return tsRustConversion.fp.proofFromRust(proof);
};
```

So just keep in mind that sometimes it's not as easy to just forward the implementation to WASM and occasionally some more work needs to be done :)
