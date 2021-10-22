This library provides a wrapper around the WebAssembly prover code, which
allows `js_of_ocaml` to compile the mina project against the WebAssembly
backend.

The different versions of the backend are generated in subdirectories; e.g. the
NodeJS backend is generated in `node/` and the Chrome backend is generated in
`chrome/`. To use a backend, run `dune build backend/plonk_wasm.js` and copy
`backend/plonk_wasm*` to the project directory.

Note that the backend code is not automatically compiled while linking against
the backend library. You should always manually issue a build command for the
`plonk_wasm.js` for the desired backend to ensure that it has been generated.

The full SnarkyJS bindings can be found in the parent directory; the bindings
and all associated outputs are stored in-tree in ../outputs, and can be
re-generated using `dune build --auto-promote @../output/build`.
