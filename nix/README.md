# Building Mina using Nix

Nix is a declarative package manager for Linux, macOS and other
UNIX-like systems. You can read more about Nix on its [official
website](https://nixos.org).

Mina can be built using Nix, in multiple ways.

## TL;DR installing Nix

If you don't already have Nix on your machine, you can install it with
the following command:

```
sh <(curl -L https://nixos.org/nix/install) --daemon
```

You may also install Nix from your distribution's official repository;
Note however that it is preferrable you get a relatively recent
version (⩾ 2.5), and the version from the repository may be rather old.

## Note about Flakes

Mina is packaged using [Nix Flakes](https://nixos.wiki/wiki/Flakes),
which are an experimental feature of Nix. However, compatibility with
pre-flake Nix is provided. If you wish to contribute the Nix
expressions in this repository, or want to get some convenience
features and speed improvements, it is advisable to enable flakes. For
this, you'll want to make sure you're running recent Nix (⩾2.5) and
have enabled the relevant experimental features, either in
`/etc/nix/nix.conf` or (recommended) in `~/.config/nix/nix.conf`:

```
mkdir -p "${XDG_CONFIG_HOME-~/.config}/nix"
echo 'experimental-features = nix-command flakes' > "${XDG_CONFIG_HOME-~/.config}/nix/nix.conf"
```

You can check that your flake support is working by running `nix flake
metadata github:nixos/nixpkgs` for example.

If you're using flakes, you have to run the `./nix/pin.sh` script to
get the `mina` registry entry, since that's the easiest way to enable
submodules to be available to the build.

## "Impure" build

You can use Nix to only fetch the "system" (native) dependencies of
Mina, and let `opam`, `cargo` and `go` figure out the relevant
language-specific dependencies. To do so, run `nix-shell` (or `nix
develop mina#impure` if you have flakes).

It will drop you in a shell with all the relevant libraries and
binaries available, and show you the instructions for building Mina.

## "Pure" build

You can also use Nix to fetch all the dependencies, and then only use
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
would be run inside the nix sandbox.

## Building a docker image

Since a "pure" build can happen entirely inside the Nix sandbox, we
can use its result to produce other useful artifacts with Nix. For
example, you can build a slim docker image. Run `nix-build
packages.x86_64-linux.mina-docker` (or `nix build mina#mina-docker` if
you're using flakes). You will get a `result` symlink in the current
directory, which links to a tarball containing the docker image. You
can load the image using `docker load -i result`, then note the tag it
outputs. You can then run Mina from this docker image with `docker run
mina:<tag> mina.exe <args>`.

## Contributing to Nix expressions

You probably want to [enable flakes](#note-about-flakes) if you plan
to contribute to the Nix expressions here.

Most Nix things (including this README ☺) are located inside the
`nix/` subfolder. The exceptions are `flake.nix` which defines inputs
and combines the expressions from `nix/`, `flake.lock` which locks the
input versions, and `default.nix` with `shell.nix`, which provide
compatibility with pre-flake Nix.

### Updating inputs

If you wish to update all the inputs of this flake, run `nix flake
update` . If you want to update a particular input, run `nix flake lock
--update-input <input>` .

### Notes on the "pure" build

The "pure" build is performed with the help of
[opam-nix](https://github.com/tweag/opam-nix). The switch is imported
from `src/opam.export`, and then external deps (from `src/external`)
are added on top. All the dependencies are then provided to the final
Mina derivation. See [./ocaml.nix](./ocaml.nix) for more details.
