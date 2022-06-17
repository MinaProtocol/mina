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
For example, to run the nodejs tests in the `test/nodejs` directory you will
need to run
```
dune build src/lib/marlin_plonk_bindings/js/test/nodejs/nodejs_test.bc.js
src/lib/marlin_plonk_bindings/js/test/nodejs/copy_over.sh
```
Similarly, to run the chrome tests in `test/chrome`, you can run
```
dune build src/lib/marlin_plonk_bindings/js/test/chrome/chrome_test.bc.js
src/lib/marlin_plonk_bindings/js/test/chrome/copy_over.sh
```
and then visit `http://localhost:8000` from a Chrome browser.
