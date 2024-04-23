# A set defining OCaml parts&dependencies of Minaocamlnix
{ inputs, ... }@args:
let
  opam-nix = inputs.opam-nix.lib.${pkgs.system};

  inherit (args) pkgs;

  inherit (builtins) filterSource path;

  inherit (pkgs.lib)
    hasPrefix last getAttrs filterAttrs optionalAttrs makeBinPath optionalString
    escapeShellArg;

  repos = with inputs; [ o1-opam-repository opam-repository ];

  export = opam-nix.importOpam ../opam.export;

  # Dependencies required by every Mina package:
  # Packages which are `installed` in the export.
  # These are all the transitive ocaml dependencies of Mina.
  implicit-deps =
    builtins.removeAttrs (opam-nix.opamListToQuery export.installed)
    [ "check_opam_switch" ];

  # Extra packages which are not in opam.export but useful for development, such as an LSP server.
  extra-packages = with implicit-deps; {
    dune-rpc = "3.5.0";
    dyn = "3.5.0";
    fiber = "3.5.0";
    chrome-trace = "3.5.0";
    ocaml-lsp-server = "1.15.1-4.14";
    ocamlc-loc = "3.5.0";
    ocaml-system = ocaml;
    ocamlformat-rpc-lib = "0.22.4";
    omd = "1.3.2";
    ordering = "3.5.0";
    pp = "1.1.2";
    ppx_yojson_conv_lib = "v0.15.0";
    stdune = "3.5.0";
    xdg = dune;
  };

  implicit-deps-overlay = self: super:
    (if pkgs.stdenv.isDarwin then {
      async_ssl = super.async_ssl.overrideAttrs {
        NIX_CFLAGS_COMPILE =
          "-Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types";
      };
    } else
      { }) // {
        # https://github.com/Drup/ocaml-lmdb/issues/41
        lmdb = super.lmdb.overrideAttrs
          (oa: { buildInputs = oa.buildInputs ++ [ self.conf-pkg-config ]; });

        # Doesn't have an explicit dependency on ctypes-foreign
        ctypes = super.ctypes.overrideAttrs
          (oa: { buildInputs = oa.buildInputs ++ [ self.ctypes-foreign ]; });

        # Can't find sodium-static and ctypes
        sodium = super.sodium.overrideAttrs {
          NIX_CFLAGS_COMPILE = "-I${pkgs.sodium-static.dev}/include";
          propagatedBuildInputs = [ pkgs.sodium-static ];
          preBuild = ''
            export LD_LIBRARY_PATH="${super.ctypes}/lib/ocaml/${super.ocaml.version}/site-lib/ctypes";
          '';
        };

        rocksdb_stubs = super.rocksdb_stubs.overrideAttrs {
          MINA_ROCKSDB = "${pkgs.rocksdb-mina}/lib/librocksdb.a";
        };

        # This is needed because
        # - lld package is not wrapped to pick up the correct linker flags
        # - bintools package also includes as which is incompatible with gcc
        lld_wrapped = pkgs.writeShellScriptBin "ld.lld"
          ''${pkgs.llvmPackages.bintools}/bin/ld.lld "$@"'';
      };

  scope =
    opam-nix.applyOverlays (opam-nix.__overlays ++ [ implicit-deps-overlay ])
    (opam-nix.defsToScope pkgs { }
      (opam-nix.queryToDefs repos (extra-packages // implicit-deps)));

  installedPackageNames =
    map (x: (opam-nix.splitNameVer x).name) (builtins.attrNames implicit-deps);

  sourceInfo = inputs.self.sourceInfo or { };

  # "System" dependencies required by all Mina packages
  external-libs = with pkgs;
    [ zlib bzip2 gmp openssl libffi ]
    ++ lib.optional (!(stdenv.isDarwin && stdenv.isAarch64)) jemalloc;

  dune-description = pkgs.stdenv.mkDerivation {
    pname = "dune-description";
    version = "dev";
    src = pkgs.lib.sources.sourceFilesBySuffices ../src [
      "dune"
      "dune-project"
      ".inc"
      ".opam"
    ];
    phases = [ "unpackPhase" "buildPhase" ];
    buildPhase = ''
      files=$(ls)
      mkdir src
      mv $files src
      cp ${../dune} dune
      cp ${../dune-project} dune-project
      ${
        inputs.describe-dune.defaultPackage.${pkgs.system}
      }/bin/describe-dune > $out
    '';
  };

  duneDescLoaded = builtins.fromJSON (builtins.readFile dune-description);
  duneOutFiles = builtins.foldl' (acc0: el:
    let
      extendAcc = acc: file:
        acc // {
          "${file}" = if acc ? "${file}" then
            builtins.throw
            "File ${file} is defined as output of many dune files"
          else
            el.src;
        };
      extendAccExe = acc: unit:
        if unit.type == "exe" then
          extendAcc acc "${el.src}/${unit.name}.exe"
        else
          acc;
      acc1 = builtins.foldl' extendAcc acc0 el.file_outs;
    in builtins.foldl' extendAccExe acc1 el.units) { } duneDescLoaded;

  collectLibLocs = attrName:
    let
      extendAcc = src: acc: name:
        acc // {
          "${name}" = if acc ? "${name}" then
            builtins.throw
            "Library with ${attrName} ${name} is defined in multiple dune files"
          else
            src;
        };
      extendAccLib = src: acc: unit:
        if unit.type == "lib" && unit ? "${attrName}" then
          extendAcc src acc unit."${attrName}"
        else
          acc;
      foldF = acc0: el: builtins.foldl' (extendAccLib el.src) acc0 el.units;
    in builtins.foldl' foldF { };

  quote = builtins.replaceStrings [ "." "/" ] [ "__" "-" ];

  # Mapping packages: package -> { lib: {public_name|name -> loc}, exe: {..}, test: {..} }
  # Mapping lib2Pkg: lib -> pkg (from library name to package)
  # Mapping lib2RawLibs: lib -> [lib] (library dependencies as in the unit definition)
  # Mapping implements: lib -> lib (for libraries that implement other libraries)
  # Mapping pubNames: lib's name -> lib's public_name (if such exists)
  # Mapping exes: .exe path -> { package, name }
  # Mapping src2Pkgs: src path -> [package name]
  # Mapping pkg2RawExtraDeps: pkg -> [lib]
  info = let
    extendAccDef = defVal: name: val: acc:
      acc // {
        "${name}" = if acc ? "${name}" then defVal else val;
      };
    extendAccImpl = msg: name: val: acc:
      acc // {
        "${name}" = if acc ? "${name}" then builtins.throw msg else val;
      };
    extendAcc = pkg: name:
      extendAccImpl
      "Unit with package ${pkg} name ${name} is defined in multiple dune files"
      name;
    handleFileDepMaps = el:
      { fileOuts2Src, src2FileDeps, ... }@acc:
      let
        fileOuts2Src' = builtins.foldl' (acc': out:
          extendAccImpl "Output ${out} appears twice in dune files" out el.src
          acc') fileOuts2Src el.file_outs;
        src2FileDeps' =
          extendAccImpl "Source ${el.src} appears twice in dune description"
          el.src el.file_deps src2FileDeps;
      in acc // {
        fileOuts2Src = fileOuts2Src';
        src2FileDeps = src2FileDeps';
      };
    extendAccLib = src:
      { packages, lib2RawDeps, lib2Pkg, implements, pubNames, exes, src2Pkgs
      , pkg2RawExtraDeps, ... }@acc:
      unit:
      let
        pkg = if unit ? "package" then
          unit.package
        else if unit ? "public_name" && unit.type == "lib" then
          builtins.head (pkgs.lib.splitString "." unit.public_name)
        else
          "__${quote src}__";
        name = if unit ? "public_name" then unit.public_name else unit.name;
        unitInfo = unit // { inherit src; };
        packages' = if packages ? "${pkg}" then
          packages // {
            "${pkg}" = packages."${pkg}" // {
              "${unit.type}" =
                extendAcc pkg name unitInfo packages."${pkg}"."${unit.type}";
            };
          }
        else
          packages // {
            "${pkg}" = {
              lib = { };
              exe = { };
              test = { };
            } // {
              "${unit.type}" = { "${name}" = unitInfo; };
            };
          };
        lib2RawDeps' = if unit.type == "lib" then
          extendAcc pkg name unit.deps lib2RawDeps
        else
          lib2RawDeps;
        lib2Pkg' = if unit.type == "lib" then
          extendAcc pkg name pkg lib2Pkg
        else
          lib2Pkg;
        pubNames' = if unit.type == "lib" && unit ? "public_name" then
          extendAccDef "" unit.name unit.public_name pubNames
        else
          pubNames;
        implements' = if unit ? "implements" then
          implements // { "${name}" = unit.implements; }
        else
          implements;
        exes' = if unit.type == "exe" then
          extendAcc pkg "${src}/${unit.name}.exe" {
            package = pkg;
            inherit name;
          } exes
        else
          exes;
        pkg2RawExtraDeps' = if unit.type != "lib" then {
          "${pkg}" = (pkg2RawExtraDeps."${pkg}" or [ ]) ++ unit.deps;
        } else
          pkg2RawExtraDeps;
      in acc // {
        packages = packages';
        lib2RawDeps = lib2RawDeps';
        lib2Pkg = lib2Pkg';
        implements = implements';
        pubNames = pubNames';
        exes = exes';
        src2Pkgs =
          pkgs.lib.recursiveUpdate src2Pkgs { "${src}"."${pkg}" = { }; };
        pkg2RawExtraDeps = pkg2RawExtraDeps';
      };
    foldF = acc0: el:
      handleFileDepMaps el
      (builtins.foldl' (extendAccLib el.src) acc0 el.units);
    preRes = builtins.foldl' foldF {
      packages = { };
      lib2RawDeps = { };
      lib2Pkg = { };
      implements = { };
      pubNames = { };
      exes = { };
      src2Pkgs = { };
      src2FileDeps = { };
      fileOuts2Src = { };
      pkg2RawExtraDeps = { };
    } duneDescLoaded;
  in preRes // {
    src2Pkgs = builtins.mapAttrs (_: builtins.attrNames) preRes.src2Pkgs;
  };

  promote = assumeLibDepsComplete: selfPkg: selfLib: accDeps: pkg: libs:
    # We don't want to try to promote package which we're part of
    if selfPkg == pkg then
      [ ]
    else
      let
        pkgDef = info.packages."${pkg}";
        libs_ = builtins.attrNames libs;
        rem = builtins.attrNames (builtins.removeAttrs pkgDef.lib libs_);
        trivialCase = rem == [ ] && pkgDef.test == [ ] && pkgDef.exe == [ ];
        # Check that including an additional dependency creates
        # no cycle back to callee
        kicksNoCycle = lib:
          # Recursive loop is over, we just check whether lib depends on callee
          !(accDeps ? "${lib}".libs."${selfPkg}"."${selfLib}" || accDeps
            ? "${lib}".pkgs."${selfPkg}");
      in if trivialCase
      || (assumeLibDepsComplete && pkgs.lib.all kicksNoCycle rem) then
        [ pkg ]
      else
        [ ];

  singletonLibDep = lib:
    let pkg = info.lib2Pkg."${lib}";
    in { "${pkg}"."${lib}" = { }; };

  executePromote = { pkgs, libs, ... }@deps:
    promoted:
    deps // {
      pkgs = pkgs // args.pkgs.lib.genAttrs promoted (_: { });
      libs = builtins.removeAttrs libs promoted;
    };

  attrFold = f: acc: attrs:
    builtins.foldl' (acc: { fst, snd }: f acc fst snd) acc
    (pkgs.lib.zipLists (builtins.attrNames attrs) (builtins.attrValues attrs));

  attrAll = f: attrFold (acc: key: value: acc && f key value) true;

  # # Executable files that are used as part of compilation process
  # # of a single package (thus forming a dependency)
  # # : { exe path -> package }
  # exeDeps = attrFold (acc0: src:
  #   builtins.foldl' (acc: dep:
  #     if info.exes ? "${dep}" then
  #       let
  #         dependentPkgs = info.src2Pkgs."${src}";
  #         exe = info.exes."${dep}";
  #         depDir = builtins.dirOf dep;
  #       in if depDir
  #       == src # this is a local dependency (TODO is . handled well?)
  #       then
  #         acc
  #       else if exe ? "public_name" && exe ? "package" then
  #         if dependentPkgs == [ ] || dependentPkgs == [ exe.package ] then
  #         # this exe is part of package of the source
  #           acc
  #         else
  #           throw
  #           "Problem with ${dep}: use of public executables in rules is not fully implemented"
  #       else if builtins.length dependentPkgs == 1 then
  #         if acc ? "${dep}" then
  #           throw "Can't internalize ${dep} twice"
  #         else
  #           acc // { "${dep}" = builtins.head dependentPkgs; }
  #       else
  #         throw
  #         "Dune file ${src}/dune defines more than one package and contains a rule requiring a call to non-public executable ${dep}"
  #     else
  #       acc) acc0) { } info.src2FileDeps;

  # TODO rewrite function to consider non-lib dependencies (exes)
  # If dune file defining a unit depends on exe => all units depend on this exe
  # (as internalized unit or otherwise)

  # There will be exeDeps (additional field) for this purpose.
  # When excersizing promotion, check *all* units (including test, exe)

  # Dep entry:
  # { libs : <pkg> -> <name> -> {}
  # , pkgs: <pkg> -> {}
  # , exes : <pkg> -> <name> -> {}
  # , files: <file's dune root> -> {}
  # }
  #
  # Deps:
  # { units: { <pkg> -> <lib|exe|test> -> <name> -> <dep entry> }
  # , files: { <file's dune root> -> { exes: ..., files: ...  } }
  # }

  allDepKeys = directDeps:
    let
      impl = deps: type:
        builtins.concatLists (pkgs.lib.mapAttrsToList (package: entries:
          builtins.map (name: { inherit name package type; })
          (builtins.attrNames entries)) deps);
    in builtins.map (src: {
      type = "file";
      inherit src;
    }) (builtins.attrNames (directDeps.files or { }))
    ++ impl (directDeps.exes or { }) "exe"
    ++ impl (directDeps.libs or { }) "lib";

  allUnitKeys = allUnits:
    builtins.concatLists (pkgs.lib.mapAttrsToList (package: units:
      builtins.map (name: {
        type = "exe";
        inherit name package;
      }) (builtins.attrNames units.exe) ++ builtins.map (name: {
        type = "lib";
        inherit name package;
      }) (builtins.attrNames units.lib)) allUnits);

  directFileDeps = dfArgs: src:
    let
      handleDirectDep = { exes, files }@acc:
        dep:
        if info.exes ? "${dep}" then
          let exe = info.exes."${dep}";
          in if dfArgs ? forExe && dfArgs.forExe == exe.name then
            acc
          else
            pkgs.lib.recursiveUpdate acc {
              exes."${exe.package}"."${exe.name}" = { };
            }
        else if info.fileOuts2Src ? "${dep}" then
          let depSrc = info.fileOuts2Src."${dep}";
          in if depSrc == src then
            acc
          else {
            inherit exes;
            files = files // { "${depSrc}" = { }; };
          }
        else
          acc;
    in builtins.foldl' handleDirectDep {
      exes = { };
      files = { };
    } info.src2FileDeps."${src}";

  depByKey = { files, units }:
    { type, ... }@key:
    if type == "file" then
      files."${key.src}"
    else
      units."${key.package}"."${key.type}"."${key.name}";
  setAttrByPath' = val: attrs: path:
    if path == [ ] then
      val
    else
      let
        hd = builtins.head path;
        tl = builtins.tail path;
      in attrs // { "${hd}" = setAttrByPath' val (attrs."${hd}" or { }) tl; };
  computeDepsImpl = acc0: path: directDeps:
    let
      recLoopMsg = "Recursive loop in ${builtins.concatStringsSep "." path}";
      acc1 = setAttrByPath' (throw recLoopMsg) acc0 path;
      directKeys = allDepKeys directDeps;
      acc2 = builtins.foldl' computeDepsNew acc1 directKeys;
      exes = builtins.foldl' (acc': key:
        let subdeps = depByKey acc2 key;
        in pkgs.lib.recursiveUpdate (subdeps.exes or { }) acc') directDeps.exes
        directKeys;
      libsAndPkgs = builtins.foldl' (acc': key:
        if key.type == "lib" then
          let
            subdeps = depByKey acc2 key;
            update = {
              libs = subdeps.libs or { };
              pkgs = subdeps.pkgs or { };
            };
          in pkgs.lib.recursiveUpdate update acc'
        else
          acc') {
            libs = directDeps.libs or { };
            pkgs = directDeps.pkgs or { };
          } directKeys;
      depMap = libsAndPkgs // {
        inherit exes;
        inherit (directDeps) files;
      };
      promote_ = pkg: libs:
        let
          pkgDef = info.packages."${pkg}";
          libs_ = builtins.attrNames libs;
          rem = builtins.removeAttrs pkgDef.lib libs_;
          trivialCase = rem == { } && pkgDef.test == { } && pkgDef.exe == { };
        in if trivialCase then [ pkg ] else [ ];
      promoted =
        builtins.concatLists (pkgs.lib.mapAttrsToList promote_ depMap.libs);
      depMap' = executePromote depMap promoted;
    in setAttrByPath' depMap' acc2 path;

  directLibDeps = { deps, ... }@unit:
    let
      deps0 = deps ++ (if unit ? implements then [ unit.implements ] else [ ]);
      deps1 = builtins.map
        (d: let d' = info.pubNames."${d}" or ""; in if d' == "" then d else d')
        deps0;
      mkDep = name: {
        inherit name;
        type = "lib";
        package = info.lib2Pkg."${name}";
      };
      libs = builtins.foldl' (acc: name:
        if info.lib2Pkg ? "${name}" then
          pkgs.lib.recursiveUpdate acc {
            "${info.lib2Pkg."${name}"}"."${name}" = { };
          }
        else
          acc) { } deps1;
    in { inherit libs; };

  computeDepsNew = { files, units }@acc:
    { type, ... }@self:
    if type == "file" then
      if files ? "${self.src}" then
        acc
      else
        computeDepsImpl acc [ "files" self.src ] (directFileDeps { } self.src)
    else if units ? "${self.package}"."${self.type}"."${self.name}" then
      acc
    else
      let
        unit = info.packages."${self.package}"."${self.type}"."${self.name}";
        dfArgs = if self.type == "exe" then { forExe = unit.name; } else { };
        directDeps = directFileDeps dfArgs unit.src // directLibDeps unit;
      in computeDepsImpl acc [ "units" self.package self.type self.name ]
      directDeps;

  pruneDepMap = let
    pruneListDeps = acc: field:
      if acc ? "${field}" then
        acc // { "${field}" = builtins.attrNames acc."${field}"; }
      else
        acc;
    pruneMultiDeps = acc: field:
      if acc ? "${field}" then
        acc // {
          "${field}" = builtins.mapAttrs (_: builtins.attrNames) acc."${field}";
        }
      else
        acc;
  in with pkgs.lib;
  (flip pkgs.lib.pipe [
    (filterAttrs (_: val: val != { }))
    (flip (builtins.foldl' pruneListDeps) [ "files" "pkgs" ])
    (flip (builtins.foldl' pruneMultiDeps) [ "exes" "libs" ])
  ]);

  allDepsToJSON = { files, units }:
    builtins.toJSON {
      files = builtins.mapAttrs (_: pruneDepMap) files;
      units = builtins.mapAttrs (_: # iterating packages
        builtins.mapAttrs (_: # iterating types
          builtins.mapAttrs (_: # iterating names
            pruneDepMap))) units;
    };

  computeDeps = acc: lib:
    if acc ? "${lib}" then
      acc
    else
      let
        acc' = acc // { "${lib}" = throw "recursive loop for ${lib}"; };
        pkg = info.lib2Pkg."${lib}";
        deps0 = info.lib2RawDeps."${lib}" ++ (if info.implements ? "${lib}" then
          [ info.implements."${lib}" ]
        else
          [ ]);
        deps1 = builtins.map (d:
          let d' = info.pubNames."${d}" or "";
          in if d' == "" then d else d') deps0;
        deps = builtins.filter (d: info.lib2Pkg ? "${d}") deps1;
        acc'' = builtins.foldl' computeDeps acc' deps;
        depsOfDeps = builtins.foldl' pkgs.lib.recursiveUpdate {
          pkgs = { };
          libs = { };
        } (pkgs.lib.attrVals deps acc'');
        libs' = builtins.foldl'
          (ld: l: pkgs.lib.recursiveUpdate ld (singletonLibDep l))
          depsOfDeps.libs deps;
        promoted = builtins.concatLists
          (pkgs.lib.mapAttrsToList (promote false pkg lib acc'') libs');
      in acc'' // {
        "${lib}" = executePromote {
          inherit (depsOfDeps) pkgs;
          libs = libs';
        } promoted;
      };

  allDepsNotFullyPromoted =
    builtins.foldl' computeDeps { } (builtins.attrNames info.lib2Pkg);

  allDepsNotFullyPromotedNew = builtins.foldl' computeDepsNew {
    files = { };
    units = { };
  } (allUnitKeys info.packages);

  # Trying to make ${depPkg} a package dependency instead of
  # having individual libs ${depLibs} as dependencies
  promoteNew = allNotPromoted: pkg: type: name: depPkg: depLibs:
    if pkg == depPkg then
      [ ] # Don't promote dependencies from own package
    else
      let
        # We want to test that $pkg.$type.$name isn't a dependency of:
        #  * any of ${depPkg}'s libraries
        #  * any of executable depedendencies of package's libraries
        depPkgDef = info.packages."${depPkg}";
        depLibNames = builtins.attrNames depLibs;
        depLibs' =
          builtins.attrNames (builtins.removeAttrs depPkgDef.lib depLibNames);
        depTests = builtins.attrNames depPkgDef.test;
        depExes = builtins.attrNames depPkgDef.exe;
        collectExes = type: acc: name:
          pkgs.lib.recursiveUpdate acc
          (allNotPromoted.units."${depPkg}"."${type}"."${name}".exes or { });
        collectStep = type: names: acc:
          builtins.foldl' (collectExes type) acc names;
        depTransExes = pkgs.lib.pipe { "${depPkg}" = depPkgDef.exe; } [
          (collectStep "lib" depLibs')
          (collectStep "test" depTests)
          (collectStep "exe" depExes)
        ];
        kicksNoCycle = type': pkg': name':
          !(allNotPromoted.units
            ? "${pkg'}"."${type'}"."${name'}".libs."${pkg}"."${name}"
            || allNotPromoted.units
            ? "${pkg'}"."${type'}"."${name'}".pkgs."${pkg}");
        kicksNoCycleMulti = type': pkg': names:
          pkgs.lib.all (kicksNoCycle type' pkg') (builtins.attrNames names);
        decisionToPromote = if type == "exe" then
          !(depTransExes ? "${pkg}"."${name}")
        else if type == "lib" then
          builtins.foldl' (a: b: a && b) true [
            # Check that $depPkg package's libraries do not have $pkg.$name as a dependency
            (pkgs.lib.all (kicksNoCycle "lib" depPkg) depLibs')
            # Check that $depPkg package's tests do not have $pkg.$name as a dependency
            (pkgs.lib.all (kicksNoCycle "test" depPkg) depTests)
            # Check that $depPkg package's executables (or transitive executable dependencies)
            # do not have $pkg.$name as a dependency
            (attrAll (kicksNoCycleMulti "exe") depTransExes)
          ]
        else # type is test, so no dependency can exist
          true;
      in if decisionToPromote then [ depPkg ] else [ ];

  allDepsNew = {
    inherit (allDepsNotFullyPromotedNew) files;
    units = pkgs.lib.mapAttrs (pkg:
      pkgs.lib.mapAttrs (type:
        pkgs.lib.mapAttrs (name: depMap:
          let
            promoted = builtins.concatLists (pkgs.lib.mapAttrsToList
              (promoteNew allDepsNotFullyPromotedNew pkg type name)
              depMap.libs);
          in executePromote depMap promoted))) allDepsNotFullyPromotedNew.units;
  };

  separatedLibsNew = attrFold (acc0: pkg: units0:
    attrFold (acc1: type: units1:
      attrFold (acc2: name:
        { libs, ... }:
        let
          libs' = builtins.removeAttrs libs [ pkg ];
          mkVal = builtins.mapAttrs (_: builtins.attrNames);
        in if libs' != { } then
          setAttrByPath' (mkVal libs') acc2 [ pkg type name ]
        else
          acc2) acc1 units1) acc0 units0) { } allDepsNew.units;

  # pkgExtraDeps = builtins.mapAttrs (pkg: rawLibs:
  # let
  #   pkgDef = info.packages."${pkg}";
  #   pkgSrcs = builtins.attrValues pkgDef.lib ++ builtins.attrValues pkgDef.exe ++ builtins.attrValues pkgDef.test;
  #   exePkgs = builtins.concatMap (src:
  #     builtins.map ({package, ...}: package) (exeDeps."${src}".ext or [])
  #   ) pkgSrcs;
  # in
  #   ) info.pkg2RawExtraDeps;

  # Mapping: lib -> {pkgs: {package -> {}}, libs: {package -> {public_name|name -> {}}}
  # contains full packages and individual libraries on which lib depends (transitive)
  allDeps = pkgs.lib.mapAttrs (lib:
    { libs, pkgs }@deps:
    let
      pkg = info.lib2Pkg."${lib}";
      promoted = builtins.concatLists
        (pkgs.lib.mapAttrsToList (promote true pkg lib allDepsNotFullyPromoted)
          deps.libs);
    in executePromote deps promoted) allDepsNotFullyPromoted;

  # "Internalize" exes to packages (or depend on public exes)

  # TODO Modify code above to include dependencies of executables on which packages depend
  # I.e. we'll just include code of executables into sources (for building the libs/packages),
  # but dependencies need to be managed separately
  # Or make executable to be a separate unit?

  # Out file deps: build corresponding dune file with just out files and copy entire
  # _build/default/* to root of the build (no transitive copying, 

  # Libraries that are used outside of their packages directly (not depending on a package as a whole)
  # Consider moving them out to separate packages?
  # Otherwise lot of edge cases
  separatedLibs =
    builtins.mapAttrs (_: builtins.mapAttrs (_: builtins.attrNames))
    (pkgs.lib.filterAttrs (_: v: v != { }) (builtins.mapAttrs (lib:
      { libs, ... }:
      (builtins.removeAttrs libs [ info.lib2Pkg."${lib}" ])) allDeps));

  # For file deps and executables, let's build them separately and then copy outs and their deps,
  # this limits the scope of failure
  # Then we'll have no _build copying

  publicLibLocs = collectLibLocs "public_name" duneDescLoaded;

  libLocs = collectLibLocs "name" duneDescLoaded // publicLibLocs;

  mkPkgCfg = desc:
    let
      # Optimization, should work even without (but slower and with far more unnecessary rebuilds)
      src = if desc.src == "." then
        with pkgs.lib.fileset;
        (toSource {
          root = ./..;
          fileset = union ../graphql_schema.json ../dune;
        })
      else if desc.src == "src" then
        with pkgs.lib.fileset;
        (toSource {
          root = ../src;
          fileset = union ../src/dune-project ../src/dune;
        })
      else if desc.src == "src/lib/snarky" then
        with pkgs.lib.fileset;
        (toSource {
          root = ../src/lib/snarky;
          fileset = union ../src/lib/snarky/dune-project ../src/lib/snarky/dune;
        })
      else
        ../. + "/${desc.src}";
      subdirs = if builtins.elem desc.src [ "." "src" "src/lib/snarky" ] then
        [ ]
      else
        desc.subdirs;

      internalLibs = builtins.concatMap (unit:
        if unit.type != "lib" then
          [ ]
        else if unit ? "public_name" then [
          unit.public_name
          unit.name
        ] else
          [ unit.name ]) desc.units;
      deps = builtins.concatMap ({ deps, ... }: deps) desc.units;
      deps' = builtins.filter (d: !builtins.elem d internalLibs) deps;
      defImplLibs = builtins.concatMap (unit:
        if unit ? "default_implementation" then
          [ unit.default_implementation ]
        else
          [ ]) desc.units;
      implement = builtins.concatMap
        (unit: if unit ? "implements" then [ unit.implements ] else [ ])
        desc.units;
      def_impls = builtins.attrValues (pkgs.lib.getAttrs defImplLibs libLocs);
      out_file_deps = builtins.concatMap
        (fd: if duneOutFiles ? "${fd}" then [ duneOutFiles."${fd}" ] else [ ])
        desc.file_deps ++ (if desc.src == "src/lib/signature_kind" then
          [ "src" ]
        else if desc.src == "src/lib/logger" then [
          "src/lib/bounded_types"
          "src/lib/mina_compile_config"
          "src/lib/itn_logger"
        ] else
          [ ]);
      lib_deps = builtins.attrValues (pkgs.lib.getAttrs
        (builtins.filter (e: libLocs ? "${e}") (deps' ++ implement)) libLocs);
    in {
      deps = pkgs.lib.unique (lib_deps ++ out_file_deps ++ def_impls);
      inherit (desc) file_deps;
      inherit subdirs out_file_deps src def_impls;
      targets = (if desc.units == [ ] then [ ] else [ desc.src ])
        ++ desc.file_outs;
    };

  pkgCfgMap = builtins.listToAttrs
    (builtins.map (desc: pkgs.lib.nameValuePair desc.src (mkPkgCfg desc))
      duneDescLoaded);

  # TODO Rewrite recursive dep calculation: compute map for every dependency
  recursiveDeps = let
    deps = loc: pkgCfgMap."${loc}".deps;
    impl = acc: loc:
      if acc ? "${loc}" then
        acc
      else
        builtins.foldl' impl (acc // { "${loc}" = ""; }) (deps loc);
  in initLoc: builtins.foldl' impl { } (deps initLoc);

  base-libs =
    let deps = pkgs.lib.getAttrs (builtins.attrNames implicit-deps) scope;
    in pkgs.stdenv.mkDerivation {
      name = "mina-base-libs";
      phases = [ "installPhase" ];
      buildInputs = builtins.attrValues deps;
      installPhase = ''
        mkdir -p $out/lib/ocaml/${scope.ocaml.version}/site-lib/stublibs $out/nix-support $out/bin
        {
          echo -n 'export OCAMLPATH=$'
          echo -n '{OCAMLPATH-}$'
          echo '{OCAMLPATH:+:}'"$out/lib/ocaml/${scope.ocaml.version}/site-lib"
          echo -n 'export CAML_LD_LIBRARY_PATH=$'
          echo -n '{CAML_LD_LIBRARY_PATH-}$'
          echo '{CAML_LD_LIBRARY_PATH:+:}'"$out/lib/ocaml/${scope.ocaml.version}/site-lib/stublibs"
        } > $out/nix-support/setup-hook
        for input in $buildInputs; do
          [ ! -d "$input/lib/ocaml/${scope.ocaml.version}/site-lib" ] || {
            find "$input/lib/ocaml/${scope.ocaml.version}/site-lib" -maxdepth 1 -mindepth 1 -not -name stublibs | while read d; do
              cp -R "$d" "$out/lib/ocaml/${scope.ocaml.version}/site-lib/"
            done
          }
          [ ! -d "$input/lib/ocaml/${scope.ocaml.version}/site-lib/stublibs" ] || cp -R "$input/lib/ocaml/${scope.ocaml.version}/site-lib/stublibs"/* "$out/lib/ocaml/${scope.ocaml.version}/site-lib/stublibs/"
          [ ! -d "$input/bin" ] || cp -R $input/bin/* $out/bin
        done
      '';
    };

  buildDunePkg = let
    copyDirs' = prefix: path: drv:
      ''
        "${builtins.dirOf "${prefix}/${path}"}" "${
          builtins.baseNameOf "${prefix}/${path}"
        }" "${drv}"'';
    copyFileDep' = f:
      if builtins.pathExists ../${f} then
        [ (copyDirs' "." f ../${f}) ]
      else
        [ ];
    copyBuildDirs' = copyDirs' "_build/default";
    copySrcDirs' = path: cfg: copyDirs' "." path cfg.src;
    copyAllBuildDirs' = def_impls: devDeps:
      pkgs.lib.mapAttrsToList copyBuildDirs'
      (builtins.removeAttrs devDeps def_impls);
    copyAllSrcDirs' = cfgSubMap: pkgs.lib.mapAttrsToList copySrcDirs' cfgSubMap;
    subdirsToDelete' = topPath: deps: path: cfg:
      builtins.concatMap (f:
        let r = "${path}/${f}";
        in if pkgs.lib.any (d: d == r || pkgs.lib.hasPrefix "${r}/" d)
        ([ topPath ] ++ deps) then
          [ ]
        else
          [ r ]) cfg.subdirs;
  in path:
  { file_deps, targets, src, def_impls, ... }@cfg:
  devDeps:
  let
    quotedPath = quote path;
    file_deps' = pkgs.lib.unique (file_deps ++ builtins.concatLists
      (pkgs.lib.mapAttrsToList (p: _: pkgCfgMap."${p}".file_deps) devDeps));
    cfgSubMap = builtins.intersectAttrs devDeps pkgCfgMap;
    depNames = builtins.attrNames cfgSubMap;
    allDirs' = copyAllBuildDirs' def_impls devDeps ++ copyAllSrcDirs' cfgSubMap
      ++ [ (copySrcDirs' path cfg) ]
      ++ builtins.concatMap copyFileDep' file_deps';
    allDirs = builtins.sort (s: t: s < t) allDirs';
    subdirsToDelete = pkgs.lib.unique (subdirsToDelete' path depNames path cfg
      ++ builtins.concatLists
      (pkgs.lib.mapAttrsToList (subdirsToDelete' path depNames) cfgSubMap));
    # If path being copied contains dune-inhabitated subdirs,
    # it isn't enough to just link dependencies from other derivations
    # because in some cases we may want to create a subdir in the directory corresponding
    # to that dependency.
    #
    # Hence what we do is the following: we create a directory for the path and recursively 
    # link all regular files with symlinks, while recreating the dependency tree
    initFS = ''
      set -euo pipefail
      chmod +w .
      inputs=( ${builtins.concatStringsSep " " allDirs} )
      for i in {0..${toString (builtins.length allDirs - 1)}}; do
        j=$((i*3))
        dir="''${inputs[$j]}"
        file="$dir/''${inputs[$((j+1))]}"
        drv="''${inputs[$((j+2))]}"
        mkdir -p "$dir"
        cp -RLTu "$drv" "$file"
        [ ! -d "$file" ] || chmod -R +w "$file"
      done
    '' + (if subdirsToDelete == [ ] then
      ""
    else ''
      toDelete=( ${
        pkgs.lib.concatMapStringsSep " " (f: ''"${f}"'') subdirsToDelete
      } )
      rm -Rf "''${toDelete[@]}"
      [ ! -d _build/default ] || ( cd _build/default && rm -Rf "''${toDelete[@]}" )
    '');
    initFSDrv = pkgs.writeShellScriptBin "init-fs-${quotedPath}" initFS;
    # TODO check logs. Seems like we're not copying all of the _build dirs correctly (in case of sources it might simply not be a factor to worry about)
    # (^ unlikely though, sorting should alleviate the concern most of the time)
  in [
    {
      name = "init-fs-${quotedPath}";
      value = initFSDrv;
    }
    {
      name = quotedPath;
      value = pkgs.stdenv.mkDerivation {
        pname = quotedPath;
        version = "dev";
        GO_CAPNP_STD = "${pkgs.go-capnproto2.src}/std";
        MARLIN_PLONK_STUBS = "${pkgs.kimchi_bindings_stubs}";
        PLONK_WASM_NODEJS = "${pkgs.plonk_wasm}/nodejs";
        PLONK_WASM_WEB = "${pkgs.plonk_wasm}/web";
        DUNE_PROFILE = "dev";
        MINA_COMMIT_SHA1 = inputs.self.sourceInfo.rev or "<dirty>";
        buildInputs = [ base-libs ] ++ external-libs;
        nativeBuildInputs = [ base-libs initFSDrv pkgs.capnproto ];
        dontUnpack = true;
        patchPhase = "init-fs-${quotedPath} ";
        buildPhase = ''
          dune build ${builtins.concatStringsSep " " targets}
        '';
        installPhase = ''
          find _build/default \( -type l -o \( -type d -empty \) \) -delete
          cp -R _build/default/${path} $out
        '';
      };
    }
  ];

  minaPkgs = self:
    builtins.listToAttrs (builtins.concatLists (pkgs.lib.attrsets.mapAttrsToList
      (path: cfg:
        let
          deps = builtins.attrNames (recursiveDeps path);
          depMap = builtins.listToAttrs (builtins.map (d: {
            name = d;
            value = self."${quote d}";
          }) (builtins.filter (p: path != p) deps));
        in buildDunePkg path cfg depMap) pkgCfgMap));

  overlay = self: super:
    let
      ocaml-libs = builtins.attrValues (getAttrs installedPackageNames self);

      # Make a script wrapper around a binary, setting all the necessary environment variables and adding necessary tools to PATH.
      # Also passes the version information to the executable.
      wrapMina = let
        commit_sha1 = inputs.self.sourceInfo.rev or "<dirty>";
      in package:
      { deps ? [ pkgs.gnutar pkgs.gzip ] }:
      pkgs.runCommand "${package.name}-release" {
        buildInputs = [ pkgs.makeBinaryWrapper pkgs.xorg.lndir ];
        outputs = package.outputs;
      } (map (output: ''
        mkdir -p ${placeholder output}
        lndir -silent ${package.${output}} ${placeholder output}
        for i in $(find -L "${placeholder output}/bin" -type f); do
          wrapProgram "$i" \
            --prefix PATH : ${makeBinPath deps} \
            --set MINA_LIBP2P_HELPER_PATH ${pkgs.libp2p_helper}/bin/mina-libp2p_helper \
            --set MINA_COMMIT_SHA1 ${escapeShellArg commit_sha1}
        done
      '') package.outputs);

      # Derivation which has all Mina's dependencies in it, and creates an empty output if the command succeds.
      # Useful for unit tests.
      runMinaCheck = { name ? "check", extraInputs ? [ ], extraArgs ? { }, }:
        check:
        self.mina-dev.overrideAttrs (oa:
          {
            pname = "mina-${name}";
            buildInputs = oa.buildInputs ++ extraInputs;
            buildPhase = check;
            outputs = [ "out" ];
            installPhase = "touch $out";
          } // extraArgs);
    in {
      # Some "core" Mina executables, without the version info.
      mina-dev = pkgs.stdenv.mkDerivation ({
        pname = "mina";
        version = "dev";
        # Only get the ocaml stuff, to reduce the amount of unnecessary rebuilds
        src = with inputs.nix-filter.lib;
          filter {
            root = ./..;
            include = [
              (inDirectory "src")
              "dune"
              "dune-project"
              "./graphql_schema.json"
              "opam.export"
            ];
          };

        withFakeOpam = false;

        # TODO, get this from somewhere
        MARLIN_REPO_SHA = "<unknown>";
        MINA_COMMIT_SHA1 = "<unknown>";
        MINA_COMMIT_DATE = "<unknown>";
        MINA_BRANCH = "<unknown>";

        DUNE_PROFILE = "dev";

        NIX_LDFLAGS =
          optionalString (pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64)
          "-F${pkgs.darwin.apple_sdk.frameworks.CoreFoundation}/Library/Frameworks -framework CoreFoundation";

        buildInputs = ocaml-libs ++ external-libs;

        nativeBuildInputs = [
          self.dune
          self.ocamlfind
          self.odoc
          self.lld_wrapped
          pkgs.capnproto
          pkgs.removeReferencesTo
          pkgs.fd
        ] ++ ocaml-libs;

        # todo: slimmed rocksdb
        MINA_ROCKSDB = "${pkgs.rocksdb-mina}/lib/librocksdb.a";
        GO_CAPNP_STD = "${pkgs.go-capnproto2.src}/std";

        # this is used to retrieve the path of the built static library
        # and copy it from within a dune rule
        # (see src/lib/crypto/kimchi_bindings/stubs/dune)
        MARLIN_PLONK_STUBS = "${pkgs.kimchi_bindings_stubs}";
        DISABLE_CHECK_OPAM_SWITCH = "true";

        MINA_VERSION_IMPLEMENTATION = "mina_version.runtime";

        PLONK_WASM_NODEJS = "${pkgs.plonk_wasm}/nodejs";
        PLONK_WASM_WEB = "${pkgs.plonk_wasm}/web";

        configurePhase = ''
          export MINA_ROOT="$PWD"
          export -f patchShebangs isScript
          fd . --type executable -x bash -c "patchShebangs {}"
          export -n patchShebangs isScript
          # Get the mina version at runtime, from the wrapper script. Used to prevent rebuilding everything every time commit info changes.
          sed -i "s/mina_version_compiled/mina_version.runtime/g" src/app/cli/src/dune src/app/rosetta/dune src/app/archive/dune
        '';

        buildPhase = ''
          dune build --display=short \
            src/app/logproc/logproc.exe \
            src/app/cli/src/mina.exe \
            src/app/batch_txn_tool/batch_txn_tool.exe \
            src/app/cli/src/mina_testnet_signatures.exe \
            src/app/cli/src/mina_mainnet_signatures.exe \
            src/app/rosetta/rosetta.exe \
            src/app/rosetta/rosetta_testnet_signatures.exe \
            src/app/rosetta/rosetta_mainnet_signatures.exe \
            src/app/generate_keypair/generate_keypair.exe \
            src/app/archive/archive.exe \
            src/app/archive_blocks/archive_blocks.exe \
            src/app/extract_blocks/extract_blocks.exe \
            src/app/missing_blocks_auditor/missing_blocks_auditor.exe \
            src/app/replayer/replayer.exe \
            src/app/swap_bad_balances/swap_bad_balances.exe \
            src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe \
            src/app/berkeley_migration/berkeley_migration.exe \
            src/app/berkeley_migration_verifier/berkeley_migration_verifier.exe
          # TODO figure out purpose of the line below
          # dune exec src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe -- --genesis-dir _build/coda_cache_dir
          # Building documentation fails, because not everything in the source tree compiles. Ignore the errors.
          dune build @doc || true
        '';

        outputs = [
          "out"
          "archive"
          "generate_keypair"
          "mainnet"
          "testnet"
          "genesis"
          "sample"
          "batch_txn_tool"
          "berkeley_migration"
        ];

        installPhase = ''
          mkdir -p $out/bin $archive/bin $sample/share/mina $out/share/doc $generate_keypair/bin $mainnet/bin $testnet/bin $genesis/bin $genesis/var/lib/coda $batch_txn_tool/bin $berkeley_migration/bin
          # TODO uncomment when genesis is generated above
          # mv _build/coda_cache_dir/genesis* $genesis/var/lib/coda
          pushd _build/default
          cp src/app/cli/src/mina.exe $out/bin/mina
          cp src/app/logproc/logproc.exe $out/bin/logproc
          cp src/app/rosetta/rosetta.exe $out/bin/rosetta
          cp src/app/batch_txn_tool/batch_txn_tool.exe $batch_txn_tool/bin/batch_txn_tool
          cp src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe $genesis/bin/runtime_genesis_ledger
          cp src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe $out/bin/runtime_genesis_ledger
          cp src/app/cli/src/mina_mainnet_signatures.exe $mainnet/bin/mina_mainnet_signatures
          cp src/app/rosetta/rosetta_mainnet_signatures.exe $mainnet/bin/rosetta_mainnet_signatures
          cp src/app/cli/src/mina_testnet_signatures.exe $testnet/bin/mina_testnet_signatures
          cp src/app/rosetta/rosetta_testnet_signatures.exe $testnet/bin/rosetta_testnet_signatures
          cp src/app/generate_keypair/generate_keypair.exe $generate_keypair/bin/generate_keypair
          cp src/app/archive/archive.exe $archive/bin/mina-archive
          cp src/app/archive_blocks/archive_blocks.exe $archive/bin/mina-archive-blocks
          cp src/app/missing_blocks_auditor/missing_blocks_auditor.exe $archive/bin/mina-missing-blocks-auditor
          cp src/app/replayer/replayer.exe $archive/bin/mina-replayer
          cp src/app/replayer/replayer.exe $berkeley_migration/bin/mina-migration-replayer
          cp src/app/berkeley_migration/berkeley_migration.exe $berkeley_migration/bin/mina-berkeley-migration
          cp src/app/berkeley_migration_verifier/berkeley_migration_verifier.exe $berkeley_migration/bin/mina-berkeley-migration-verifier
          cp src/app/swap_bad_balances/swap_bad_balances.exe $archive/bin/mina-swap-bad-balances
          cp -R _doc/_html $out/share/doc/html
          # cp src/lib/mina_base/sample_keypairs.json $sample/share/mina
          popd
          remove-references-to -t $(dirname $(dirname $(command -v ocaml))) {$out/bin/*,$mainnet/bin/*,$testnet/bin*,$genesis/bin/*,$generate_keypair/bin/*}
        '';
        shellHook =
          "export MINA_LIBP2P_HELPER_PATH=${pkgs.libp2p_helper}/bin/mina-libp2p_helper";
      } // optionalAttrs pkgs.stdenv.isDarwin {
        OCAMLPARAM = "_,cclib=-lc++";
      });

      # Same as above, but wrapped with version info.
      mina = wrapMina self.mina-dev { };

      # Mina with additional instrumentation info.
      with-instrumentation-dev = self.mina-dev.overrideAttrs (oa: {
        pname = "with-instrumentation";
        outputs = [ "out" ];

        buildPhase = ''
          dune build  --display=short --profile=testnet_postake_medium_curves --instrument-with bisect_ppx src/app/cli/src/mina.exe
        '';
        installPhase = ''
          mkdir -p $out/bin
          mv _build/default/src/app/cli/src/mina.exe $out/bin/mina
        '';
      });

      with-instrumentation = wrapMina self.with-instrumentation-dev { };

      mainnet-pkg = self.mina-dev.overrideAttrs (s: {
        version = "mainnet";
        DUNE_PROFILE = "mainnet";
        # For compatibility with Docker build
        MINA_ROCKSDB = "${pkgs.rocksdb-mina}/lib/librocksdb.a";
      });

      mainnet = wrapMina self.mainnet-pkg { };

      devnet-pkg = self.mina-dev.overrideAttrs (s: {
        version = "devnet";
        DUNE_PROFILE = "devnet";
        # For compatibility with Docker build
        MINA_ROCKSDB = "${pkgs.rocksdb-mina}/lib/librocksdb.a";
      });

      devnet = wrapMina self.devnet-pkg { };

      # Unit tests
      mina_tests = runMinaCheck {
        name = "tests";
        extraArgs = {
          MINA_LIBP2P_HELPER_PATH = "${pkgs.libp2p_helper}/bin/mina-libp2p_helper";
          MINA_LIBP2P_PASS = "naughty blue worm";
          MINA_PRIVKEY_PASS = "naughty blue worm";
          TZDIR = "${pkgs.tzdata}/share/zoneinfo";
        };
        extraInputs = [ pkgs.ephemeralpg ];
      } ''
        dune build graphql_schema.json --display=short
        export MINA_TEST_POSTGRES="$(pg_tmp -w 1200)"
        pushd src/app/archive
        psql "$MINA_TEST_POSTGRES" < create_schema.sql
        popd
        # TODO: investigate failing tests, ideally we should run all tests in src/
        dune runtest src/app/archive src/lib/command_line_tests --display=short
      '';

      # Check if the code is formatted properly
      mina-ocaml-format = runMinaCheck { name = "ocaml-format"; } ''
        dune exec --profile=dev src/app/reformat/reformat.exe -- -path . -check
      '';

      # Integration test executive
      test_executive-dev = self.mina-dev.overrideAttrs (oa: {
        pname = "mina-test_executive";
        outputs = [ "out" ];

        buildPhase = ''
          dune build --profile=integration_tests src/app/test_executive/test_executive.exe src/app/logproc/logproc.exe -j$NIX_BUILD_CORES
        '';
        installPhase = ''
          mkdir -p $out/bin
          mv _build/default/src/app/test_executive/test_executive.exe $out/bin/test_executive
          mv _build/default/src/app/logproc/logproc.exe $out/bin/logproc
        '';
      });

      test_executive = wrapMina self.test_executive-dev { };

      experiment = minaPkgs self.experiment // {
        inherit dune-description;
        file-deps =
          pkgs.writeText "file-deps.json" (builtins.toJSON info.src2FileDeps);
        exes = pkgs.writeText "exes.json" (builtins.toJSON info.exes);
        packages =
          pkgs.writeText "packages.json" (builtins.toJSON info.packages);
        separated-libs = pkgs.writeText "separated-libs.json"
          (builtins.toJSON separatedLibsNew);
        all-deps-new =
          pkgs.writeText "all-deps.json" (allDepsToJSON allDepsNew);
        all-deps = pkgs.writeText "all-deps.json" (builtins.toJSON
          (pkgs.lib.mapAttrs (_:
            { pkgs, libs }: {
              pkgs = builtins.attrNames pkgs;
              libs = args.pkgs.lib.mapAttrs (_: builtins.attrNames) libs;
            }) allDeps));
      };
    };
in scope.overrideScope' overlay
