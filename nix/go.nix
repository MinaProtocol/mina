# An overlay defining Go parts&dependencies of Mina
final: prev: {
  vend = final.callPackage ./vend { };

  go-capnproto2 = final.buildGo118Module rec {
    pname = "capnpc-go";
    version = "v3.0.0-alpha.1";
    vendorSha256 = "sha256-jbX/nnlnQoItFXFL/MZZKe4zAjM/EA3q+URJG8I3hok=";
    src = final.fetchFromGitHub {
      owner = "capnproto";
      repo = "go-capnproto2";
      rev = "v3.0.0-alpha.1";
      hash = "sha256-afdLw7of5AksR4ErCMqXqXCOnJ/nHK2Lo4xkC5McBfM";
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
      == "4ce9e2efa7e35cce9b7b131bef15652830756f6f6da250afefd4751efa1d6565"
      && builtins.hashFile "sha256" ../src/app/libp2p_helper/src/go.sum
      == "8b90b3cee4be058eeca0bc9a5a2ee88d62cada9fb09785e0ced5e5cea7893192" then
        "sha256-MXLfE122UCNizqvGUu6WlThh1rnZueTqirCzaEWmbno="
      else
        final.lib.warn
        "Please update the hashes in ${__curPos.file}#${toString __curPos.line}"
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
}