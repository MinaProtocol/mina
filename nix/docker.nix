{ lib, dockerTools, buildEnv, ocamlPackages_mina, linkFarm, runCommand
, dumb-init, tzdata, coreutils, findutils, bashInteractive, python3
, libp2p_helper, procps, postgresql, curl, jq, stdenv, rsync, bash, gnutar, gzip
, currentTime, flockenzeit, }:
let
  created = flockenzeit.lib.ISO-8601 currentTime;

  mkdir = name:
    runCommand "mkdir-${name}" { } "mkdir -p $out${lib.escapeShellArg name}";

  mina-daemon-scripts = stdenv.mkDerivation {
    pname = "mina-daemon-scripts";
    version = "dev";
    src = ../dockerfiles;
    buildInputs = [ python3 bash ]; # For patchShebang-ing
    installPhase = ''
      mkdir -p $out/healthcheck $out/entrypoint.d $out/var/lib/coda
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

  basePkgs = [
    dumb-init
    coreutils
    findutils
    bashInteractive
    python3
    procps
    curl
    jq
    localtime
    zoneinfo
  ];

  baseImage = name: pkgs:
    dockerTools.buildImage {
      inherit name;
      copyToRoot = basePkgs ++ pkgs;
    };

  mina-exe = ocamlPackages_mina.exes.mina;

  mkFullImage = name: packages: fromImage: additional_envs:
    dockerTools.streamLayeredImage {
      inherit fromImage;
      name = "${name}-full";
      inherit created;
      contents = [ libp2p_helper ] ++ packages;
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
    contents = [ mina-exe ];
  };

  mina-image-full = mkFullImage "mina" [ mina-exe ]
    (baseImage "mina-base" [ mina-daemon-scripts ]) [ ];

  mina-archive-image-full =
    mkFullImage "mina-archive" [ ocamlPackages_mina.exes.archive ]
    (baseImage "mina-base-archive" [ mina-archive-scripts gnutar gzip ]) [ ];
}
