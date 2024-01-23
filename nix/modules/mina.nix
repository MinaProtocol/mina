inputs:
{ pkgs, lib, config, ... }: {
  options = with lib;
    with types;
    let
      mkFlag = lib.mkOption {
        type = bool;
        default = false;
      };
    in {
      services.mina = {
        enable = mkEnableOption
          "the daemon for Mina, a lightweight, constant-size blockchain";
        config = lib.mkOption {
          type = attrs;
          default = { };
        };
        package = lib.mkOption {
          type = package;
          default = inputs.self.packages.${pkgs.system}.default;
        };
        client-port = lib.mkOption {
          type = port;
          default = 8301;
        };
        external-port = lib.mkOption {
          type = port;
          default = 8302;
        };
        rest-port = lib.mkOption {
          type = port;
          default = 3085;
        };
        external-ip = lib.mkOption {
          type = nullOr
            (strMatching "[0-9]{0,3}[.][0-9]{0,3}[.][0-9]{0,3}[.][0-9]{0,3}");
          default = null;
        };
        protocol-version = lib.mkOption {
          type = nullOr (strMatching "[0-9]+[.][0-9]+[.][0-9]+");
          default = null;
        };
        enable-peer-exchange = mkFlag;
        seed = mkFlag;
        generate-genesis-proof = mkFlag;
        log-level = lib.mkOption {
          type = enum [
            "Spam"
            "Trace"
            "Debug"
            "Info"
            "Warn"
            "Error"
            "Faulty_peer"
            "Fatal"
          ];
          default = "Info";
        };
        disable-node-status = mkFlag;
        peers = lib.mkOption {
          type = listOf str;
          default = [ ];
        };

        block-producer-key = lib.mkOption {
          type = nullOr path;
          default = null;
        };
        discovery-keypair = lib.mkOption {
          type = nullOr path;
          default = null;
        };

        waitForRpc = lib.mkOption {
          type = bool;
          default = true;
        };
        extraArgs = lib.mkOption {
          type = listOf str;
          default = [ ];
        };
      };
    };

  config = let
    cfg = config.services.mina;
    config-file = pkgs.writeText "config.json" (builtins.toJSON cfg.config);
    inherit (lib) escapeShellArg optionalString optional;
    arg = opt:
      optionalString (!isNull cfg.${opt})
      "--${opt} ${escapeShellArg (toString cfg.${opt})}";
    flag = opt: optionalString (!isNull cfg.${opt} && cfg.${opt}) "--${opt}";
    args = opt:
      toString (map (val: "--${opt} ${escapeShellArg val}") cfg."${opt}s");
  in lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.external-port ];
    users.users.mina = {
      isSystemUser = true;
      group = "mina";
    };
    users.groups.mina = { };
    systemd.services.mina = {
      wantedBy = [ "multi-user.target" ];
      path = [ cfg.package ] ++ optional cfg.waitForRpc pkgs.netcat;
      script = ''
        mina daemon \
          --config-file ${config-file} \
          --config-dir "$STATE_DIRECTORY" \
          --working-dir "$STATE_DIRECTORY" \
          ${arg "log-level"} \
          ${arg "external-port"} \
          ${arg "client-port"} \
          ${arg "rest-port"} \
          ${arg "external-ip"} \
          ${arg "protocol-version"} \
          ${arg "block-producer-key"} \
          ${arg "discovery-keypair"} \
          ${
            optionalString cfg.generate-genesis-proof
            "--generate-genesis-proof true"
          } \
          ${flag "disable-node-status"} \
          ${flag "enable-peer-exchange"} \
          ${flag "seed"} \
          ${args "peer"} \
          ${toString (map escapeShellArg cfg.extraArgs)} \
          &
        ${optionalString cfg.waitForRpc ''
          until nc -z 127.0.0.1 ${toString cfg.client-port}; do
            if ! jobs %% > /dev/null 2> /dev/null; then
              echo "Mina daemon crashed before the RPC socket is up"
              exit 1
            fi
            sleep 1
          done
        ''}
      '';
      serviceConfig = {
        PrivateTmp = true;
        ProtectHome = "yes";
        User = "mina";
        Group = "mina";
        StateDirectory = "mina";
        Type = "forking";
        # Mina daemon can take a while to start up
        TimeoutStartSec = "15min";
      };
    };
  };

}
