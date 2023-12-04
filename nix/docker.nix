{ lib, dockerTools, buildEnv, ocamlPackages_mina, runCommand, dumb-init
, coreutils, bashInteractive, python3, libp2p_helper, procps, postgresql, curl
, jq, stdenv, rsync, bash, gnutar, gzip, currentTime, flockenzeit, tzdata
, cqlsh-expansion, python3Packages, awscli }:
let

  created = flockenzeit.lib.ISO-8601 currentTime;

  mkdir = name:
    runCommand "mkdir-${name}" { } "mkdir -p $out${lib.escapeShellArg name}";

  nix-image = dockerTools.pullImage {
    imageName = "lnl7/nix";
    imageDigest =
      "sha256:9ba4c0a01d5153f741ac87364b2fd7a9c8b8b92600325f56d35da18421917e95";
    finalImageName = "lnl7-nix";
    finalImageTag = "latest";
    sha256 = "1zymy4rdwzbfhvcbpr1k3mr7gq08gkmrj33dg25ig0nbv9rka5si";
  };

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

  mina-delegation-verify-init = runCommand "mina-delegation-verify-init" { } ''
    mkdir -p $out
    export HOME=$out
    export PYTHONUSERBASE=${cqlsh-expansion}
    ${cqlsh-expansion}/bin/cqlsh-expansion.init
  '';

  mina-delegation-verify-auth = stdenv.mkDerivation {
    pname = "mina-delegation-verify-auth";
    version = "dev";
    src = ../src/app/delegation_verify/scripts;
    outputs = [ "out" ];
    installPhase = ''
      mkdir -p $out/bin
      cp authenticate.sh $out/bin/authenticate.sh
      chmod -R +x $out
    '';
  };

  mkFullImage = name: packages:
    dockerTools.streamLayeredImage {
      name = "${name}-full";
      inherit created;
      contents = [
        dumb-init
        coreutils
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
        env = [ "MINA_TIME_OFFSET=0" ];
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

  mina-delegation-verify-image = dockerTools.streamLayeredImage {
    name = "mina-delegation-verify";
    inherit created;
    fromImage = nix-image;
    maxLayers = 300;
    contents = [
      ocamlPackages_mina.mina-delegation-verify.out
      cqlsh-expansion
      mina-delegation-verify-init
      mina-delegation-verify-auth.out
      awscli
      jq
      coreutils
      bashInteractive
    ];
    config = {
      cmd = [ "bash" ];
      Env = [ "TZ=Etc/UTC" "TZDIR=${tzdata}/share/zoneinfo" "CQLSH=${cqlsh-expansion}/bin/cqlsh-expansion" "PYTHONUSERBASE=${cqlsh-expansion}" ];
    };
    
  };

  mina-image-full = mkFullImage "mina" (with ocamlPackages_mina; [
    mina-build-config
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
}
