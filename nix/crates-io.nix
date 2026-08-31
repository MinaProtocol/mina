# An overlay making crate tarballs downloadable again.
#
# crates.io enforces its crawler policy on `https://crates.io/api/v1/crates/…`
# and answers 403 to any User-Agent starting with `curl/`, which is exactly
# what nixpkgs' `fetchurl` sends (`curl/<version> Nixpkgs/<version>`). Every
# crate fetched by `importCargoLock` (i.e. by every `buildRustPackage` here)
# goes through that endpoint, so a cache miss on any crate fails the build:
#
#     trying https://crates.io/api/v1/crates/ansi_term/0.12.1/download
#     curl: (22) The requested URL returned error: 403
#     error: cannot download crate-ansi_term-0.12.1.tar.gz from any mirror
#
# `static.crates.io` is the CDN crates.io points cargo itself at: no User-Agent
# gate, and no 1 req/sec crawler rate limit either. Upstream nixpkgs made the
# same switch in f830e6112, which landed in nixos-25.11; we pin
# nixos-24.11-small, so rewrite the URL here instead.
#
# Crate fetches are fixed-output derivations, so their output paths depend only
# on the derivation name and the hash: rewriting the URL moves nothing and
# leaves every existing binary-cache entry valid.
#
# Remove this overlay once the nixpkgs pin moves past the upstream fix.
final: prev:
let
  inherit (prev.lib) hasPrefix removePrefix;

  apiPrefix = "https://crates.io/api/v1/crates/";
  staticPrefix = "https://static.crates.io/crates/";

  toStaticUrl = url:
    if hasPrefix apiPrefix url then
      staticPrefix + removePrefix apiPrefix url
    else
      url;

  toStaticUrls = args:
    args // (if args ? url then { url = toStaticUrl args.url; } else { })
    // (if args ? urls then { urls = map toStaticUrl args.urls; } else { });
in {
  # `prev.fetchurl` is a functor carrying `override`; keep those attributes and
  # only replace how it is applied.
  fetchurl = prev.fetchurl // {
    __functor = _: args: prev.fetchurl (toStaticUrls args);
  };
}
