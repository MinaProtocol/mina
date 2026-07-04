This library provides a wrapper around the Kimchi prover code, which allows
`js_of_ocaml` to compile the mina project against a JavaScript-provided
backend. This means that `external` OCaml functions now know what
implementation to point to. See `./bindings/README.md` for more details.

The Rust prover is compiled by the **kimchi-napi** crate (napi-rs), both as a
native `.node` addon and as a `wasm32-wasip1-threads` module (loaded via
`@napi-rs/wasm-runtime`). The backend stubs in `node_js/` and `web/` do not
load the FFI module themselves anymore: they read it from
`globalThis.__o1js_kimchi_ffi`, which the consuming loader (e.g. o1js's
`node-backend.js` / `web-backend.js` / `native-backend.js`) installs before
evaluating the compiled js_of_ocaml artifact.

The previous wasm-bindgen backend (`kimchi-wasm` crate, built here via
wasm-pack into `node_js/kimchi_wasm.js` and `web/kimchi_wasm.js`) has been
removed.

To run the nodejs tests in the `test/nodejs` directory you will need to run

```
dune build src/lib/crypto/kimchi_bindings/js/test/nodejs/nodejs_test.bc.js
src/lib/crypto/kimchi_bindings/js/test/nodejs/copy_over.sh
```

Similarly, to run the web tests in `test/web`, you can run

```
dune build src/lib/crypto/kimchi_bindings/js/test/web/web_test.bc.js
src/lib/crypto/kimchi_bindings/js/test/web/copy_over.sh
```

and then visit `http://localhost:8000` from a browser.

Note that the test harnesses require a `kimchi_ffi` module to be installed on
`globalThis.__o1js_kimchi_ffi` before the compiled artifact is evaluated (see
above); they were previously hard-wired to the removed wasm-bindgen backend.
