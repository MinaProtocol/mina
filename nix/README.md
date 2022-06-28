# Building Mina using Nix

Nix is a declarative package manager for Linux, macOS and other
UNIX-like systems. You can read more about Nix on its [official
website](https://nixos.org).

Mina can be built using Nix, in multiple ways. Follow the steps below to get started and read the [troubleshooting section](#troubleshooting) if you encounter any problem.

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

You can check that your flake support is working by running `nix flake metadata github:nixos/nixpkgs` for example.

## 3. Add a nix registry entry

If you're using flakes (see previous section), **you have to run the `./nix/pin.sh` script** to
get the `mina` registry entry, since that's the easiest way to enable
submodules to be available to the build.

## 4. Use it

### IDE with LSP support (vscode, emacs, (neo)vim, ...)

Just run

```
nix develop mina#with-lsp -c $EDITOR .
```

if you have your `$EDITOR` variable set correctly. Otherwise, replace it with
the editor you want to edit Mina with.

This command will try to `dune build @check` in `src/app/cli`, in order to get
type information necessary for the LSP to work. This might take a while, but
will only happen once. After it's done, you will be dropped in your favourite editor.

### "Pure" build

You can use Nix to fetch all the dependencies, and then only use
`dune` as a build system to build Mina itself.

This way, you can build the entirety of Mina inside the Nix sandbox
fully automatically: run `nix-build` (or `nix build mina` if you're
using flakes).

If you wish to build Mina yourself, or work on some changes
incrementally, run `nix-shell default.nix` (or `nix develop mina` if
you're using flakes). This will drop you in a shell with all
dependencies, including OCaml, Rust and Go ones available, so the only
thing you have to do is run `dune build src/app/cli/src/mina.exe`. You
can also just run `eval "$buildPhase"` to run the same command as
would be run inside the nix sandbox. Note that `opam` will **not** be available in that shell, since Nix takes over the job of computing and installing dependencies. If you need to modify the opam switch, use the impure build (next section).

### "Impure" build

You can also use Nix to only fetch the "system" (native) dependencies of
Mina, and let `opam`, `cargo` and `go` figure out the relevant
language-specific dependencies. To do so, run `nix-shell` (or `nix develop mina#impure` if you have flakes).

It will drop you in a shell with all the relevant libraries and
binaries available, and show you the instructions for building Mina.

### Building a docker image

Since a "pure" build can happen entirely inside the Nix sandbox, we
can use its result to produce other useful artifacts with Nix. For
example, you can build a slim docker image. Run `nix-build packages.x86_64-linux.mina-docker` (or `nix build mina#mina-docker` if
you're using flakes). You will get a `result` symlink in the current
directory, which links to a tarball containing the docker image. You
can load the image using `docker load -i result`, then note the tag it
outputs. You can then run Mina from this docker image with `docker run mina:<tag> mina.exe <args>`.

### direnv

It is considered as a good practice to automatically enter the Nix shell instead of keeping in mind that you need to execute the `nix develop mina` command every time you enter the Mina repo directory.  
One way to do this is by using [`direnv`](https://direnv.net) + [`nix-direnv`](https://github.com/nix-community/nix-direnv)

#### How-To

- Install the `direnv` and add hook into your shell:
  - [Installation](https://direnv.net/docs/installation.html)
  - [Configuration](https://direnv.net/docs/hook.html)
- Reload your shell
- Configure the [`nix-direnv`](https://github.com/nix-community/nix-direnv)
  - The `Via home-manager (Recommended)` section
- Create the `.envrc` file under the Mina repo root path with the following content: `use nix` or `use flake mina`:
  ```
  cd mina
  touch .envrc && echo "use flake mina" >> .envrc
  ```
- Execute the following command within the Mina repo root path, in order to activate the `direnv` for current directory (it will read and apply previously created `.envrc` configuration file):

  ```
  direnv allow
  ```

- _Optional_: Reload your shell
- Now you will enter the Nix shell automatically should you `cd` into the Mina repo root path.
- To build Mina, you can use all the same techniques as from within the `nix develop` shell mentioned above. For example, try `dune build src/app/cli/src/mina.exe`, or `eval "$buildPhase"`.  
  Please note though that `make` targets invocation won't work as usual, that is why it is preferably to use `Dune`.

#### Check the shell

`direnv` will tell you which variables it added to your shell every time you enter the subject directory.

In addition to that you can:

- Check if `direnv` loaded the configuration for particular directory by invoking the `direnv status` command within subject directory.
- Check the `IN_NIX_SHELL` environment variable value:
  ```
  echo ${IN_NIX_SHELL}
  ```
  - Where an empty string means that the Nix shell was not entered.

#### CLI prompt info

- In addition you might want to update your CLI prompt environment information to automatically inform you if you've entered the Nix shell.
  - [Example](https://gist.github.com/chisui/0d12bd51a5fd8e6bb52e6e6a43d31d5e)
    - `prompt_nix_shell` method.
    - <img width="335" alt="CLI Prompt info" src="https://user-images.githubusercontent.com/4096154/175948252-aa41dc36-9d98-4986-878a-da5ed8d850dd.png">

## Miscellaneous

### Contributing to Nix expressions

You probably want to [enable flakes](#2-enable-flakes-optional-but-recommended) if you plan
to contribute to the Nix expressions here.

Most Nix things (including this README ☺) are located inside the
`nix/` subfolder. The exceptions are `flake.nix` which defines inputs
and combines the expressions from `nix/`, `flake.lock` which locks the
input versions, and `default.nix` with `shell.nix`, which provide
compatibility with pre-flake Nix.

### Updating inputs

If you wish to update all the inputs of this flake, run `nix flake update` . If you want to update a particular input, run `nix flake lock --update-input <input>` .

### Notes on the "pure" build

The "pure" build is performed with the help of
[opam-nix](https://github.com/tweag/opam-nix). The switch is imported
from `src/opam.export`, and then external deps (from `src/external`)
are added on top. Also, all in-tree Rust dependencies
(`kimchi_bindings` in particular) are built as separate derivations
using `rustPlatform`. Implicit native dependencies are taken from
nixpkgs with some overlays applied (see
[./overlay.nix](./overlay.nix)). All the dependencies are then
provided to the final Mina derivation. See [./ocaml.nix](./ocaml.nix)
for more details.

## Troubleshooting

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
