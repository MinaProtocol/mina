{ lib, dockerTools, buildEnv, ocamlPackages_mina, runCommand, dumb-init
, coreutils, findutils, bashInteractive, python3, libp2p_helper, procps, postgresql, curl
, jq, stdenv, rsync, bash, gnutar, gzip, currentTime, flockenzeit }:
let
  created = flockenzeit.lib.ISO-8601 currentTime;

  mkdir = name:
    runCommand "mkdir-${name}" { } "mkdir -p $out${lib.escapeShellArg name}";

  mina-build-config = stdenv.mkDerivation {
    pname = "mina-build-config";
    version = "dev";
    nativeBuildInputs = [ rsync ];

    buildCommand = ''
      mkdir -p $out/etc/coda/build_config
      cp ${../src/config}/mainnet.mlh $out/etc/coda/build_config/BUILD.mlh
      rsync -Huav ${../src/config}/* $out/etc/coda/build_config/.
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

  mkFullImage = name: packages: additional_envs: dockerTools.streamLayeredImage {
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
    ] ++ packages;
    extraCommands = ''
      mkdir root tmp
      chmod 777 tmp
    '';
    config = {
      env = [ "MINA_TIME_OFFSET=0" ] ++ additional_envs;
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
    mina-build-config
    mina-daemon-scripts

    mina.out
    mina.mainnet
    mina.genesis
  ]);
  
  # Image with enhanced binary capable of generating coverage report on mina exit
  # For more details please visit: https://github.com/aantron/bisect_ppx/blob/master/doc/advanced.md#sigterm-handling
  mina-image-instr-full = mkFullImage "mina-instr" (with ocamlPackages_mina; [
    mina-build-config
    mina-daemon-scripts

    with_instrumentation.out
    mina.mainnet
    mina.genesis
  ]) ["BISECT_SIGTERM=yes"];

  mina-archive-image-full = mkFullImage "mina-archive" (with ocamlPackages_mina; [
    mina-archive-scripts
    gnutar
    gzip

    mina.archive
  ]);
}