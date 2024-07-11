# Some definitions to export information about dune project to text form
{ pkgs, deps, ... }@args:
let
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
  pruneDepMap = with pkgs.lib;
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

  packagesDotGraph = let
    sep = "\n  ";
    nonTransitiveDeps = pkg:
      let
        allDeps = deps.packageDeps allDeps "pkgs" pkg;
        transitiveDeps = builtins.foldl'
          (acc: depPkg: acc // deps.packageDeps allDeps "pkgs" depPkg) { }
          (builtins.attrNames allDeps);
      in builtins.attrNames
      (builtins.removeAttrs allDeps (builtins.attrNames transitiveDeps));
    escape = builtins.replaceStrings [ "-" ] [ "_" ];
    genEdges = pkg:
      pkgs.lib.concatMapStringsSep sep (dep: "${escape pkg} -> ${escape dep}")
      (nonTransitiveDeps pkg);
  in "digraph packages {\n  "
  + pkgs.lib.concatMapStringsSep sep genEdges (builtins.attrNames allDeps.units)
  + ''

    }'';

in { inherit allDepsToJSON packagesDotGraph; }
