# Compute dependencies between units (libraries, executables, tests),
# packages and generated files.
#
# When a unit depends on all units from a package, they're
# collapsed to a package dependency (this is called promotion).
#
# Functions in this file do not attempt to promote partial
# dependencies (when a unit depends on only a few dependencies
# from a package), unlike deps.nix.
{ pkgs, util, ... }@args:
let
  executePromote = { pkgs, libs, ... }@deps:
    promoted:
    deps // {
      pkgs = pkgs // args.pkgs.lib.genAttrs promoted (_: { });
      libs = builtins.removeAttrs libs promoted;
    };

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

  directFileDeps = info: dfArgs: src:
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
      empty = {
        exes = { };
        files = { };
      };
      file_deps = info.srcInfo."${src}".file_deps;
      deps = builtins.foldl' handleDirectDep empty file_deps;
      duneDirs = builtins.concatMap (fd:
        if builtins.baseNameOf fd == "dune" then
          [ (builtins.dirOf fd) ]
        else
          [ ]) file_deps;
    in deps // { files = builtins.removeAttrs deps.files duneDirs; };

  depByKey = { files, units }:
    { type, ... }@key:
    if type == "file" then
      files."${key.src}"
    else
      units."${key.package}"."${key.type}"."${key.name}";

  computeDepsImpl = info: acc0: path: directDeps:
    let
      recLoopMsg = "Recursive loop in ${builtins.concatStringsSep "." path}";
      acc1 = util.setAttrByPath (throw recLoopMsg) acc0 path;
      directKeys = allDepKeys directDeps;
      acc2 = builtins.foldl' (computeDeps info) acc1 directKeys;
      exes = builtins.foldl' (acc': key:
        let subdeps = depByKey acc2 key;
        in pkgs.lib.recursiveUpdate (subdeps.exes or { }) acc') directDeps.exes
        directKeys;
      files = builtins.foldl' (acc': key:
        let subdeps = depByKey acc2 key;
        in pkgs.lib.recursiveUpdate (subdeps.files or { }) acc')
        directDeps.files directKeys;
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
      depMap = libsAndPkgs // { inherit exes files; };
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
    in util.setAttrByPath depMap' acc2 path;

  directLibDeps = info:
    let
      toPubName = d:
        let d' = info.pubNames."${d}" or "";
        in if d' == "" then d else d';
      implementsDep = unit:
        if unit ? "implements" then [ unit.implements ] else [ ];
      defImplDeps = unit:
        if unit ? "default_implementation" then
          let
            defImplLib = toPubName unit.default_implementation;
            defImplPkg = info.lib2Pkg."${defImplLib}";
          in builtins.map toPubName
          info.packages."${defImplPkg}".lib."${defImplLib}".deps
        else
          [ ];
      mkDep = name: {
        inherit name;
        type = "lib";
        package = info.lib2Pkg."${name}";
      };
      libs = deps:
        builtins.foldl' (acc: name:
          if info.lib2Pkg ? "${name}" then
            pkgs.lib.recursiveUpdate acc {
              "${info.lib2Pkg."${name}"}"."${name}" = { };
            }
          else
            acc) { } deps;
    in unit: {
      libs = libs (defImplDeps unit ++ implementsDep unit
        ++ builtins.map toPubName unit.deps);
    };

  computeDeps = info:
    { files, units }@acc:
    { type, ... }@self:
    if type == "file" then
      if files ? "${self.src}" then
        acc
      else
        computeDepsImpl info acc [ "files" self.src ]
        (directFileDeps info { } self.src)
    else if units ? "${self.package}"."${self.type}"."${self.name}" then
      acc
    else
      let
        unit = info.packages."${self.package}"."${self.type}"."${self.name}";
        dfArgs = if self.type == "exe" then { forExe = unit.name; } else { };
        directDeps = directFileDeps info dfArgs unit.src
          // directLibDeps info unit;
      in computeDepsImpl info acc [ "units" self.package self.type self.name ]
      directDeps;

  allUnitKeys = allUnits:
    builtins.concatLists (pkgs.lib.mapAttrsToList (package: units0:
      builtins.concatLists (pkgs.lib.mapAttrsToList (type: units:
        builtins.map (name: { inherit type name package; })
        (builtins.attrNames units)) units0)) allUnits);

  allDepsNotFullyPromoted = info:
    builtins.foldl' (computeDeps info) {
      files = { };
      units = { };
    } (allUnitKeys info.packages);
in { inherit allDepsNotFullyPromoted executePromote; }
