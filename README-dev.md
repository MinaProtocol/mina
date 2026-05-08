# Mina developer guide

Mina is a cryptocurrency protocol with a lightweight, constant-sized
blockchain. This file is the **index** for developer documentation —
each topic links out to a focused page under [`docs/`](./docs/) or
elsewhere in the repo.

If you maintain protocol terminology questions ("what is a scan state?"
"what is `k`?"), the canonical glossary lives at
[`docs/GLOSSARY.md`](./docs/GLOSSARY.md).

For information about our development process and how to contribute,
see [`CONTRIBUTING.md`](./CONTRIBUTING.md).

---

## First 30 minutes

The recommended path for a brand-new contributor:

1. **Clone the repo and submodules.**

    ```sh
    git clone git@github.com:MinaProtocol/mina.git
    cd mina
    git submodule update --init --recursive
    git config --local --add submodule.recurse true
    ```

    > **Note on SSH:** the `MinaProtocol` and `o1-labs` repositories do
    > not accept the password authentication used by `https://` URLs. If
    > you've cloned over HTTPS, switch to SSH globally:
    >
    > ```sh
    > git config --global url.ssh://git@github.com/.insteadOf https://github.com/
    > ```
    >
    > If `git submodule update` fails with
    > `git@github.com: Permission denied (publickey)`, set up an SSH
    > key: [Generating a new SSH key](https://help.github.com/en/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).

2. **Pick your build environment.** Most contributors should pick
   exactly one of these:

    - **[Nix](./nix/README.md)** — *recommended.* Manages the C library
      + OCaml dependency matrix for you; the same setup that CI uses.
    - **[Linux native](./docs/setup-linux.md)** — Ubuntu / Debian /
      compatible distros; you manage the system dependencies.
    - **[macOS native](./docs/setup-macos.md)** — Homebrew-based; pay
      attention to the Apple Silicon caveats.
    - **[Docker](./docs/setup-docker.md)** — works anywhere; isolates
      the toolchain.

3. **Build:** `make build` (allow ~10–20 minutes the first time; needs
   ~10 GB RAM).

4. **Run the test suite for one library** so you know the toolchain
   works end-to-end:

    ```sh
    dune runtest src/lib/mina_base
    ```

5. **Configure your editor** — set up Merlin / OCaml-LSP per the
   [IDE section](./docs/setup-linux.md#ide-setup-merlin-lsp) (works on
   Linux and macOS).

6. **Read [`CLAUDE.md`](./CLAUDE.md)** for an architectural orientation
   and a list of the most-used `make` and `dune` commands.

That should leave you with a working dev environment and enough context
to find your way around the codebase.

---

## Topic index

### Setup

| Path | Page |
|---|---|
| Native, Linux | [docs/setup-linux.md](./docs/setup-linux.md) |
| Native, macOS | [docs/setup-macos.md](./docs/setup-macos.md) |
| Docker dev environment | [docs/setup-docker.md](./docs/setup-docker.md) |
| Nix dev environment | [nix/README.md](./nix/README.md) |
| IDE / Merlin / LSP / VSCode / Emacs / vim | [docs/setup-linux.md § IDE setup](./docs/setup-linux.md#ide-setup-merlin-lsp) |

### Building & packaging

| Topic | Page |
|---|---|
| Build a Debian package locally | [docs/build-debian-locally.md](./docs/build-debian-locally.md) |
| Build a Docker image locally | [docs/build-docker-locally.md](./docs/build-docker-locally.md) |
| `make` reference | [Using the Makefile](#using-the-makefile) (below) |
| Adding a Buildkite CI job | [buildkite/HOWTO-add-a-job.md](./buildkite/HOWTO-add-a-job.md) |

### Running

| Topic | Page |
|---|---|
| Run a Mina daemon | [docs/daemon.md](./docs/daemon.md) (also see [Running a node](#running-a-node) below for the brief version) |
| Local demo daemon | [docs/demo.md](./docs/demo.md) |
| Mina via Docker | [docs/docker.md](./docs/docker.md) |

### Reference

| Topic | Page |
|---|---|
| Mina-specific terminology | [docs/GLOSSARY.md](./docs/GLOSSARY.md) |
| Branching policy | [README-branching.md](./README-branching.md) |
| Tests overview | [docs/tests.md](./docs/tests.md) |
| Environment variables | [docs/environment-variables.md](./docs/environment-variables.md) |
| Overriding genesis constants | [docs/genesis-constants.md](./docs/genesis-constants.md) |
| Tracing | [docs/tracing.md](./docs/tracing.md) |

---

## Running a node

The source code for the Mina node is in `src/app/cli/`. After it's
compiled, you can run the binary directly with dune:

```sh
dune exec src/app/cli/src/mina.exe -- daemon --libp2p-keypair /path/to/key
```

The build artifact lives at `_build/default/src/app/cli/src/mina.exe`.

The default configuration depends on the build profile selected at
compile time; to connect to a specific public network you typically need
to compile with the matching profile. See
[`docs/GLOSSARY.md` § Profiles](./docs/GLOSSARY.md#profiles-dev-devnet-mainnet-lightnet).

### Setup

Generate a libp2p keypair:

```sh
dune exec src/app/cli/src/mina.exe -- libp2p generate-keypair --privkey-path /path/to/key
```

When prompted, enter a passphrase. During development you may leave it
blank for convenience, but a real passphrase is strongly recommended for
production-style runs.

The daemon expects to find the passphrase in the `MINA_LIBP2P_PASS`
environment variable, which must be defined even if the passphrase is
empty. The keypair file must belong to the user running the daemon:

```sh
chmod 0600 /path/to/key
chmod 0700 /path/to
```

Provide a peer list to bootstrap the node. For Mainnet:
<https://storage.googleapis.com/mina-seed-lists/mainnet_seeds.txt>.

The `daemon.json` config file contains network-specific bootstrap data
(genesis ledger, network-specific overrides). It can be extracted from
the Docker image dedicated to a particular network. Pass with
`--config-file` if it isn't auto-discovered in `config/`.

### Launch

Assuming the key passphrase is `pass`:

```sh
MINA_LIBP2P_PASS=pass dune exec src/app/cli/src/mina.exe -- daemon \
  --libp2p-keypair /path/to/key \
  --peer-list-url https://example.peer.list \
  --config-file /custom/path/to/daemon.json
```

The `--seed` flag tells the daemon to run a fresh network of its own; a
peer list is then optional. For full CLI help:

```sh
dune exec src/app/cli/src/mina.exe -- -help
```

For more on the daemon, RPC interface, and config file format see
[`docs/daemon.md`](./docs/daemon.md).

---

## Using the Makefile

The Makefile contains placeholder targets for the most common tasks and
knows how to use Docker where helpful. Most-used targets:

- `build` — build the Mina binary
- `build_intgtest` — build [`test_executive`](./src/app/test_executive/) for integration tests
- `libp2p_helper` — build the [`libp2p_helper`](./src/app/libp2p_helper/)
- `reformat` — run `ocamlformat` over the source tree (use this if the
  pre-commit hook fails)
- `reformat-diff` — format only modified files (recommended after edits)

For the full target list and dune internals, see [`CLAUDE.md`](./CLAUDE.md).

We use the [Dune](https://github.com/ocaml/dune/) build system for OCaml
code.

---

## Adding a new OCaml dependency

OCaml dependencies live in [`opam.export`](./opam.export). This file is
machine-generated and must not be edited by hand.

To add a new dependency, create a fresh switch to avoid pulling in any
local extras (like `ocaml-lsp`). The codebase uses OCaml 4.14.2:

```sh
opam switch create mina_fresh 4.14.2
opam switch import opam.export
```

Then install your dependency. You may need to specify versions of
existing dependencies to avoid forced upgrades:

```sh
opam install alcotest cmdliner=1.0.3 fmt=0.8.6
```

Re-export the switch:

```sh
opam switch export opam.export
```

### Pinned packages and system dependencies

Some packages are pinned via git submodules or live in this repository.
If an existing pinned package is updated (in this repo or in a
submodule), CI re-pins it automatically.

If you add a new package in this repo or as a new submodule, you must
also update [`dockerfiles/toolchain/`](./dockerfiles/toolchain) with the
required system packages.

---

## Common dune tasks

To run unit tests for a single library: `dune runtest src/lib/$LIBNAME`.

You may occasionally see a build error of the form:

```text
Error: Files src/lib/mina_base/mina_base.objs/account.cmx
       and src/lib/mina_base/mina_base.objs/token_id.cmx
       make inconsistent assumptions over implementation Crypto_params
```

Workaround: `rm -r src/_build/default/src/$OFFENDING_PATH` and rebuild.
In the example above, `$OFFENDING_PATH` is
`src/lib/mina_base/mina_base.objs`.

For more on tests, see [`docs/tests.md`](./docs/tests.md).
