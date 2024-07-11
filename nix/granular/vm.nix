# Some tests can't be executed in nix environment (e.g.
# test that start a local network), a workaround is to run
# them in QEMU virtual machine
{ pkgs, util, ... }:
let
  vmTestScript = self: pkg: buildCmd:
    let
      pkgEnvVar = util.artifactEnvVar [ "pkgs" pkg ];
      script = pkgs.writeShellScriptBin "runtest-${pkg}" ''
        set -eo pipefail
        PATH_BK="$PATH"
        source "$(which env-${pkg})" || true # Ignore read-only variables
        source $stdenv/setup
        export NIX_STORE=/nix/store
        export NIX_BUILD_TOP=/home/builder/build
        export NIX_ENFORCE_NO_NATIVE=0
        export NIX_ENFORCE_PURITY=0
        export NIX_HARDENING_ENABLE=""
        mkdir -p $NIX_BUILD_TOP
        phases='unpackPhase patchPhase configurePhase' genericBuild
        envVar="${pkgEnvVar}"
        echo "Reusing build artifacts from: ''${!envVar}"
        cp --no-preserve=mode,ownership -RL "''${!envVar}" _build
        export dontCheck=0
        export phases='buildPhase'
        export PATH="$PATH:$PATH_BK"
        ${buildCmd}
      '';
      drv = self.pkgs."${pkg}";
    in [ script drv ];

  vmTest = virtualisation: self: pkg: auxBuildInputs: buildCmd:
    let vmScript = vmTestScript self pkg buildCmd ++ auxBuildInputs;
    in mkVmTest virtualisation vmScript pkg;

  mkVmTest = virtualisation: packages: name:
    pkgs.testers.runNixOSTest {
      name = "vmtest-${name}";
      nodes.machine = { config, pkgs, ... }: {
        security.pam.loginLimits = [{
          domain = "*";
          type = "soft";
          item = "nofile";
          value = "65536";
        }];
        users.users.builder = {
          isNormalUser = true;
          home = "/home/builder";
          extraGroups = [ "wheel" ];
          inherit packages;
        };
        system.stateVersion = "23.11";
        virtualisation = {
          graphics = false;
          cores = 8;
          memorySize = 16384; # TODO Lower the requirement
          diskSize = 4096;
        } // virtualisation;
      };
      testScript = ''
        machine.wait_for_unit("default.target")
        machine.succeed("cd /home/builder && su -- builder -c 'runtest-${name}'")
      '';
    };
  vmTestOverrides = pkg:
    let envVar = util.artifactEnvVar [ "pkgs" pkg ];
    in {
      postInstall = ''
        mkdir -p $out/bin
        declare > $out/bin/env-${pkg}
        echo "export ${envVar}=$out" >> $out/bin/env-${pkg}
        chmod +x $out/bin/env-${pkg}
      '';
    };
  testWithVm' = buildCmd: virtualisation: pkg: auxBuildInputs: self: super: {
    pkgs."${pkg}" = super.pkgs."${pkg}".overrideAttrs (vmTestOverrides pkg);
    tested."${pkg}" = vmTest virtualisation self pkg auxBuildInputs buildCmd;
  };
  testWithVm = testWithVm' "genericBuild";
in { inherit vmTest vmTestOverrides testWithVm testWithVm'; }
