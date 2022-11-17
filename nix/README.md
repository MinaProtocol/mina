# Building Mina using Nix

Nix is a declarative package manager for Linux, macOS and other
UNIX-like systems. You can read more about Nix on its [official
website](https://nixos.org).

Mina can be built using Nix, in multiple ways. Follow the steps below to get
started and read the [troubleshooting section](#troubleshooting) if you
encounter any problem.

<details>
<summary>TL;DR for those who know Nix</summary>

This is a flake. It provides a lot of different packages from the monorepo. Most
of those packages require submodules to build. To simplify your life, there's
`nix/pin.sh` script which creates the relevant registry entry with
`?submodules=1`, so that you can then use it like `nix build mina`, `nix develop
mina`, etc. You can discover all the available packages as usual, by using tab
completion or `nix eval mina#packages.x86_64-linux --apply __attrNames` or your
favourite way.

</details>

## 1. Install Nix

If you don't already have Nix on your machine, you can install it with
the following command:

```
sh <(curl -L https://nixos.org/nix/install) --daemon
```

You may also install Nix from your distribution's official repository;
Note however that it is preferrable you get a relatively recent
version (⩾ 2.5), and the version from the repository may be rather old.

## 2. Enable Flakes (optional but recommended)

Mina is packaged using [Nix Flakes](https://nixos.wiki/wiki/Flakes),
which are an experimental feature of Nix. However, compatibility with
pre-flake Nix is provided. If you wish to contribute the Nix
expressions in this repository, or want to get some convenience
features and speed improvements, **it is advisable to enable flakes**. For
this, you'll want to make sure you're running recent Nix (⩾2.5) and
have enabled the relevant experimental features, either in
`/etc/nix/nix.conf` or (recommended) in `~/.config/nix/nix.conf`:

```
mkdir -p "${XDG_CONFIG_HOME-${HOME}/.config}/nix"
echo 'experimental-features = nix-command flakes' > "${XDG_CONFIG_HOME-${HOME}/.config}/nix/nix.conf"
```

You can check that your flake support is working by running `nix flake metadata
github:nixos/nixpkgs` for example.

## 3. Add a nix registry entry

If you're using flakes (see previous section), **you have to run the
`./nix/pin.sh` script** to get the `mina` registry entry, since that's the
easiest way to enable submodules to be available to the build. This is needed
because by default Nix will not include submodules in the source tree it builds
dependencies from, resulting in errors.

For the curious, `mina` registry entry will resolve to
`git+file:///path/to/your/mina/checkout?submodules=1`. Should you want to hack
on a different mina checkout, try e.g. `nix develop
"git+file://$PWD?submodules=1"` from that checkout.

## 4. Use it

### "Pure" development shell

TL;DR:
```
nix develop mina
dune build src/app/cli/src/mina.exe
```

You can use Nix to fetch all the dependencies, and then only use `dune` as a
build system to build Mina itself.

If you wish to build Mina yourself, or work on some changes incrementally, run
`nix develop mina` if you're using flakes (or `nix-shell default.nix`
otherwise). This will drop you in a shell with all dependencies, including
OCaml, Rust and Go ones available, so the only thing you have to do is run `dune
build src/app/cli/src/mina.exe`. You can also just run `eval "$buildPhase"` to
run the same command as would be run inside the nix sandbox. The produced
executable can be found in `_build/default/src/app/cli/src/mina.exe`. You most
likely want to run it from the same shell you've built it in, since the
executable looks for certain dependencies at runtime via environment variables,
meaning you either have to set those variables yourself or rely on the ones set
by the `devShell`. The executable produced by `nix build mina` (see ["Pure"
build section](#pure-build)) doesn't suffer from this limitation, since it is
wrapped with all the necessary environment variables.

Note that `opam` will **not** be available in that shell, since Nix takes over
the job of computing and installing dependencies. If you need to modify the opam
switch, use the impure build (next section).

Don't forget to exit and re-enter the development shell after switching
branches, or otherwise changing the dependency tree of Mina.

### IDE with LSP support (vscode, emacs, (neo)vim, ...)

Just run

```
nix develop mina#with-lsp -c $EDITOR .
```

if you have your `$EDITOR` variable set correctly. Otherwise, replace it with
the editor you want to edit Mina with.

This will drop you in your favorite editor within a Nix environment containing an
OCaml LSP server. You might need to configure your editor appropriately;
See [Per-editor instructions](#per-editor-instructions).

However, for LSP to work its magic, you will need to have to make type
informations available. They can for example be obtained by running `dune build
@check` in `src/app/cli`, which might take a while, or by compiling the project.

Don't forget to exit and re-enter the editor using this command after switching
branches, or otherwise changing the dependency tree of Mina.

#### Per-editor instructions

##### Visual Studio Code / vscodium

You have to install the "OCaml Platform" extension, either from
[official marketplace](https://marketplace.visualstudio.com/items?itemName=ocamllabs.ocaml-platform)
or [openvsix](https://open-vsx.org/extension/ocamllabs/ocaml-platform).

After installing it, run `code` (or `codium`) from within the `nix develop mina#with-lsp` shell,
click "Select Sandbox" in the extension menu, and then pick "Global Sandbox". From then on, it should just work.

##### Vim

Install [CoC](https://github.com/neoclide/coc.nvim), and add the following to its configuration (`$HOME/.config/nvim`, or just enter command `:CocConfig`):

```
{
  "languageserver": {
    "ocaml-lsp": {
      "command": "ocamllsp",
      "args": [],
      "filetypes": [
        "ocaml", "reason"
      ]
    }
  }
}
```

Now, whenever you start vim from `nix develop mina#with-lsp`, it should just work.

##### Emacs

You need to install the [tuareg](https://github.com/ocaml/tuareg) and [lsp-mode](https://github.com/emacs-lsp/lsp-mode).
This should just work without any configuration, as long as you start it from `nix develop mina#with-lsp`.

### "Pure" build

TL;DR:
```
nix build mina
```

Alternatively, you can build the entirety of Mina inside the Nix sandbox fully
automatically: run `nix build mina` if you're using flakes (or `nix-build`
otherwise). You can find the resulting executable at `result/bin/mina`.

### "Impure" development shell

TL;DR:
```
nix develop mina#impure
opam init --bare
opam update
opam switch import src/opam.export --strict
eval $(opam env)
./scripts/pin-external-packages.sh
```

You can also use Nix to only fetch the "system" (native) dependencies of Mina,
and let `opam`, `cargo` and `go` figure out the relevant language-specific
dependencies. To do so, run `nix develop mina#impure` if you have flakes (or
`nix-shell` otherwise).

It will drop you in a shell with all the relevant libraries and binaries
available, and show you the instructions for building Mina.

Don't forget to exit and re-enter the development shell after switching
branches, or otherwise changing the dependency tree of Mina.

### Building a docker image

TL;DR:
```
nix build mina#mina-docker
```

Since a "pure" build can happen entirely inside the Nix sandbox, we can use its
result to produce other useful artifacts with Nix. For example, you can build a
slim docker image. Run `nix build mina#mina-docker` if you're using flakes (or
`nix-build packages.x86_64-linux.mina-docker` otherwise). You will get a
`result` symlink in the current directory, which links to a tarball containing
the docker image. You can load the image using `docker load -i result`, then
note the tag it outputs. You can then run Mina from this docker image with
`docker run mina:<tag> mina.exe <args>`.

### Demo nixos-container

If you're running NixOS, you can use `nixos-container` to run a demo of mina
daemon from your local checkout. To do so, try

```
sudo nixos-container create mina --flake mina
sudo nixos-container start mina
sudo nixos-container root-login mina
```

From there, you can poke the mina daemon, e.g. with `systemctl status mina`.

If you want to update the container to reflect the latest checkout, try

```
sudo nixos-container stop mina
sudo nixos-container update mina --flake mina
sudo nixos-container start mina
```

### direnv

TL;DR
```
printf './nix/pin.sh\nuse flake mina\n' > .envrc
direnv allow
```

It is considered as a good practice to automatically enter the Nix shell instead
of keeping in mind that you need to execute the `nix develop mina` command every
time you enter the Mina repo directory. One way to do this is by using
[`direnv`](https://direnv.net) +
[`nix-direnv`](https://github.com/nix-community/nix-direnv)

#### How-To

- Install the `direnv` and add hook into your shell:
  - [Installation](https://direnv.net/docs/installation.html)
  - [Configuration](https://direnv.net/docs/hook.html)
- Reload your shell
- Configure the [`nix-direnv`](https://github.com/nix-community/nix-direnv)
  - The `Via home-manager (Recommended)` section
- Create the `.envrc` file under the Mina repo root path with the following
  content: `use flake mina`:
  ```
  cd mina
  touch .envrc && echo "use flake mina" >> .envrc
  ```
- Execute the following command within the Mina repo root path, in order to
  activate the `direnv` for current directory (it will read and apply previously
  created `.envrc` configuration file):

  ```
  direnv allow
  ```

- _Optional_: Reload your shell
- Now you will enter the Nix shell automatically should you `cd` into the Mina
  repo root path.
- To build Mina, you can use all the same techniques as from within the `nix
  develop` shell mentioned above. For example, try `dune build
  src/app/cli/src/mina.exe`, or `eval "$buildPhase"`. Please note though that
  `make` targets invocation won't work as usual, that is why it is preferably to
  use `dune` directly.

#### Check the shell

`direnv` will tell you which variables it added to your shell every time you
enter the subject directory.

In addition to that you can:

- Check if `direnv` loaded the configuration for particular directory by
  invoking the `direnv status` command within subject directory.
- Check the `IN_NIX_SHELL` environment variable value:
  ```
  echo ${IN_NIX_SHELL}
  ```
  Where an empty string means that the Nix shell was not entered.

#### CLI prompt info

- In addition you might want to update your CLI prompt environment information
  to automatically inform you if you've entered the Nix shell.
  - [Example](https://gist.github.com/chisui/0d12bd51a5fd8e6bb52e6e6a43d31d5e)
    - `prompt_nix_shell` method.
    - <img width="335" alt="CLI Prompt info" src="https://user-images.githubusercontent.com/4096154/175948252-aa41dc36-9d98-4986-878a-da5ed8d850dd.png">

## Miscellaneous & advanced

### Contributing to Nix expressions

You probably want to [enable flakes](#2-enable-flakes-optional-but-recommended)
if you plan to contribute to the Nix expressions here.

Most Nix things (including this README ☺) are located inside the `nix/`
subfolder. The exceptions are `flake.nix` which defines inputs and combines the
expressions from `nix/`, `flake.lock` which locks the input versions, and
`default.nix` with `shell.nix`, which provide compatibility with pre-flake Nix.

### Updating inputs

If you wish to update all the inputs of this flake, run `nix flake update` . If
you want to update a particular input, run `nix flake lock --update-input
<input>` .

### Notes on the "pure" build

The "pure" build is performed with the help of
[opam-nix](https://github.com/tweag/opam-nix). The switch is imported from
`opam.export`, and then external deps (from `src/external`) are added on top.
Also, all in-tree Rust dependencies (`kimchi_bindings` in particular) are built
as separate derivations using `rustPlatform`. Implicit native dependencies are
taken from nixpkgs with some overlays applied. All the dependencies are then
provided to the final Mina derivation. See [./ocaml.nix](./ocaml.nix) for more
details.

### Why are Rust, Go and OCaml bits built separately?

In order to enforce reproducibility, Nix doesn't generally allow networking from
inside the sandbox, apart from specific circumstances. This means that just
running `cargo build` or `go build` won't work. Instead, we're using Nix tooling
that pre-downloads all Rust/Go/OCaml dependencies as separate steps, then
provides those dependencies to the relevant build system, and builds the
components that way. Since there are three separate tools to build Rust, Go, and
OCaml packages, we have to package those components separately.

### Updating dependencies of `libp2p_helper` requires me to update the hash. Why?

`go.sum` uses a [really weird](https://github.com/vikyd/go-checksum) hashing
algorithm that's incompatible with Nix. Because of this, fetching dependencies
of Go's package is done with a fixed-output derivation (FOD), which allows
networking inside the Nix sandbox (in order to vendor all the dependencies using
`go mod vendor`), but in exchange requires the hash of the output to be
specified explicitly. This is the hash you're updating by running
`./nix/update-libp2p-hashes.sh`.

### Discovering all the packages this Flake provides

`nix flake show` doesn't work due to
[IFD](https://nixos.wiki/wiki/Import_From_Derivation).

This should give you all the "user-facing" packages this flake provides for
`x86_64-linux`:

```
nix eval mina#packages.x86_64-linux --apply __attrNames
```

#### `nix repl`

If you want to explore the entire packageset (including all of nixpkgs), enter
`nix repl`, issue `:lf mina` command there, and explore the
`legacyPackages.${__currentSystem}.regular` package set (e.g. using tab
completion). It will have a lot of things, but it allows you to play around with
and build the dependencies which are used to build Mina. `nix repl --help` and
the `:?` command will likely be useful.

Example session:

```
❯ nix repl
Welcome to Nix 2.12.0pre20220901_4823067. Type :? for help.

nix-repl> :lf mina
warning: Git tree '/home/balsoft/projects/tweag/mina' is dirty
Added 19 variables.

nix-repl> legacyPackages.x86_64-linux.regular.ocamlPackages_mina.easy-format.version
"1.3.2"

nix-repl> :b legacyPackages.x86_64-linux.regular.ocamlPackages_mina.fmt

This derivation produced the following outputs:
  out -> /nix/store/3r9ralnsyzja44p006s98i903yjzipsx-fmt-0.8.6

nix-repl> :u legacyPackages.x86_64-linux.regular.ocamlPackages_mina.mina-dev.overrideAttrs (_: { DUNE_PROFILE = "dev"; })

❯ # Now you're in a shell with mina built with DUNE_PROFILE="dev"
```

## Troubleshooting

### `Error: File unavailable:`, `Undefined symbols for architecture ...:`, `Compiler version mismatch`, missing dependency libraries, or incorrect dependency library versions

If you get an error like this:

```
File "src/lib/crypto/kimchi_bindings/stubs/dune", line 77, characters 0-237:
77 | (rule
78 |  (enabled_if
79 |   (<> %{env:MARLIN_PLONK_STUBS=n} n))
80 |  (targets libwires_15_stubs.a)
81 |  (deps
82 |   (env_var MARLIN_PLONK_STUBS))
83 |  (action
84 |   (progn
85 |    (copy
86 |     %{env:MARLIN_PLONK_STUBS=n}/lib/libwires_15_stubs.a
87 |     libwires_15_stubs.a))))
Error: File unavailable:
/nix/store/2i0iqm48p20mrn69nbgr0pf76vdzjxj6-marlin_plonk_bindings_stubs-0.1.0/lib/lib/libwires_15_stubs.a
```

or like this:

```
Undefined symbols for architecture x86_64:
  "____chkstk_darwin", referenced from:
      __GLOBAL__sub_I_clock_cache.cc in librocksdb_stubs.a(clock_cache.o)
      __GLOBAL__sub_I_lru_cache.cc in librocksdb_stubs.a(lru_cache.o)
      __GLOBAL__sub_I_sharded_cache.cc in librocksdb_stubs.a(sharded_cache.o)
      __GLOBAL__sub_I_builder.cc in librocksdb_stubs.a(builder.o)
      __GLOBAL__sub_I_c.cc in librocksdb_stubs.a(c.o)
      __GLOBAL__sub_I_column_family.cc in librocksdb_stubs.a(column_family.o)
      __GLOBAL__sub_I_compacted_db_impl.cc in librocksdb_stubs.a(compacted_db_impl.o)
      ...
ld: symbol(s) not found for architecture x86_64
```

or like this:

```
Compiler version mismatch: this project seems to be compiled with OCaml
compiler version 4.11, but the running OCaml LSP supports OCaml version 4.14.
OCaml language support will not work properly until this problem is fixed.
Hint: Make sure your editor runs OCaml LSP that supports this version of
compiler.
```

This could be caused by having some non-Nix setup polluting the environment
in your shell init file. Try running `nix develop mina -c bash --norc` or
`nix develop mina -c zsh --no-rc` and see if that helps. If it does, look through
the corresponding shell init files for anything suspicious (e.g. `eval $(opam env)`
or `PATH` modifications).

Alternatively, you might have switched branches but didn't re-enter the development
shell. Exit the development shell (with `exit`, Ctrl+D, or however else you like
exiting your shells) and re-enter it again with `nix develop mina`. `direnv` can
also sometimes not reload the environment automatically, in that case, try
`direnv reload`.

Finally, in some circumstances, `dune` is not smart enough to rebuild
things even if the environment changed and they should be rebuilt. Try removing
the `_build` directory (or running `dune clean`, which does the same thing).

### `MINA_LIBP2P_HELPER_PATH`

If you get an error like

```
[
  "Failed to connect to libp2p_helper process",
  [
    "Could not start libp2p_helper. If you are a dev, did you forget to `make libp2p_helper` and set MINA_LIBP2P_HELPER_PATH? Try MINA_LIBP2P_HELPER_PATH=$PWD/src/app/libp2p_helper/result/bin/libp2p_helper.",
    [
      "Unix.Unix_error", "No such file or directory",
      "Core.Unix.create_process",
      "((prog coda-libp2p_helper) (args ()) (env (Extend ())))"
    ]
  ]
]
```

This is most likely because you have built Mina yourself from `nix develop mina`
or `nix-shell default.nix`, and then ran the resulting executable from outside
the shell. This is not supported, see ["Pure" development
shell](#pure-development-shell) section. You can try re-entering the shell and
running the executable from there, or building mina with `nix build mina` and
running it with `result/bin/mina` instead.

### Submodules

Nix will **not** fetch submodules for you. You have to make sure that
you have the entire mina source code, including submodules, before you
run any nix commands. This should make sure you have the right
versions checked out (in most cases):

```
git submodule sync
git submodule update --init --recursive
```

If you don't do this, Nix may not always yell at you right away
(especially if all the submodule directories are present in the tree
somehow, but not correctly filled in). It will however fail with a
strange error during the build, when it fails to find a
dependency. Make sure you do this!

### git LFS

If you have git LFS installed and configured on your system, the build may fail with strange errors similar to this:

```
Downloading docs/res/all_data_structures.dot.png (415 KB)
Error downloading object: docs/res/all_data_structures.dot.png (fed6771): Smudge error: Error downloading docs/res/all_data_structures.dot.png (fed6771190a9b063246074bbfe3b1fc0ba4240fdc41abcf026d5bc449ca4f9b8): batch request: missing protocol: ""

Errors logged to /tmp/nix-115798-1/lfs/logs/20220121T113801.442266054.log
Use `git lfs logs last` to view the log.
error: external filter 'git-lfs filter-process' failed
fatal: docs/res/all_data_structures.dot.png: smudge filter lfs failed
error: program 'git' failed with exit code 128
(use '--show-trace' to show detailed location information)
```

You can fix this by setting `GIT_LFS_SKIP_SMUDGE=1` env variable, e.g. by running

```
export GIT_LFS_SKIP_SMUDGE=1
```

Before running any `nix` commands.

### Warning: ignoring untrusted substituter

Update your `/etc/nix/nix.conf` with the following content (concatenating new
values with possibly already existing):

```
trusted-substituters = https://storage.googleapis.com/mina-nix-cache https://cache.nixos.org
trusted-public-keys = nix-cache.minaprotocol.org:D3B1W+V7ND1Fmfii8EhbAbF1JXoe2Ct4N34OKChwk2c= nix-cache.minaprotocol.org:fdcuDzmnM0Kbf7yU4yywBuUEJWClySc1WIF6t6Mm8h4= nix-cache.minaprotocol.org:D3B1W+V7ND1Fmfii8EhbAbF1JXoe2Ct4N34OKChwk2c= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```

And then reload your `nix-daemon` service.
