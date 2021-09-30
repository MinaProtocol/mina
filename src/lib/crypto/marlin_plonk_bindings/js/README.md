This library provides a wrapper around the WebAssembly prover code, which
allows `js_of_ocaml` to compile the mina project against the WebAssembly
backend.

The different versions of the backend are generated in subdirectories; e.g. the
NodeJS backend is generated in `node_js/` and the Chrome backend is generated
in `chrome/`. To use a backend, run `dune build backend/plonk_wasm.js` and copy
`backend/plonk_wasm*` to the project directory.

Note that the backend code is not automatically compiled while linking against
the backend library. You should always manually issue a build command for the
`plonk_wasm.js` for the desired backend to ensure that it has been generated.
For example, to run the tests in the `test/` directory you will need to run
```
dune build test/bindings_js_test.bc.js
dune build node_js/plonk_wasm.js
cd /my/target/directory/
cp ...../test/bindings_js_test.bc.*js .
cp ...../node_js/plonk_wasm* .
```
