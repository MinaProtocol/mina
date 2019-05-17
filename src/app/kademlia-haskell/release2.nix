# We use stack.yaml as a single source of truth for our Haskell build
# configuration. You can use Stack to build the package when you're writing
# Haskell, and Nix to build it for use in Coda, and they should both use the
# same dependencies, compiler version, etc. stack2nix is used to build
# packages.nix, based on the Stackage snapshot we use. To rebuild it, get
# stack2nix from https://github.com/input-output-hk/stack2nix and run:
# cd src/app/kademlia-haskell; stack2nix . > packages.nix

# Library profiling is on by default, and approximately doubles compile time.
# Turn it off.
let pinnedNixpkgs = import (builtins.fetchTarball {
  name = "nixpkgs-unstable-2019-03-18";
  url = https://github.com/nixos/nixpkgs/archive/0125544e2a0552590c87dca1583768b49ba911c0.tar.gz;
  sha256 = "04xvlqw3zbq91zkfa506b2k1ajmj7pqh3nvdh9maabw6m5jhm5rl";
  });
in
((import ./packages.nix { pkgs = pinnedNixpkgs {} ; }).override
  {overrides = self: super: {
    mkDerivation = args: super.mkDerivation (args // {enableLibraryProfiling = false;});
    };
  }).kademlia-haskell
