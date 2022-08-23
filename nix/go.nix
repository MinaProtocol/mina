# An overlay defining Go parts&dependencies of Mina
final: prev: {
  vend = final.callPackage ./vend { };

  go-capnproto2 = pkgs.buildGo118Module rec {
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
    vendorSha256 =
      # sanity check, to make sure the fixed output drv doesn't keep working
      # when the inputs change
      if builtins.hashFile "sha256" ../src/app/libp2p_helper/src/go.mod
      == "b61925da13e7b9d0e0581e3af0f423ecf5beb7ac56eb747b5af02d18fdfa3abc"
      && builtins.hashFile "sha256" ../src/app/libp2p_helper/src/go.sum
      == "27d929c6f62322fb01e84781456ce1fb986cc28d1b9fe7b338e4291f5e909baa" then
        "sha256-WT6SmmtSctJ0Roq4EYKAl7LSzsjsjjS0xqN1RATxpqs="
      else
        final.lib.warn
        "Please update the hashes in ${__curPos.file}#${toString __curPos.line}"
        final.lib.fakeHash;
    NO_MDNS_TEST = 1; # no multicast support inside the nix sandbox
    overrideModAttrs = n: {
      # Yo dawg
      # proxyVendor doesn't work (cannot find package "." in:)
      # And runVend was removed from nixfinal
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
}
