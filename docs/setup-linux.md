# Developer Setup (Linux)

Native Linux build instructions (Ubuntu-flavoured by default). If you'd
rather not deal with the system dependency matrix,
[Nix](../nix/README.md) and [Docker](./setup-docker.md) are both
supported alternatives.

## Prerequisites

This guide assumes you have already cloned the repo and pulled in
submodules. If not, see the "Clone the repo" section of
[`README-dev.md`](../README-dev.md).

A reasonably recent Ubuntu (or compatible distro) is expected. Mina has
historically been developed against Ubuntu LTS releases.

## System dependencies

Mina has a variety of opam and system dependencies. A number of C
libraries are expected to be available in the system; the canonical list
is what's installed in the
[Dockerfiles](../dockerfiles/). Most of these are installed via `apt`;
RocksDB is installed automatically as a `dune` rule in the
`ocaml-rocksdb` library.

If you need Docker for building containers later (e.g. local Docker
images), follow the official [Docker CE for Ubuntu instructions](https://docs.docker.com/install/linux/docker-ce/ubuntu/).

## opam switch

To get all of the required opam dependencies, run:

```sh
opam repository add --yes --all --set-default o1-labs https://github.com/o1-labs/opam-repository.git
opam switch import opam.export
```

> **Note:** the switch provides a `dune_wrapper` binary that you can use
> instead of `dune` and which fails early if your switch becomes out of
> sync with the `opam.export` file.

Some dependencies that are not taken from `opam` or integrated with
`dune` must be added manually. Run:

```sh
scripts/pin-external-packages.sh
```

## Build

```sh
make build
```

For a quick type-check without a full build:

```sh
dune build @check
```

## IDE setup (Merlin, LSP)

The IDE configuration is OS-independent — these instructions apply on
both Linux and macOS.

### vim

Add this snippet in your `.vimrc` (change the home directory to match
yours):

```vim
let s:ocamlmerlin="/Users/USERNAME/.opam/4.14.2/share/merlin"
execute "set rtp+=".s:ocamlmerlin."/vim"
execute "set rtp+=".s:ocamlmerlin."/vimbufsync"
let g:syntastic_ocaml_checkers=['merlin']
```

Then:

- In your home directory, run `opam init`.
- In this shell, `eval $(opam config env)`.
- Install autocomplete dependencies:
  `opam install merlin ocp-indent core async ppx_jane ppx_deriving`.
- Make sure you have `au FileType ocaml set omnifunc=merlin#Complete` in
  your `.vimrc`.
- Install an auto-completer (such as YouCompleteMe) and a syntastic
  (such as syntastic or ALE).

### Emacs

Install the `opam` packages mentioned above and also install `tuareg`.
Add the following to your `.emacs` file:

```lisp
(let ((opam-share (ignore-errors (car (process-lines "opam" "var" "share")))))
  (when (and opam-share (file-directory-p opam-share))
    ;; Register Merlin
    (add-to-list 'load-path (expand-file-name "emacs/site-lisp" opam-share))
    (load "tuareg-site-file")
    (autoload 'merlin-mode "merlin" nil t nil)
    ;; Automatically start it in OCaml buffers
    (add-hook 'tuareg-mode-hook 'merlin-mode t)
    (add-hook 'caml-mode-hook 'merlin-mode t)))
```

To use the Emacs built-in autocomplete, use `M-x completion-at-point` or
`M-tab`. There are other Emacs autocompletion packages; see
[Emacs from scratch](https://github.com/ocaml/merlin/wiki/emacs-from-scratch).

### VSCode

- Make sure you're in the right opam switch (`mina`).
- Add the [OCaml Platform](https://marketplace.visualstudio.com/items?itemName=ocamllabs.ocaml-platform)
  extension.
- You might get a prompt to install `ocaml-lsp-server` in the Sandbox —
  accept.
- You might get a prompt to install `ocamlformat-rpc` in the Sandbox —
  accept.
- Type "shell command:install code command in PATH".
- Close all windows and instances of VSCode.
- From terminal, in your mina directory, run `code .`.
- Run `dune build` in the terminal inside VSCode.
