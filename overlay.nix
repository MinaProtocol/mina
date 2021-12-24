final: prev:
let pkgs = final;
in {
  go-capnproto2 = pkgs.buildGoModule rec {
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

  libp2p_ipc_go = pkgs.stdenv.mkDerivation {
    # todo: buildgomodule?
    name = "libp2p_ipc-go";
    buildInputs = [ pkgs.capnproto pkgs.go-capnproto2 ];
    src = ./src/libp2p_ipc;
    buildPhase = ''
      capnp compile -ogo -I${pkgs.go-capnproto2.src}/std libp2p_ipc.capnp
    '';
    installPhase = ''
      mkdir $out
      cp go.mod go.sum *.go $out/
    '';
  };

  # Jobs/Test/Libp2pUnitTest
  libp2p_helper = pkgs.buildGoModule {
    pname = "libp2p_helper";
    version = "0.1";
    src = ./src/app/libp2p_helper/src;
    runVend = true; # missing some schema files
    vendorSha256 = "sha256-g0DsuLMiXjUTsGbhCSeFKEFKMEMtg3UTUjmYwUka6iE=";
    postConfigure = ''
      chmod +w vendor
      cp -r --reflink=auto ${pkgs.libp2p_ipc_go}/ vendor/libp2p_ipc
    '';
    NO_MDNS_TEST = 1; # no multicast support inside the nix sandbox
    overrideModAttrs = n: {
      # remove libp2p_ipc from go.mod, inject it back in postconfigure
      postConfigure = ''
        sed -i '/libp2p_ipc/d' go.mod
      '';
    };
  };
}
