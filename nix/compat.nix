let
  # Pull out revisions and narHashes from the lock file
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  fetchGithub = node:
    with node.locked;
    fetchTarball {
      url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
      sha256 = narHash;
    };
  # "Bootstrap" inputs
  flake-compat = fetchGithub lock.nodes.flake-compat;
  gitignore-nix = fetchGithub lock.nodes.gitignore-nix;
  nixpkgs = fetchGithub lock.nodes.nixpkgs;

  inherit (import gitignore-nix { lib = import "${nixpkgs}/lib"; })
    gitignoreSource;

  # Actual flake to be passed on
  flake = import flake-compat { src = gitignoreSource ../.; };
in flake
