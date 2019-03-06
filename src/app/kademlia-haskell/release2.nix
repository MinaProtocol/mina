# We use stack.yaml as a single source of truth for our Haskell build
# configuration. You can use Stack to build the package when you're writing
# Haskell, and Nix to build it for use in Coda, and they should both use the
# same dependencies, compiler version, etc. stack2nix is used to build
# packages.nix, based on the Stackage snapshot we use. To rebuild it, get
# stack2nix from https://github.com/input-output-hk/stack2nix and run:
# cd src/app/kademlia-haskell; stack2nix . > packages.nix

# Library profiling is on by default, and approximately doubles compile time.
# Turn it off.
((import ./packages.nix {}).override
  {overrides = self: super: {
    mkDerivation = args: super.mkDerivation (args // {enableLibraryProfiling = false;});
    };
  }).kademlia-haskell
