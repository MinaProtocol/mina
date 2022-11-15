{ lib, dockerTools, buildEnv, ocamlPackages_mina, runCommand, dumb-init
, coreutils, bashInteractive, python3, libp2p_helper, procps, postgresql, curl
, jq, stdenv, rsync, bash, gnutar, gzip, gnused, cacert, writeShellScript, doas
, less, shadow }:
let
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

  init-rosetta-db = writeShellScript "init-db" ''
    MINA_NETWORK=$1
    POSTGRES_DBNAME=$2
    POSTGRES_USERNAME=$3
    POSTGRES_DATA_DIR=$4
    DUMP_TIME=''${5:=0000}
    PG_CONN=postgres://$POSTGRES_USERNAME:$POSTGRES_USERNAME@127.0.0.1:5432/$POSTGRES_DBNAME

    useradd -r -u 0 -U -d /root root
    useradd -r -U -M postgres

    echo 'permit nopass root' > /etc/doas.conf

    mkdir -p /run/postgresql /data/postgresql

    chown postgres:postgres /data/postgresql /run/postgresql

    doas -u postgres initdb -D $POSTGRES_DATA_DIR --auth trust --auth-local trust -g
    doas -u postgres pg_ctl -D $POSTGRES_DATA_DIR start
    doas -u postgres psql -c "SHOW ALL;"
    doas -u postgres psql -c "CREATE USER \"$POSTGRES_USERNAME\" WITH SUPERUSER PASSWORD '$POSTGRES_USERNAME';"
    doas -u postgres createdb -O $POSTGRES_USERNAME $POSTGRES_DBNAME
    DATE="$(date -Idate)_$DUMP_TIME"
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    curl "https://storage.googleapis.com/mina-archive-dumps/''${MINA_NETWORK}-archive-dump-''${DATE}.sql.tar.gz" -o o1labs-archive-dump.tar.gz
    tar -xvf o1labs-archive-dump.tar.gz
    doas -u postgres psql -f "''${MINA_NETWORK}-archive-dump-''${DATE}.sql" "$PG_CONN"
    rm -f o1labs-archive-dump.tar.gz
    echo "[POPULATE] Top 10 blocks in populated archiveDB:"
    psql "$PG_CONN" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
  '';

  mina-rosetta-scripts = stdenv.mkDerivation {
    pname = "mina-rosetta-scripts";
    version = "dev";
    buildCommand = ''
      mkdir -p $out/rosetta
      cp -r ${../src/app/rosetta}/{*.sh,*.conf,*.json} $out/rosetta
      chmod -R +x $out
      rm $out/rosetta/init-db.sh
      ln -s ${init-rosetta-db} $out/rosetta/init-db.sh
      sed 's/pg_ctlcluster ''${POSTGRES_VERSION} main/doas -u postgres pg_ctl/' -i $out/rosetta/docker-start.sh
      cp -r "${../genesis_ledgers}" $out/genesis_ledgers
      patchShebangs $out
    '';
  };

  mkFullImage = name: packages: extraArgs:
    dockerTools.streamLayeredImage (lib.recursiveUpdate {
      name = "${name}-full";
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
    } extraArgs);

in {
  mina-image-slim = dockerTools.streamLayeredImage {
    name = "mina";
    contents = [ ocamlPackages_mina.mina.out ];
  };
  mina-image-full = mkFullImage "mina" (with ocamlPackages_mina; [
    mina-build-config
    mina-daemon-scripts

    mina.out
    mina.mainnet
    mina.genesis
  ]) { };
  mina-archive-image-full = mkFullImage "mina-archive"
    (with ocamlPackages_mina; [
      mina-archive-scripts
      gnutar
      gzip

      mina.archive
    ]) { };
  mina-rosetta-image-full = mkFullImage "mina-rosetta"
    (with ocamlPackages_mina; [
      mina-rosetta-scripts

      gnutar
      gzip
      postgresql
      gnused
      (doas.override { withPAM = false; })
      shadow
      less

      mina.out
      mina.rosetta
      mina.archive
      mina.mainnet
    ]) {
      config = {
        cmd = [ "/bin/dumb-init" "/rosetta/docker-start.sh" ];
        WorkingDir = "/rosetta";
      };
    };
}
