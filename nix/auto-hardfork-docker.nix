# nix/auto-hardfork-docker.nix
#
# callPackage-compatible expression for building an auto-hardfork docker image
# that packages both pre-fork and post-fork mina binaries with the dispatcher.
#
# Called via lib.mkAutoHardforkDocker from the main flake. The prefork/postfork
# derivations come from the mina flake at different branches, so their full
# runtime closures (glibc, gcc-lib, etc.) are preserved automatically.

{ lib, dockerTools, runCommand, stdenv, dumb-init, coreutils, findutils
, bashInteractive, python3, procps, curl, jq, fakeNss, bash, flockenzeit
, currentTime, preforkDevnet, postforkDevnet, preforkLibp2p, postforkLibp2p }:
let
  created = flockenzeit.lib.ISO-8601 currentTime;

  mina-daemon-scripts = stdenv.mkDerivation {
    pname = "mina-daemon-scripts";
    version = "dev";
    src = ../dockerfiles;
    buildInputs = [ python3 bash ];
    installPhase = ''
      mkdir -p $out/healthcheck $out/entrypoint.d
      cp scripts/healthcheck-utilities.sh $out/healthcheck/utilities.sh
      cp scripts/cron_job_dump_ledger.sh $out/cron_job_dump_ledger.sh
      cp scripts/daemon-entrypoint.sh $out/entrypoint.sh
      cp puppeteer-context/* $out/
      chmod -R +x $out/*
    '';
  };

  auto-hardfork-layout = runCommand "auto-hardfork-layout" { } ''
    mkdir -p $out/runtimes/berkeley $out/runtimes/mesa
    mkdir -p $out/usr/local/bin
    mkdir -p $out/etc/default

    # Pre-fork binaries
    ln -s ${preforkDevnet}/bin/mina $out/runtimes/berkeley/mina
    ln -s ${preforkLibp2p}/bin/mina-libp2p_helper $out/runtimes/berkeley/coda-libp2p_helper

    # Post-fork binaries
    ln -s ${postforkDevnet}/bin/mina $out/runtimes/mesa/mina
    ln -s ${postforkLibp2p}/bin/mina-libp2p_helper $out/runtimes/mesa/coda-libp2p_helper

    # Dispatcher script
    cp ${../scripts/hardfork/dispatcher.sh} $out/usr/local/bin/mina-dispatch
    chmod +x $out/usr/local/bin/mina-dispatch
    ln -s mina-dispatch $out/usr/local/bin/mina

    # Dispatcher config
    cat > $out/etc/default/mina-dispatch <<'CONF'
MINA_NETWORK=mesa
MINA_PROFILE=devnet
RUNTIMES_BASE_PATH=/runtimes
MINA_LIBP2P_ENVVAR_NAME=MINA_LIBP2P_HELPER_PATH
CONF
  '';
in dockerTools.streamLayeredImage {
  name = "mina-auto-hardfork-devnet-full";
  inherit created;
  contents = [
    fakeNss
    dumb-init
    coreutils
    findutils
    bashInteractive
    python3
    procps
    curl
    jq
    mina-daemon-scripts
    auto-hardfork-layout
    # Include mina and libp2p packages directly so streamLayeredImage
    # picks up their full runtime closures (including glibc, gcc-lib, etc.).
    preforkDevnet
    postforkDevnet
    preforkLibp2p
    postforkLibp2p
  ];
  extraCommands = ''
    mkdir root tmp
    chmod 777 tmp
    mkdir -p usr/bin
    ln -s /bin/env usr/bin/env
  '';
  config = {
    Env = [
      "MINA_TIME_OFFSET=0"
      "HOME=/root"
      "MINA_APP=/usr/local/bin/mina-dispatch"
    ];
    WorkingDir = "/root";
    Cmd = [ "/bin/dumb-init" "/entrypoint.sh" ];
  };
}
