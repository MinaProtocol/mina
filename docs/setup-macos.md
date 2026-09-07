# Developer Setup (macOS)

Native macOS build instructions. If you'd rather not deal with the system
dependency matrix, [Nix](../nix/README.md) and
[Docker](./setup-docker.md) are both supported alternatives.

## Prerequisites

This guide assumes you have already cloned the repo and pulled in
submodules. If not, see the "Clone the repo" section of
[`README-dev.md`](../README-dev.md).

1. Upgrade to the latest version of macOS.
2. Install Xcode Command Line Tools:

    ```sh
    xcode-select --install
    ```

3. Install [rustup](https://rustup.rs/).

## opam switch

1. Add the o1-labs opam repository:

    ```sh
    opam repository add --yes --all --set-default o1-labs https://github.com/o1-labs/opam-repository.git
    ```

2. Create your switch with deps:

    ```sh
    opam switch import --switch mina opam.export
    ```

### Apple Silicon (M1/M2) caveats

M1- and M2-series machines experience issues because Homebrew does not
link include files automatically.

If you get an error about failing to find `gmp.h`, update your
`~/.zshrc` or `~/.bashrc` with:

```sh
export CFLAGS="-I/opt/homebrew/Cellar/gmp/6.2.1_1/include/"
```

or run:

```sh
env CFLAGS="/opt/homebrew/Cellar/gmp/6.2.1_1/include/" opam install conf-gmp.2
```

If you get an error about failing to find `lmdb.h`, update your shell rc
with:

```sh
export CPATH="$HOMEBREW_PREFIX/include:$CPATH"
export LIBRARY_PATH="$HOMEBREW_PREFIX/lib:$LIBRARY_PATH"
export PATH="$(brew --prefix lmdb)/bin:$PATH"
export PKG_CONFIG_PATH=$(brew --prefix lmdb)/lib/pkgconfig:$PKG_CONFIG_PATH
```

If you get `conf-openssl` install errors, try running:

```sh
export PKG_CONFIG_PATH=$(brew --prefix openssl@1.1)/lib/pkgconfig
opam switch import opam.export
```

If prompted, run `opam user-setup install` to enable opam-user-setup
support for Merlin.

## Pinned dependencies

Pin dependencies that override opam versions:

```sh
scripts/pin-external-packages.sh
```

## Go (libp2p helper)

Install the correct version of Go via `goenv`:

```sh
goenv init
```

To make sure the right `goenv` is used, update your shell env script
with:

```sh
eval "$(goenv init -)"
export PATH="/Users/$USER/.goenv/shims:$PATH"
```

Then install and select the pinned version:

```sh
goenv install 1.18.10
goenv global 1.18.10
```

Verify with `go version`. If you see
`compile:version "go1.18.10" does not match go tool version "go1.20.2"`,
either run `brew remove go` or pick the matching version with goenv.

## Build

```sh
make build
```

If you get errors about `libp2p` and `capnp`, try `brew install capnp`.

## IDE setup (OCaml-LSP, Merlin)

For better IDE support, install the OCaml-LSP language server:

```sh
opam install ocaml-lsp-server
```

For full Merlin / VSCode / Emacs / vim configuration, see the
[IDE setup section](./setup-linux.md#ide-setup-merlin-lsp) in
`setup-linux.md` — the configuration is OS-independent.
