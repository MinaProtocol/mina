# Mina README-dev

Mina is a cryptocurrency protocol with a lightweight, constant-sized blockchain.

- [Node Developers Overview](https://docs.minaprotocol.com/node-developers)
- [Mina README](README.md)

For information about our development process and how to contribute, see [CONTRIBUTING.md](CONTRIBUTING.md). If you want to build
Mina, this is the right file!

## Building Mina

Building Mina is involved because many C library dependencies must be present in the system. Furthermore, these libraries need to be in correct versions, or else the system will fail to build. OCaml-specific setup is also required. Therefore, it is recommended to build Mina with Nix, which offers a great help in managing these dependencies. Manual dependency management is fragile and prone to break with every system update.

If you are already a Nix user, or are comfortable installing Nix, you already have a way to build Mina locally. For information and
instructions, see [nix/README.md](./nix/README.md).

Mina builds and runs on Linux and macOS.

Quick start instructions:

1.  Start with Ubuntu 18 or run it in a virtual machine
2.  Clone the Mina repository (if you have not done that already):

    ```sh
    git clone git@github.com:MinaProtocol/mina.git
    ```

    If you have already done that, remember that the MinaProtocol and o1-labs repositories do not accept the password authentication used by the https URLs. You must set GitHub repos to pull and push over ssh:

    ```sh
    git config --global url.ssh://git@github.com/.insteadOf https://github.com/
    ```

3.  Pull in the submodules:

    ```sh
    git submodule update --init --recursive
    ```

    If this command fails with `git@github.com: Permission denied (publickey).` then you need to set up SSH keys on your machine. Follow the [Generating a new SSH key and adding it to the ssh-agent](https://help.github.com/en/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) instructions.

4.  Run:

    ```sh
    git config --local --add submodule.recurse true
    ```

### Developer Setup (Docker)

You can build Mina using Docker. Using Docker works in any dev environment. See [/dev](https://github.com/MinaProtocol/mina/tree/develop/dev).

### Developer Setup (MacOS)

1. Upgrade to the latest version of macOS.
2. Install Xcode Command Line Tools:

    ```sh
    xcode-select --install
    ```

3. Invoke `make macos-setup`.

   - When prompted, confirm that you want to add a number of exports in your shell config file.
   - Make sure to `source` your shell config file or create a new terminal.
   - If this is your first time using OCaml, be sure to run:

        ```sh
        eval $(opam config env)
        ```

1. Install [rustup](https://rustup.rs/).
2. Create your switch with deps `opam switch import --switch mina opam.export`

    M1- and M-2 operating systems experience issues because Homebrew does not link include files automatically.
  
    If you get an error about failing to find `gmp.h`, update your `~/.zshrc` or `~/.bashrc` with:

    ```sh
    export CFLAGS="-I/opt/homebrew/Cellar/gmp/6.2.1_1/include/"
    ```

    or run:

    ```sh
    env CFLAGS="/opt/homebrew/Cellar/gmp/6.2.1_1/include/" opam install conf-gmp.2
    ```

    If you get an error about failing to find `lmdb.h`, update your `~/.zshrc` or `~/.bashrc` with:

    ```text
    export CPATH="$HOMEBREW_PREFIX/include:$CPATH"
    export LIBRARY_PATH="$HOMEBREW_PREFIX/lib:$LIBRARY_PATH"
    export PATH="$(brew --prefix lmdb)/bin:$PATH"
    export PKG_CONFIG_PATH=$(brew --prefix lmdb)/lib/pkgconfig:$PKG_CONFIG_PATH
    ```

   - Note:If you get conf-openssl install errors, try running `export PKG_CONFIG_PATH=$(brew --prefix openssl@1.1)/lib/pkgconfig` and try `opam switch import opam.export` again.
   - If prompted, run `opam user-setup install` to enable opam-user-setup support for Merlin.

3. Pin dependencies that override opam versions:

    ```sh
    scripts/pin-external-packages.sh
    ```

7. Install the correct version of golang:

   - `goenv init`
   - To make sure the right `goenv` is used, update your shell env script with:

        ```text
        eval "$(goenv init -)"
        export PATH="/Users/$USER/.goenv/shims:$PATH"
        ```

   - `goenv install 1.18.10`
   - `goenv global 1.18.10`
   - Check that the `go version` returns the right version, otherwise you see the message `compile:version "go1.18.10" does not match go tool version "go1.20.2"`. If so, run `brew remove go` or get the matching version.

9.  Invoke `make build`.

    If you get errors about `libp2p` and `capnp`, try with `brew install capnp`.

9.  For better IDE support, install the OCaml-LSP language server for OCaml:

    ```sh
    opam install ocaml-lsp-server
    ```

10. Set up your IDE. See [Customizing your dev environment for autocomplete/merlin](https://github.com/MinaProtocol/mina/blob/develop/README-dev.md#customizing-your-dev-environment-for-autocompletemerlin).

### Developer Setup (Linux)

#### Building

Mina has a variety of opam and system dependencies.

To get all of the required opam dependencies, run:

```sh
opam switch import opam.export
```

**NOTE**: The `switch` command provides a `dune_wrapper` binary that you can use instead of dune and fails early if your switch becomes out of sync with the `opam.export` file.

Some dependencies that are not taken from `opam` or integrated with `dune` must be added manually. Run the `scripts/pin-external-packages.sh` script.

A number of C libraries are expected to be available in the system and are also listed in the Dockerfiles. Unlike most of the C libraries that are installed using `apt` in the Dockerfiles, the libraries for RocksDB are automatically installed when building Mina by using a `dune` rule in the library `ocaml-rocksdb`.

#### Setup Docker CE on Ubuntu

- [Ubuntu Setup Instructions](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

#### Customizing your dev environment for autocomplete/merlin

If you use vim, add this snippet in your `.vimrc` file to use Merlin. (Note:Be sure to change the HOME directory to match yours.)

```bash
let s:ocamlmerlin="/Users/USERNAME/.opam/4.07/share/merlin"
execute "set rtp+=".s:ocamlmerlin."/vim"
execute "set rtp+=".s:ocamlmerlin."/vimbufsync"
let g:syntastic_ocaml_checkers=['merlin']
```

- In your home directory `opam init`
- In this shell, `eval $(opam config env)`
- Now `/usr/bin/opam install merlin ocp-indent core async ppx_jane ppx_deriving` (everything we depend on that you want autocompletes for) for doc reasons
- Make sure you have `au FileType ocaml set omnifunc=merlin#Complete` in your `.vimrc`
- Install an auto-completer (such as YouCompleteMe) and a syntastic (such syntastic or ALE)

- If you use emacs, install the `opam` packages mentioned above and also install `tuareg`. Add the following to your `.emacs` file:

    ```lisp
    (let ((opam-share (ignore-errors (car (process-lines "opam" "config" "var" "share")))))
      (when (and opam-share (file-directory-p opam-share))
        ;; Register Merlin
        (add-to-list 'load-path (expand-file-name "emacs/site-lisp" opam-share))
        (load "tuareg-site-file")
        (autoload 'merlin-mode "merlin" nil t nil)
        ;; Automatically start it in OCaml buffers
        (add-hook 'tuareg-mode-hook 'merlin-mode t)
        (add-hook 'caml-mode-hook 'merlin-mode t)))
    ```

    To use the Emacs built-in autocomplete, use `M-x completion-at-point` or `M-tab`. There are other
    Emacs autocompletion packages; see [Emacs from scratch](https://github.com/ocaml/merlin/wiki/emacs-from-scratch).

- If you use VSCode, set up Merlin to work inside VSCode:
  - Make sure to be in the right switch (mina)
  - Add the [OCaml Platform](https://marketplace.visualstudio.com/items?itemName=ocamllabs.ocaml-platform) extension
  - You might get a prompt to install `ocaml-lsp-server` as well in the Sandbox
  - You might get a prompt to install `ocamlformat-rpc` as well in the Sandbox
  - Type "shell command:install code command in PATH"
  - Close all windows and instances of VSCode
  - From terminal, in your mina directory, run `code .`
  - Run `dune build` in the terminal inside VSCode

## Running a node

The source code for the Mina node is located in `src/app/cli/`. After it is compiled, you can run the compiled binary like this:

```shell
dune exec src/app/cli/src/mina.exe -- daemon --libp2p-keypair /path/to/key
```

The results of a successful build appear in `_build/default/src/app/cli/src/mina.exe`.

The default configuration of the node depends on the build profile that is used during compilation. To connect to some networks, you need to compile the daemon with a specific profile.

*Some setup is required*:

Generate a key pair so that the daemon can create an account to issue blocks from using the same `mina.exe` binary:

```shell
dune exec src/app/cli/src/mina.exe -- libp2p generate-keypair --privkey-path /path/to/key
```

When prompted, enter a passphrase. During development, you can leave it blank for convenience, but using a passphrase is strongly encouraged when running a real node!

The running daemon expects to find this passphrase in
an environment variable `MINA_LIBP2P_PASS`, which must be defined even if the passphrase is empty.
The `/path/to/key` must belong to the user running the daemon. Set these filesystem permissions:

```shell
chmod 0600 /path/to/key
chmod 0700 /path/to
```

Additionally, you must provide a list of peers to connect to bootstrap the node.
The list of peers depends on the network you want to connect to and is announced when the network is being launched. For Mainnet, see the [list of peers](https://storage.googleapis.com/mina-seed-lists/mainnet_seeds.txt).

The `daemon.json` config file also contains bootstrap data that is specific to the network the node is trying to connect to and must be tailored specifically for a particular network. This file can also override some of the configuration options selected during compilation. The `daemon.json` file can be extracted from the Docker image
that is dedicated to running a particular network. If it's not located in the `config` directory, it can be pointed to with `--config-file` option.

The aforementioned bootstrap data includes the genesis ledger, i.e. the initial state of the blockchain. It is crucial for all the nodes on the network to have the same genesis ledger. While starting a new network, it is important that it contains at least one account possessing some funds. Otherwise, the network will not be able to bootstrap, as there will be no way to determine the next block producer.

When all of this setup is complete, you can launch the daemon. The following command assumes the key passphrase is set to `pass`:

```shell
MINA_LIBP2P_PASS=pass dune exec src/app/cli/src/mina.exe -- daemon --libp2p-keypair /path/to/key --peer-list-url https://example.peer.list --config-file /custom/path/to/daemon.json
```

The `--seed` flag tells the daemon to run a fresh network of its own. When this flag is used, specifying a peer list is not required, but is still possible. With `--seed` option the node does not crash, even if it does not manage to connect to any peers. To learn more, see the command line help:

```shell
dune exec src/app/cli/src/mina.exe -- -help
```

The command line help is the place to learn about other options to the Mina CLI and how to connect to an existing network, such as Mainnet.

## Using the Makefile

The Makefile contains placeholder targets for all the common tasks that need to be done and automatically knows how to use Docker.

The most important `make` targets are:

- `build`: build everything
- `build_intgtest`: build the [`test_executive`](./src/app/test_executive/README.md#using-lucy) for running integration tests
- `libp2p_helper`: build the [`libp2p_helper`](./src/app/libp2p_helper/README.md)
- `reformat`: automatically use `ocamlformat` to reformat the source files (use it if the hook fails during a commit)

We use the [Dune](https://github.com/ocaml/dune/) build system for OCaml code.

## Steps for adding a new OCaml dependency

OCaml dependencies live in the [`opam.export`](./opam.export) file. This file is machine generated and must not be modified.

To add a new dependency, you most likely will need to create a new fresh switch to avoid pushing in any local dependency (like `ocaml-lsp`). The following commands assume that the version of the OCaml compiler used in the codebase is 4.14.0:

```shell
opam switch create mina_fresh 4.14.0
opam switch import opam.export
```

After that, install your dependency. You might have to specify versions of current dependencies to avoid having to upgrade  dependencies. For example:

```sh
opam install alcotest cmdliner=1.0.3 fmt=0.8.6
```

Then, run the following command to update the `ocaml.export` file:

```sh
opam switch export opam.export
```

## Steps for adding a new OCaml pinned dependency

Rarely, you may edit one of our forked opam-pinned packages, or add a new system
dependency (like libsodium). Some of the pinned packages are git submodules,
others inhabit the git Mina repository.

If an existing pinned package is updated, either in the Mina repository or in the
the submodule's repository, it is automatically re-pinned in CI.

If you add a new package in the Mina repository or as a submodule, you must do all of the following:

1. Update [`scripts/macos-setup.sh`](scripts/macos-setup.sh) with the required commands for Darwin systems
2. Update [`dockerfiles/stages/`](dockerfiles/stages) with the required packages

## Common Dune tasks

To run unit tests for a single library, do `dune runtest lib/$LIBNAME`.

You might see a build error like this:

```text
Error:Files src/lib/mina_base/mina_base.objs/account.cmx
       and src/lib/mina_base/mina_base.objs/token_id.cmx
       make inconsistent assumptions over implementation Crypto_params
```

You can work around it with `rm -r src/_build/default/src/$OFFENDING_PATH` and a rebuild.
Here, the offending path is `src/lib/mina_base/mina_base.objs`.

## Overriding Genesis Constants

Mina genesis constants consists of constants for the consensus algorithm, sizes for various data structures like transaction pool, scan state, ledger, etc.
All the constants can be set at compile-time. A subset of the compile-time constants can be overridden when generating the genesis state using `runtime_genesis_ledger.exe`. A subset of those constants can again be overridden at runtime by passing the new values to the daemon.

The constants at compile-time are set for different configurations using optional compilation. This is how integration tests and builds with multiple configurations are run.
Some of these constants defined in [mina_compile_config.ml](src/lib/mina_compile_config/mina_compile_config.ml) cannot be changed after building and require creating a new build profile (`\*.mlh` files) for any change in the values.

<b> 1. Constants that can be overridden when generating the genesis state are:</b>

- k (consensus constant)
- delta (consensus constant)
- genesis_state_timestamp
- transaction pool max size

To override these constants, pass a json file to `runtime_genesis_ledger.exe` with the format:

```json
{
  "k":10,
  "delta":3,
  "txpool_max_size":3000,
  "genesis_state_timestamp":"2020-04-20 11:00:00-07:00"
}
```

The exe then packages the overridden constants along with the genesis ledger and the genesis proof for the daemon to consume.

<b> 2. Constants that can be overriden at runtime are:</b>

- genesis_state_timestamp
- transaction pool max size

To do this, pass a json file to the daemon using the flag `genesis-constants` with the format:

```json
{
  "txpool_max_size":3000,
  "genesis_state_timestamp":"2020-04-20 11:00:00-07:00"
}
```

The daemon logs reflect these changes and `mina client status` displays some of the constants.
