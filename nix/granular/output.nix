{ pkgs, util, pathFilter, deps, show, ... }@args:
let
  # Patch phase is used to propagate file/exe dependencies
  genPatchPhase = info: self: fileDeps: exeDeps: buildInputs:
    let
      traverseExes = f:
        builtins.concatLists (pkgs.lib.mapAttrsToList (pkg: nameMap:
          builtins.map (name: f pkg name info.packages."${pkg}".exe."${name}")
          (builtins.attrNames nameMap)) exeDeps);
      exes = traverseExes (pkg: key:
        { src, name, ... }:
        let exeEnvVar = util.artifactEnvVar [ "all-exes" pkg key ];
        in "'${exeEnvVar}' '${key}' '${src}/${name}.exe'");
      # TODO if exe is public, try to promote to package dependency and use as such
      installExes = if exes == [ ] then
        ""
      else ''
        exesArr=( ${builtins.concatStringsSep " " exes} )
        for i in {0..${builtins.toString (builtins.length exes - 1)}}; do
          drvEnvName="''${exesArr[$i*3]}"
          drv="''${!drvEnvName}"
          exe="''${exesArr[$i*3+1]}"
          dst="''${exesArr[$i*3+2]}"
          install -D "$drv/bin/$exe" "$dst"
        done
      '';
      exeInputs = traverseExes (pkg: key: _: self.all-exes."${pkg}"."${key}");
      fileInputs = builtins.map (dep: self.files."${util.quote dep}")
        (builtins.attrNames fileDeps);
    in {
      fileDeps = builtins.map (dep: util.artifactEnvVar [ "files" dep ])
        (builtins.attrNames fileDeps);
      patchPhase = ''
        runHook prePatch

        for fileDepEnvName in $fileDeps; do
          cp --no-preserve=mode,ownership -RLTu "''${!fileDepEnvName}" ./
        done
        ${installExes}

        runHook postPatch
      '';
      buildInputs = buildInputs ++ exeInputs ++ fileInputs;
    };

  installNixSupportFile = src:
    let envVar = util.artifactEnvVar [ "files" src ];
    in ''
      mkdir -p $out/nix-support
      echo "export ${envVar}=$out" > $out/nix-support/setup-hook
    '';

  installNixSupportExe = pkg: key:
    let envVar = util.artifactEnvVar [ "all-exes" pkg key ];
    in ''
      mkdir -p $out/nix-support
      echo "export ${envVar}=$out" > $out/nix-support/setup-hook
    '';

  installNixSupportPkg = pkg:
    let envVar = util.artifactEnvVar [ "pkgs" pkg ];
    in ''
      mkdir -p $out/nix-support
      {
        echo -n 'export OCAMLPATH=$'
        echo -n '{OCAMLPATH-}$'
        echo '{OCAMLPATH:+:}'"$out/install/default/lib"
        if [[ -d $out/install/default/lib/stublibs ]]; then
          echo -n 'export CAML_LD_LIBRARY_PATH=$'
          echo -n '{CAML_LD_LIBRARY_PATH-}$'
          echo '{CAML_LD_LIBRARY_PATH:+:}'"$out/install/default/lib/stublibs"
        fi
        echo "export ${envVar}=$out"
      } > $out/nix-support/setup-hook
      [ ! -d $out/install/default/bin ] || ln -s install/default/bin $out/bin
    '';

  # Make separate libs a separately-built derivation instead of `rm -Rf` hack
  genPackage = separatedPackages: allDeps: info: self: pkg: pkgDef:
    let
      sepPackages = separatedPackages pkg;
      packageArg = if info.pseudoPackages ? "${pkg}" then
        info.pseudoPackages."${pkg}"
      else
        "@install --only-packages=${pkg}";
    in if sepPackages != [ ] then
      throw "Package ${pkg} has separated lib dependency to packages ${
        builtins.concatStringsSep ", " sepPackages
      }"
    else
      let
        pkgDeps = builtins.filter (d: !(info.pseudoPackages ? "${d}"))
          (builtins.attrNames (deps.packageDeps allDeps "pkgs" pkg));
        buildInputs = pkgs.lib.attrVals pkgDeps self.pkgs;
      in pkgs.stdenv.mkDerivation ({
        pname = pkg;
        version = "dev";
        src = self.src.pkgs."${pkg}";
        dontCheck = true;
        buildPhase = ''
          runHook preBuild

          runtest=""
          if [[ "$dontCheck" != 1 ]]; then
            echo "Running tests for ${pkg}"
            runtest=" @runtest "
          fi

          dune build $runtest ${packageArg} \
            -j $NIX_BUILD_CORES --root=. --build-dir=_build

          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall

          mv _build $out
          ${installNixSupportPkg pkg}

          runHook postInstall
        '';
      } // genPatchPhase info self (deps.packageDeps allDeps "files" pkg)
        (deps.packageDepsMulti allDeps "exes" pkg) buildInputs);

  genTestedPackage = info: self: pkg: _:
    let
      drv = self.pkgs."${pkg}";
      pkgEnvVar = util.artifactEnvVar [ "pkgs" pkg ];
      # For detached units (with no package) there is no need to rely on pre-built
      # libraries/executables because a detached unit can't be a dependency of another
      # package, hence no use to introduce indirection
      usePrebuilt = s:
        if info.pseudoPackages ? "${pkg}" then
          { }
        else {
          postPatch = ''
            envVar="${pkgEnvVar}"
            echo "Reusing build artifacts from: ''${!envVar}"
            cp --no-preserve=mode,ownership -RL "''${!envVar}" _build
          '';
          buildInputs = s.buildInputs ++ [ drv ];
        };
    in drv.overrideAttrs (s:
      usePrebuilt s // {
        pname = "test-${pkg}";
        installPhase = "touch $out";
        dontCheck = false;
      });

  genExe = allDeps: info: self: pkg: name: exeDef:
    let
      deps = field: allDeps.units."${pkg}".exe."${name}"."${field}" or { };
      pkgDeps = builtins.filter (d: !(info.pseudoPackages ? "${d}"))
        (builtins.attrNames (deps "pkgs"));
      buildInputs = pkgs.lib.attrVals pkgDeps self.pkgs;
    in pkgs.stdenv.mkDerivation ({
      pname = "${name}.exe";
      version = "dev";
      src = self.src.all-exes."${pkg}"."${name}";
      buildPhase = ''
        runHook preBuild

        dune build -j $NIX_BUILD_CORES --root=. --build-dir=_build "${exeDef.src}/${exeDef.name}.exe"

        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin
        mv "_build/default/${exeDef.src}/${exeDef.name}.exe" $out/bin/${name}
        ${installNixSupportExe pkg name}

        runHook postInstall
      '';
    } // genPatchPhase info self (deps "files") (deps "exes") buildInputs);

  genFile = allDeps: info: self: pname: src:
    let deps = field: allDeps.files."${src}"."${field}";
    in pkgs.stdenv.mkDerivation ({
      inherit pname;
      version = "dev";
      src = self.src.files."${pname}";
      fileOuts = builtins.concatStringsSep " "
        (builtins.attrNames info.srcInfo."${src}".file_outs);
      buildPhase = ''
        runHook preBuild

        dune build $fileOuts

        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall

        rm -Rf _build/default/.*
        mv _build/default $out
        ${installNixSupportFile src}

        runHook postInstall
      '';
    } // genPatchPhase info self (deps "files") (deps "exes") [ ]);

  duneAndFileDepsFilters = info: src:
    let
      duneFile = if src == "." then "dune" else "${src}/dune";
      notAnOutput = dep:
        !(info.fileOuts2Src ? "${dep}" || info.exes ? "${dep}");
      srcFiles = [ duneFile ] ++ builtins.attrNames
        info.srcInfo."${src}".file_outs
        # ^ include out files is they exist in file system so that dune can handle mode correctly
        ++ builtins.filter notAnOutput info.srcInfo."${src}".file_deps;
    in builtins.map pathFilter.all srcFiles;

  unitFilters = src: duneSubdirs: includeSubdirs:
    { with_standard, include, exclude }:
    let
      srcPrefix = if src == "." then "" else "${src}/";
      mapModuleFiles = f: a:
        builtins.map pathFilter.all [
          "${srcPrefix}${a}.ml"
          "${srcPrefix}${a}.mli"
        ];
      srcParts = if src == "." then [ ] else pkgs.lib.splitString "/" src;
      exclude' =
        # Commented out because although dune doesn't need the module,
        # it still wants it to be present in filesystem
        # builtins.concatMap (a: [ [ "${a}.ml" ] [ "${a}.mli" ] ]) exclude ++
        builtins.map (pkgs.lib.splitString "/") duneSubdirs;
    in builtins.concatMap (mapModuleFiles pathFilter.all) include
    ++ (if with_standard then
      [
        (pathFilter.create {
          type = if includeSubdirs then 1 else 0;
          ext = [ "ml" "mli" ];
          exclude = exclude';
        } src)
      ]
    else
      [ ]);

  unitSourceFilters = info:
    { src, ... }@unit:
    duneAndFileDepsFilters info src
    ++ unitFilters src (info.srcInfo."${src}".subdirs or [ ])
    ((info.srcInfo."${src}".include_subdirs or "no") != "no") ({
      with_standard = true;
      include = [ ];
      exclude = [ ];
    } // (unit.modules or { }));

  unitSourceFiltersWithExtra = info: extraLibs: unit:
    let
      extraUnits = builtins.concatLists (pkgs.lib.mapAttrsToList
        (pkg: libs: pkgs.lib.attrVals libs info.packages."${pkg}".lib)
        extraLibs);
    in builtins.concatMap (unitSourceFilters info) ([ unit ] ++ extraUnits);

  # Only sources, without dependencies built by other derivations
  genPackageSrc = root: allDeps: info: pkg: pkgDef:
    let
      pseudoPkgDeps = builtins.filter (d: info.pseudoPackages ? "${d}")
        (builtins.attrNames (deps.packageDeps allDeps "pkgs" pkg));
      sepLibs = builtins.mapAttrs (_: { lib, ... }: builtins.attrNames lib)
        (pkgs.lib.getAttrs pseudoPkgDeps info.packages);
      filters = builtins.concatLists (builtins.concatLists
        (pkgs.lib.mapAttrsToList (_:
          pkgs.lib.mapAttrsToList (_: unitSourceFiltersWithExtra info sepLibs))
          pkgDef));
    in pathFilter.toPath {
      path = root;
      name = "source-${pkg}";
    } (pathFilter.merge filters);
  genExeSrc = root: allDeps: info: pkg: name: exeDef:
    let
      deps = field: allDeps.units."${pkg}".exe."${name}"."${field}" or { };
      pseudoPkgDeps = builtins.filter (d: info.pseudoPackages ? "${d}")
        (builtins.attrNames (deps "pkgs"));
      sepLibs = builtins.mapAttrs (_: builtins.attrNames) ((deps "libs")
        // builtins.mapAttrs (_: { lib, ... }: lib)
        (pkgs.lib.getAttrs pseudoPkgDeps info.packages));
    in pathFilter.toPath {
      path = root;
      name = "source-${name}-exe";
    } (pathFilter.merge (unitSourceFiltersWithExtra info sepLibs exeDef));
  genFileSrc = root: info: name: src:
    pathFilter.toPath {
      path = root;
      inherit name;
    } (pathFilter.merge (duneAndFileDepsFilters info src));

  mkOutputs =
    info: allFileDeps: genPackage: genTestedPackage: genExe: genFile: {
      pkgs = builtins.mapAttrs genPackage info.packages;
      tested = builtins.mapAttrs genTestedPackage info.packages;
      all-exes = builtins.mapAttrs
        (pkg: { exe, ... }: builtins.mapAttrs (genExe pkg) exe)
        (pkgs.lib.filterAttrs (_: v: v ? "exe") info.packages);
      files = pkgs.lib.mapAttrs' (k: _:
        let name = util.quote k;
        in {
          inherit name;
          value = genFile name k;
        }) allFileDeps;
    };

  overrideDerivations = overrides: outputs:
    let
      buildInputs = overrides.buildInputs or [ ];
      nativeBuildInputs = overrides.nativeBuildInputs or [ ];
      modifyDo = _: drv:
        drv.overrideAttrs (s:
          overrides // {
            buildInputs = (s.buildInputs or [ ]) ++ buildInputs;
            nativeBuildInputs = (s.nativeBuildInputs or [ ])
              ++ nativeBuildInputs;
          });
    in outputs // {
      pkgs = builtins.mapAttrs modifyDo outputs.pkgs;
      tested = builtins.mapAttrs modifyDo outputs.tested;
      files = builtins.mapAttrs modifyDo outputs.files;
      all-exes =
        builtins.mapAttrs (_: builtins.mapAttrs modifyDo) outputs.all-exes;
    };

  mkCombined = name: buildInputs:
    pkgs.stdenv.mkDerivation {
      inherit name buildInputs;
      phases = [ "buildPhase" "installPhase" ];
      buildPhase = ''
        echo "Build inputs: $buildInputs"
      '';
      installPhase = ''
        touch $out
      '';
    };

  testOrPkgImpl = noTest: info: self: pkg:
    let
      hasTestDefs = !noTest && util.packageHasTestDefs info.packages."${pkg}";
      isPseudo = info.pseudoPackages ? "${pkg}";
    in if hasTestDefs && isPseudo then
      [ self.tested."${pkg}" ]
    else if hasTestDefs && !isPseudo then [
      self.pkgs."${pkg}"
      self.tested."${pkg}"
    ] else
      [ self.pkgs."${pkg}" ];
  testOrPkg = testOrPkgImpl false;
  testOrPkg' = testByDefault: info: self: pkg:
    testOrPkgImpl (testByDefault info.packages."${pkg}") info self pkg;

  outputs' = commonOverrides: rootPath: allDeps: info: testByDefault: self:
    overrideDerivations commonOverrides
    (outputs rootPath allDeps info testByDefault self) // {
      info = {
        src = pkgs.writeText "src-info.json" (builtins.toJSON info.srcInfo);
        exe = pkgs.writeText "exes.json" (builtins.toJSON info.exes);
        package =
          pkgs.writeText "packages.json" (builtins.toJSON info.packages);
        separated-libs = pkgs.writeText "separated-libs.json"
          (builtins.toJSON (deps.separatedLibs allDeps));
        deps = pkgs.writeText "all-deps.json" (show.allDepsToJSON allDeps);
        deps-graph = pkgs.writeText "packages.dot" show.packagesDotGraph;
      };
    };
  outputs = rootPath: allDeps: info: testByDefault: self:
    let
      packageNames = builtins.attrNames info.packages;
      separatedLibs = deps.separatedLibs allDeps;
      separatedPackages = pkg:
        builtins.attrNames (util.attrFold (acc0: type:
          util.attrFold (acc1: name: _:
            acc1 // (separatedLibs."${pkg}"."${type}"."${name}" or { })) acc0)
          { } info.packages."${pkg}");
    in mkOutputs info allDeps.files
    (genPackage separatedPackages allDeps info self)
    (genTestedPackage info self) (genExe allDeps info self)
    (genFile allDeps info self) // {
      src = mkOutputs info allDeps.files (genPackageSrc rootPath allDeps info)
        (genPackageSrc rootPath allDeps info) (genExeSrc rootPath allDeps info)
        (genFileSrc rootPath info);
      exes = builtins.foldl' (acc:
        { package, name }:
        # TODO for exes within packages, use package derivation
        acc // {
          "${name}" = if acc ? "${name}" then
            throw "Executable with name ${name} defined more than once"
          else
            self.all-exes."${package}"."${name}";
        }) { } (builtins.attrValues info.exes) // {
          libp2p_helper = pkgs.libp2p_helper;
        };
      all =
        mkCombined "all" (builtins.map (pkg: self.pkgs."${pkg}") packageNames);
      default = mkCombined "default"
        (builtins.concatMap (testOrPkg' testByDefault info self) packageNames);
      all-tested = mkCombined "all-tested"
        (builtins.concatMap (testOrPkg info self) packageNames);
    };
in { inherit outputs outputs' overrideDerivations; }
