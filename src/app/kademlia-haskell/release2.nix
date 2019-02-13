# We use stack.yaml as a single source of truth for our Haskell builds. You can
# use stack to build the package when you're writing Haskell, and nix to build
# it for use in Coda. stack2nix is used to build packages.nix, based on the
# Stackage snapshot we use. To rebuild it, get stack2nix from
# https://github.com/input-output-hk/stack2nix and run:
# cd src/app/kademlia-haskell; stack2nix . > packages.nix

(import ./packages.nix {}).kademlia-haskell
