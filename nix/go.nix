# An overlay defining Go parts&dependencies of Mina
final: prev: {
  vend = final.callPackage ./vend { };

  go-capnproto2 = final.buildGo118Module rec {
    pname = "capnpc-go";
    version = "v3.0.0-alpha.5";
    vendorSha256 = "sha256-oZ6fUUpAsBS5hvl2+eqWsE3i0lwJzXeVaH2OiqWJQyY=";
    # Don't understand the problem, but it seems to build fine without examples
    excludedPackages = [ "./example/books/ex1" "./example/books/ex2" "./example/hashes" ];
    src = final.fetchFromGitHub {
      owner = "capnproto";
      repo = "go-capnproto2";
      rev = "v3.0.0-alpha.5";
      hash = "sha256-geKqYjPUyJ7LT01NhJc9y8oO1hyhktTx1etAK4cXBec=";
    };
  };

  libp2p_ipc_go = final.stdenv.mkDerivation {
    # todo: buildgomodule?
    name = "libp2p_ipc-go";
    buildInputs = [ final.capnproto final.go-capnproto2 ];
    src = ../src/libp2p_ipc;
    buildPhase = ''
      capnp compile -ogo -I${final.go-capnproto2.src}/std libp2p_ipc.capnp
    '';
    installPhase = ''
      mkdir $out
      cp go.mod go.sum *.go $out/
    '';
  };

  # Jobs/Test/Libp2pUnitTest
  libp2p_helper = final.buildGo118Module {
    pname = "libp2p_helper";
    version = "0.1";
    src = ../src/app/libp2p_helper/src;
    doCheck = false; # TODO: tests hang
    vendorSha256 = let hashes = final.lib.importJSON ./libp2p_helper.json; in
      # sanity check, to make sure the fixed output drv doesn't keep working
      # when the inputs change
      if builtins.hashFile "sha256" ../src/app/libp2p_helper/src/go.mod
      == hashes."go.mod"
      && builtins.hashFile "sha256" ../src/app/libp2p_helper/src/go.sum
      == hashes."go.sum" then
        hashes.vendorSha256
      else
        final.lib.warn
        ''
          Below, you will find an error about a hash mismatch.
          This is likely because you have updated go.mod and/or go.sum in libp2p_helper.
          Please, locate the "got: " hash in the aforementioned error. If it's in SRI format ([35;1msha256-<...>[31;1m), copy the entire hash, including the `[35;1msha256-[31;1m'. Otherwise (if it's in the base32 format, like `[35;1msha256:<...>[31;1m'), copy only the base32 part, without `[35;1msha256:[31;1m'.
          Then, run [37;1m./nix/update-libp2p-hashes.sh [35;1m"<got hash here>"[31;0m
        ''
        final.lib.fakeHash;
    NO_MDNS_TEST = 1; # no multicast support inside the nix sandbox
    overrideModAttrs = n: {
      # Yo dawg
      # proxyVendor doesn't work (cannot find package "." in:)
      # And runVend was removed from nixpkgs
      # So we vendor the vend package in yo repo
      # So yo can vendor while u vendor
      postBuild = ''
        rm vendor -rf
        ${final.vend}/bin/vend
      '';
      # remove libp2p_ipc from go.mod, inject it back in postconfigure
      postConfigure = ''
        sed -i 's/.*libp2p_ipc.*//' go.mod
      '';
    };
    postConfigure = ''
      chmod +w vendor
      cp -r --reflink=auto ${final.libp2p_ipc_go}/ vendor/libp2p_ipc
      sed -i 's/.*libp2p_ipc.*//' go.mod
    '';
  };

  # Tool for testing implementation of the rosetta api
  rosetta-cli = final.buildGoModule rec {
    pname = "rosetta-cli";
    version = "0.10.0";
    src = final.fetchFromGitHub {
      owner = "coinbase";
      repo = "rosetta-cli";
      rev = "085f95c85c99f607a82fb1814594d95dc9fefb55";
      sha256 = "I3fNRiMwuk5FWiECu31Z5A23djUR0GHugy1OqNruzj8=";
    };
    vendorSha256 = "sha256-ooFpB17Yu9aILx3kl2o6WVbbX110YeSdcC0RIaBUwzM=";
  };
}
