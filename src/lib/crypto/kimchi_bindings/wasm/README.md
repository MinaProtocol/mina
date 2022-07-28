# Kimchi WASM

This code allows us to compile parts of Kimchi into [Web Assembly (WASM)](https://webassembly.org/).

## Requirements

For this to work, you will need to install the following dependencies:

* [wasm-pack](https://rustwasm.github.io/wasm-pack/installer/)
* [wasm-bindgen-cli](https://rustwasm.github.io/docs/wasm-bindgen/reference/cli.html)

## Usage

To build for nodejs:

```console
$ wasm-pack build --mode no-install --target nodejs --out-dir ./nodejs ./. -- --features nodejs
```

To build for web browsers:

```console
$ wasm-pack build --mode no-install --target web --out-dir ./web ./.
```

## Resources

* [Rust WASM book](https://rustwasm.github.io/docs/book/game-of-life/hello-world.html)
* [WASM-bindgen book](https://rustwasm.github.io/docs/wasm-bindgen/)
