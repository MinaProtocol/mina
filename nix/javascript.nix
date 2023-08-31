final: prev:
let
  inherit (final)
    pkgs stdenv writeScript nix-npm-buildPackage ocamlPackages_mina plonk_wasm;
in {
  client_sdk = nix-npm-buildPackage.buildYarnPackage {
    name = "client_sdk";
    src = ../frontend/client_sdk;
    yarnPostLink = writeScript "yarn-post-link" ''
      #!${stdenv.shell}
      ls node_modules/bs-platform/lib/*.linux
      patchelf \
        --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${stdenv.cc.cc.lib}/lib" \
        ./node_modules/bs-platform/lib/*.linux ./node_modules/bs-platform/vendor/ninja/snapshot/*.linux ./node_modules/gentype/vendor-linux/gentype.exe
    '';
    yarnBuildMore = ''
      cp ${ocamlPackages_mina.mina_client_sdk}/share/client_sdk/client_sdk.bc.js src
      yarn build
    '';
    installPhase = ''
      mkdir -p $out/share/client_sdk
      mv src/*.js $out/share/client_sdk
    '';
  };
  snarky_js = nix-npm-buildPackage.buildNpmPackage {
    src = ../src/lib/snarkyjs;
    preBuild = ''
      BINDINGS_PATH=./src/bindings/compiled/node_bindings
      mkdir -p "$BINDINGS_PATH"
      cp ${plonk_wasm}/nodejs/plonk_wasm* "$BINDINGS_PATH"
      cp ${ocamlPackages_mina.mina_client_sdk}/share/snarkyjs_bindings/snarky_js_node*.js "$BINDINGS_PATH"
      chmod -R 777 "$BINDINGS_PATH"

      # TODO: deduplicate from ./scripts/build-snarkyjs-node.sh
      # better error messages
      # TODO: find a less hacky way to make adjustments to jsoo compiler output
      # `s` is the jsoo representation of the error message string, and `s.c` is the actual JS string
      sed -i 's/function failwith(s){throw \[0,Failure,s\]/function failwith(s){throw globalThis.Error(s.c)/' "$BINDINGS_PATH"/snarky_js_node.bc.js
      sed -i 's/function invalid_arg(s){throw \[0,Invalid_argument,s\]/function invalid_arg(s){throw globalThis.Error(s.c)/' "$BINDINGS_PATH"/snarky_js_node.bc.js
      sed -i 's/return \[0,Exn,t\]/return globalThis.Error(t.c)/' "$BINDINGS_PATH"/snarky_js_node.bc.js
    '';
    npmBuild = "npm run build";
  };

  # Jobs/Release/LeaderboardArtifact
  leaderboard = nix-npm-buildPackage.buildYarnPackage {
    src = ../frontend/leaderboard;
    yarnBuildMore = "yarn build";
    # fix reason
    yarnPostLink = writeScript "yarn-post-link" ''
      #!${stdenv.shell}
      ls node_modules/bs-platform/lib/*.linux
      patchelf \
        --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${stdenv.cc.cc.lib}/lib" \
        ./node_modules/bs-platform/lib/*.linux ./node_modules/bs-platform/vendor/ninja/snapshot/*.linux
    '';
    # todo: external stdlib @rescript/std
    preInstall = ''
      shopt -s extglob
      rm -rf node_modules/bs-platform/lib/!(js)
      rm -rf node_modules/bs-platform/!(lib)
      rm -rf yarn-cache
    '';
  };

  zkapp-cli = nix-npm-buildPackage.buildNpmPackage {
    src = pkgs.fetchFromGitHub {
      owner = "o1-labs";
      repo = "zkapp-cli";
      rev = "b6542ccca0ce94d61c29edf519cd0eecaf9332fb";
      sha256 = "sha256-R1Pb1OcjzvuJ0t/7+tq+QDke7E9aRmNmUxbR7QtVJOE=";
    };
    doCheck = true;
    preInstall = "npm prune";
    dontNpmPrune = true; # running npm prune --production removes husky which seems actually needed
    postInstall = ''
      ln -s $out/src/bin/index.js $out/bin/zk
      ln -s $out/src/bin/index.js $out/bin/zkapp
      ln -s $out/src/bin/index.js $out/bin/zkapp-cli
    '';
  };
}
