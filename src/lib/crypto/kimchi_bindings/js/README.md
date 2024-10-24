This library provides a wrapper around the WebAssembly prover code, which
allows `js_of_ocaml` to compile the mina project against the WebAssembly
backend. This means that `external` OCaml functions now know what implementation to point to. See `./bindings/README.md` for more details.

The different versions of the backend are generated in subdirectories; e.g. the
NodeJS backend is generated in `node_js/` and the Web backend is generated
in `web/`. To use a backend, run `dune build **backend**/plonk_wasm.js` (where `**backend**` is either `web` or `node_js`) and copy `**backend**/plonk_wasm*` to the project directory.
