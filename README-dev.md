# Mina

Mina is a new cryptocurrency protocol with a lightweight, constant-sized blockchain.

- [Node Developer homepage](https://docs.minaprotocol.com/en/node-developers)
- [Repository Readme](README.md)

If you haven't seen it yet, [CONTRIBUTING.md](CONTRIBUTING.md) has information
about our development process and how to contribute. If you just want to build
Mina, this is the right file!

## Building Mina

Building Mina can be slightly involved. There are many C library dependencies that need
to be present in the system, as well as some OCaml-specific setup.

If you are already a Nix user, or are comfortable installing Nix, it
can be an easy way to build Mina locally. See
[nix/README.md](./nix/README.md) for more information and
instructions.

Currently, Mina builds/runs on Linux & macOS. MacOS may have some issues that you can track [here](https://github.com/MinaProtocol/coda/issues/962).

The short version:

1.  Start with Ubuntu 18 or run it in a virtual machine
2.  Set github repos to pull and push over ssh: `git config --global url.ssh://git@github.com/.insteadOf https://github.com/`
    - To push branches to repos in the MinaProtocol or o1-labs organisations, you must complete this step. These repositories do not accept the password authentication used by the https URLs.
3.  Pull in our submodules: `git submodule update --init --recursive`
    - This might fail with `git@github.com: Permission denied (publickey).`. If that happens it means
      you need to [set up SSH keys on your machine](https://help.github.com/en/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).
4.  Run `git config --local --add submodule.recurse true`

### Developer Setup (Docker)

You can build Mina using Docker. This should work in any dev environment.
Refer to [/dev](/dev).

### Developer Setup (MacOS)

- Invoke `make macos-setup`
  - If this is your first time using OCaml, be sure to run `eval $(opam config env)`
- Invoke `rustup toolchain install 1.63.0`
- Invoke `make build`
- Jump to [customizing your editor for autocomplete](#customizing-your-dev-environment-for-autocompletemerlin)
- Note: If you are seeing conf-openssl install errors, try running `export PKG_CONFIG_PATH=$(brew --prefix openssl@1.1)/lib/pkgconfig` and try `opam switch import opam.export` again.

### Developer Setup (Linux)

#### Building

Mina has a variety of opam and system dependencies.

To get all the opam dependencies you need, you run `opam switch import opam.export`.
> *_NOTE:_*  The switch provides a `dune_wrapper` binary that you can use instead of dune, and will fail early if your switch becomes out of sync with the `opam.export` file.

Some of our dependencies aren't taken from `opam`, and aren't integrated
with `dune`, so you need to add them manually, by running `scripts/pin-external-packages.sh`.

There are a variety of C libraries we expect to be available in the system.
These are also listed in the dockerfiles. Unlike most of the C libraries,
which are installed using `apt` in the dockerfiles, the libraries for RocksDB are
automatically installed when building Mina via a `dune` rule in the library
ocaml-rocksdb.

#### Setup Docker CE on Ubuntu

- [Ubuntu Setup Instructions](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

#### Customizing your dev environment for autocomplete/merlin
[dev-env]: #dev-env

- If you use vim, add this snippet in your vimrc to use merlin. (REMEMBER to change the HOME directory to match yours)

```bash
let s:ocamlmerlin="/Users/USERNAME/.opam/4.07/share/merlin"
execute "set rtp+=".s:ocamlmerlin."/vim"
execute "set rtp+=".s:ocamlmerlin."/vimbufsync"
let g:syntastic_ocaml_checkers=['merlin']
```

- In your home directory `opam init`
- In this shell, `eval $(opam config env)`
- Now `/usr/bin/opam install merlin ocp-indent core async ppx_jane ppx_deriving` (everything we depend on, that you want autocompletes for) for doc reasons
- Make sure you have `au FileType ocaml set omnifunc=merlin#Complete` in your vimrc
- Install an auto-completer (such as YouCompleteMe) and a syntastic (such syntastic or ALE)
- If you use vscode, you might like this extension

  - [OCaml and Reason IDE](https://marketplace.visualstudio.com/items?itemName=freebroccolo.reasonml)
  - [OCaml Platform](https://marketplace.visualstudio.com/items?itemName=ocamllabs.ocaml-platform)

- If you use emacs, besides the `opam` packages mentioned above, also install `tuareg`, and add the following to your .emacs file:

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

Emacs has a built-in autocomplete, via `M-x completion-at-point`, or simply `M-tab`. There are other
Emacs autocompletion packages; see [Emacs from scratch](https://github.com/ocaml/merlin/wiki/emacs-from-scratch).

## Running a node

The source code for the Mina node is located in src/app/cli/. Once it is compiled, it can be run like this:

```shell
$ dune exec src/app/cli/src/mina.exe -- daemon --libp2p-keypair /path/to/key
```

Please note, that default configuration of the node depends on the build profile
used during compilation, so in order to connect to some networks it might be
necessary to compile the daemon with a specific profile.

Before this can be done, however, some setup is required. First a key
pair needs to be generated so that the daemon can create an account to
issue blocks from. This can be done using the same `mina.exe` binary:

```shell
$ dune exec src/app/cli/src/mina.exe -- libp2p generate-keypair --privkey-path /path/to/key
```

The program will ask you for a passphrase, which can be left blank for convenience (of course this is
highly discouraged when running a real node!). The running daemon expects to find this passphrase in
an environment variable `MINA_LIBP2P_PASS`, which needs to be defined even if the passphrase is empty.
Furthermore, `/path/to/key` needs to belong to the user running the daemon and to have filesystem
permissions set to `0600`. Also the directory containing the file (`/path/to`) needs its permissions
set to `0700`.

```shell
$ chmod 0600 /path/to/key
$ chmod 0700 /path/to
```

Additionally, it's necessary to provide a list of peers to connect to to bootstrap the node.
The list of peers depends on the network one wants to connect to and is announces when the
network is being launched. For mainnet the list can be found at:
https://storage.googleapis.com/mina-seed-lists/mainnet_seeds.txt .

Moreover, `daemon.json` config file also contains some bootstrap data specific to the network
the node is trying to connect to. Therefore it also needs to be tailored specifically for
a particular network. This file can also override some of the configuration options selected
during compilation (see above). At the moment it can be extracted from the docker image
dedicated to running a particular network. If it's not located in the config directory,
it can be pointed to with `--config-file` option.

When all of this setup is complete, the daemon can be launched (assuming the key passphrase was set to "pass"):

```shell
$ MINA_LIBP2P_PASS=pass dune exec src/app/cli/src/mina.exe -- daemon --libp2p-keypair /path/to/key --peer-list-url https://example.peer.list --config-file /custom/path/to/daemon.json
```

The `--seed` flag tells the daemon to run a fresh network of its own. In that case specifying
a peer list is not necessary, but still possible. With `--seed` option the node will
not crash, even if it does not manage to connect to any peers. See:

```shell
$ dune exec src/app/cli/src/mina.exe -- -help
```

to learn about other options to the CLI app and how to connect to an existing network, such
as mainnet.

## Using the Makefile

The makefile contains phony targets for all the common tasks that need to be done.
It also knows how to use Docker automatically. 

These are the most important `make` targets:

- `build`: build everything
- `libp2p_helper`: build the libp2p helper
- `reformat`: automatically use `ocamlformat` to reformat the source files (use
    it if the hook fails during a commit)

We use the [dune](https://github.com/ocaml/dune/) buildsystem for our OCaml code.

## Steps for adding a new dependency

Rarely, you may edit one of our forked opam-pinned packages, or add a new system
dependency (like libsodium). Some of the pinned packages are git submodules,
others inhabit the git Mina repository.

If an existing pinned package is updated, either in the Mina repository or in the
the submodule's repository, it will be automatically re-pinned in CI.

If you add a new package in the Mina repository or as a submodule, you must do all of the following:

1. Update [`scripts/macos-setup.sh`](scripts/macos-setup.sh) with the required commands for Darwin systems
2. Update [`dockerfiles/stages/`](dockerfiles/stages) with the required packages

## Common dune tasks

To run unit tests for a single library, do `dune runtest lib/$LIBNAME`.

You might see a build error like this:

```text
Error: Files src/lib/mina_base/mina_base.objs/account.cmx
       and src/lib/mina_base/mina_base.objs/token_id.cmx
       make inconsistent assumptions over implementation Crypto_params
```

You can work around it with `rm -r src/_build/default/src/$OFFENDING_PATH` and a rebuild.
Here, the offending path is `src/lib/mina_base/mina_base.objs`.

## Overriding Genesis Constants

Mina genesis constants consists of constants for the consensus algorithm, sizes for various data structures like transaction pool, scan state, ledger etc.
All the constants can be set at compile-time. A subset of the compile-time constants can be overriden when generating the genesis state using `runtime_genesis_ledger.exe`, and a subset of those can again be overridden at runtime by passing the new values to the daemon.

The constants at compile-time are set for different configurations using optional compilation. This is how integration tests/builds with multiple configurations are run.
Currently some of these constants (defined [here](src/lib/mina_compile_config/mina_compile_config.ml)) cannot be changed after building and would require creating a new build profile (\*.mlh files) for any change in the values.

<b> 1. Constants that can be overridden when generating the genesis state are:</b>

- k (consensus constant)
- delta (consensus constant)
- genesis_state_timestamp
- transaction pool max size

To override the above listed constants, pass a json file to `runtime_genesis_ledger.exe` with the format:

```json
{
  "k": 10,
  "delta": 3,
  "txpool_max_size": 3000,
  "genesis_state_timestamp": "2020-04-20 11:00:00-07:00"
}
```

The exe will then package the overriden constants along with the genesis ledger and the genesis proof for the daemon to consume.

<b> 2. Constants that can be overriden at runtime are:</b>

- genesis_state_timestamp
- transaction pool max size

To do this, pass a json file to the daemon using the flag `genesis-constants` with the format:

```json
{
  "txpool_max_size": 3000,
  "genesis_state_timestamp": "2020-04-20 11:00:00-07:00"
}
```

The daemon logs should reflect these changes. Also, `mina client status` displays some of the constants.
