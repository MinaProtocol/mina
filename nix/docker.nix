{ lib, dockerTools, buildEnv, ocamlPackages_mina, linkFarm, runCommand
, dumb-init, tzdata, coreutils,  findutils, bashInteractive, python3, libp2p_helper, procps
, postgresql, curl, jq, stdenv, rsync, bash, gnutar, gzip, cacert, currentTime
, flockenzeit }:
let
  created = flockenzeit.lib.ISO-8601 currentTime;

  mkdir = name:
    runCommand "mkdir-${name}" { } "mkdir -p $out${lib.escapeShellArg name}";

  # /etc/coda/build_config/PROFILE is the hint the daemon falls back on to
  # resolve its proof level when MINA_PROFILE is not set in the environment, so
  # it has to name the profile the binaries in the same image were built with.
  # This mirrors build_profile_deb in scripts/debian/builder-helpers.sh, which
  # ships the same file with the same contents.
  mkBuildConfig = profile:
    stdenv.mkDerivation {
      pname = "mina-build-config-${profile}";
      version = "dev";

      buildCommand = ''
        mkdir -p $out/etc/coda/build_config
        printf "${profile}" > $out/etc/coda/build_config/PROFILE
      '';
    };

  mina-daemon-scripts = stdenv.mkDerivation {
    pname = "mina-daemon-scripts";
    version = "dev";
    src = ../dockerfiles;
    buildInputs = [ python3 bash ]; # For patchShebang-ing
    installPhase = ''
      mkdir -p $out/healthcheck $out/entrypoint.d
      cp scripts/healthcheck-utilities.sh $out/healthcheck/utilities.sh
      cp scripts/cron_job_dump_ledger.sh $out/cron_job_dump_ledger.sh
      cp scripts/daemon-entrypoint.sh $out/entrypoint.sh
      cp puppeteer-context/* $out/
      chmod -R +x $out/*
    '';
  };

  mina-archive-scripts = stdenv.mkDerivation {
    pname = "mina-archive-scripts";
    version = "dev";
    buildCommand = ''
      mkdir -p $out/entrypoint.d $out/healthcheck
      cp ${../dockerfiles/scripts/archive-entrypoint.sh} $out/entrypoint.sh
      cp ${
        ../dockerfiles/scripts/healthcheck-utilities.sh
      } $out/healthcheck/utilities.sh
      chmod -R +x $out
    '';
  };

  localtime = linkFarm "localtime" [{
    name = "etc/localtime";
    path = "${tzdata}/share/zoneinfo/UTC";
  }];

  zoneinfo = linkFarm "zoneinfo" [{
    name = "usr/share/zoneinfo";
    path = "${tzdata}/share/zoneinfo";
  }];

  mkFullImage = name: packages: dockerTools.streamLayeredImage {
    name = "${name}-full";
    inherit created;
    contents = [
      dumb-init
      coreutils
      findutils
      bashInteractive
      python3
      libp2p_helper
      procps
      curl
      jq
      cacert
      localtime
      zoneinfo
    ] ++ packages;
    extraCommands = ''
      mkdir root tmp
      chmod 777 tmp
    '';
    config = {
      env = [
        "MINA_TIME_OFFSET=0"
        "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
        # The daemon defaults its config directory to $HOME/.mina-config, and
        # there is no /etc/passwd in this image for docker to derive HOME from,
        # so without this it becomes /.mina-config. The integration test
        # entrypoint imports account keys into /root/.mina-config explicitly, so
        # a daemon reading /.mina-config finds an empty wallet and every test
        # that unlocks an account fails with "Could not find owned account".
        # The debian images get HOME=/root from their base image's passwd entry.
        "HOME=/root"
      ];
      WorkingDir = "/root";
      cmd = [ "/bin/dumb-init" "/entrypoint.sh" ];
    };
  };
in {
  mina-image-slim = dockerTools.streamLayeredImage {
    name = "mina";
    inherit created;
    contents = [ ocamlPackages_mina.mina.out ];
  };

  mina-image-full = mkFullImage "mina" (with ocamlPackages_mina; [
    (mkBuildConfig "mainnet")
    mina-daemon-scripts

    mina.out
    mina.mainnet
    mina.genesis
  ]);

  mina-archive-image-full = mkFullImage "mina-archive"
    (with ocamlPackages_mina; [
      mina-archive-scripts
      gnutar
      gzip

      mina.archive
    ]);

  # Devnet counterparts of the two images above, for the integration tests. Same
  # layout, but every binary comes from the DUNE_PROFILE=devnet build
  # (ocamlPackages_mina.devnet) instead of the dev-profile one, and the PROFILE
  # hint matches what is in the image.
  #
  # These are the images the integration tests want: `mina-image-full` pairs
  # dev-profile binaries with a PROFILE hint that says mainnet, which is neither
  # of the two things a devnet test needs. `devnet` is also what NixBuildTest
  # already builds on every PR, so these reuse the shared nix cache rather than
  # pulling a second, otherwise-unused compile of mina.
  #
  # "generic" is meant in the same sense as the mina-${network}-generic Debian
  # package: daemon binaries and the profile hint, with no network config baked
  # in. That is not just a naming choice -- a config.json inside the image gets
  # picked up implicitly by every node, and a fork element in it breaks the
  # integration tests. Nothing here ships one: the only thing under /etc/coda is
  # build_config/PROFILE, and devnet.genesis contributes an empty
  # /var/lib/coda (ocaml.nix leaves the genesis copy commented out). The tests
  # pass the runtime config they want on the command line instead.
  mina-image-devnet-generic =
    mkFullImage "mina-devnet-generic" (with ocamlPackages_mina; [
      (mkBuildConfig "devnet")
      mina-daemon-scripts

      devnet.out
      # Devnet is a testnet-signature network, so this is the counterpart of
      # mina.mainnet above, not a different kind of thing.
      devnet.testnet
      devnet.genesis
    ]);

  mina-archive-image-devnet = mkFullImage "mina-archive-devnet"
    (with ocamlPackages_mina; [
      mina-archive-scripts
      gnutar
      gzip

      devnet.archive
    ]);
}
