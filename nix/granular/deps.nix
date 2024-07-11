{ pkgs, util, depsNonpromoted, ... }@args:
let
  # Trying to make ${depPkg} a package dependency instead of
  # having individual libs ${depLibs} as dependencies
  attemptPromote = info: allNotPromoted: pkg: type: name: depPkg: depLibs:
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
            ? "${pkg'}"."${type'}"."${name'}".pkgs."${pkg}");
        multi = cycleCheck: type': pkg': names:
          pkgs.lib.all (cycleCheck type' pkg') (builtins.attrNames names);
        libKicksNoCycle = type': pkg': name':
          !(allNotPromoted.units
            ? "${pkg'}"."${type'}"."${name'}".libs."${pkg}"."${name}"
            || allNotPromoted.units
            ? "${pkg'}"."${type'}"."${name'}".pkgs."${pkg}");
        goodToPromote = cycleCheck:
          builtins.foldl' (a: b: a && b) true [
            # Check that $depPkg package's libraries do not have $pkg.$name as a dependency
            (pkgs.lib.all (cycleCheck "lib" depPkg) depLibs')
            # Check that $depPkg package's tests do not have $pkg.$name as a dependency
            (pkgs.lib.all (cycleCheck "test" depPkg) depTests)
            # Check that $depPkg package's executables (or transitive executable dependencies)
            # do not have $pkg.$name as a dependency
            (util.attrAll (multi cycleCheck "exe") depTransExes)
          ];
        decisionToPromote = if type == "exe" then
          !(depTransExes ? "${pkg}"."${name}") && goodToPromote kicksNoCycle
        else if type == "lib" then
          goodToPromote libKicksNoCycle
        else
          goodToPromote kicksNoCycle;
      in if decisionToPromote then [ depPkg ] else [ ];

  promoteAll = info: allDepsNotFullyPromoted:
    util.attrFold (acc0: pkg:
      util.attrFold (acc1: type:
        util.attrFold (acc2: name: depMap:
          let
            promoted = builtins.concatLists
              (pkgs.lib.mapAttrsToList (attemptPromote info acc2 pkg type name)
                depMap.libs);
            depMap' = depsNonpromoted.executePromote depMap promoted;
          in util.setAttrByPath depMap' acc2 [ "units" pkg type name ]) acc1)
      acc0) allDepsNotFullyPromoted allDepsNotFullyPromoted.units;

  allDeps = info:
    let allDepsNotFullyPromoted = depsNonpromoted.allDepsNotFullyPromoted info;
    in promoteAll info allDepsNotFullyPromoted;

  separatedLibs = allDeps:
    util.attrFold (acc0: pkg: units0:
      util.attrFold (acc1: type: units1:
        util.attrFold (acc2: name:
          { libs, ... }:
          let
            libs' = builtins.removeAttrs libs [ pkg ];
            mkVal = builtins.mapAttrs (_: builtins.attrNames);
          in if libs' != { } then
            util.setAttrByPath (mkVal libs') acc2 [ pkg type name ]
          else
            acc2) acc1 units1) acc0 units0) { } allDeps.units;

  packageDepsImpl = update: allDeps: field: pkg:
    builtins.foldl' (acc0: v0:
      builtins.foldl' (acc: v: update acc v."${field}") acc0
      (builtins.attrValues v0)) { }
    (builtins.attrValues allDeps.units."${pkg}");

  packageDeps = packageDepsImpl (a: b: a // b);
  packageDepsMulti = packageDepsImpl pkgs.lib.recursiveUpdate;
in { inherit packageDeps packageDepsMulti separatedLibs allDeps promoteAll; }
