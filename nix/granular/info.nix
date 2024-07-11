# Computes information object for the dune project
#
# Has type: {pkgs, ..} -> dune description -> info
# 
# For info being an object containing the following keys (each key containing an object
# a.k.a. mapping):
# 
# - mapping packages: pkg -> { lib: {public_name|name -> loc}, exe: {..}, test: {..} }
# - mapping lib2Pkg: lib -> pkg (from library name to package)
# - mapping pubNames: lib's name -> lib's public_name (if such exists)
# - mapping exes: .exe path -> { package, name }
# - mapping srcInfo: src -> entry from dune description w/o units
# - mapping fileOuts2Src: file path -> src (mapping from output of some dune's rule
#                                           to directory that contains dune file)
# - mapping pseudoPackages: pkg -> src (for packages which names were artifically generated
#                                     to hold units that have no package defined)
{ pkgs, util, ... }@args:
let
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
    { fileOuts2Src, srcInfo, ... }@acc:
    let
      fileOuts2Src' = builtins.foldl' (acc': out:
        extendAccImpl "Output ${out} appears twice in dune files" out el.src
        acc') fileOuts2Src (builtins.attrNames el.file_outs);
      srcInfo' =
        extendAccImpl "Source ${el.src} appears twice in dune description"
        el.src (builtins.removeAttrs el [ "units" "src" ]) srcInfo;
    in acc // {
      fileOuts2Src = fileOuts2Src';
      srcInfo = srcInfo';
    };
  extendAccLib = src:
    { packages, lib2Pkg, pubNames, exes, pseudoPackages, ... }@acc:
    unit:
    let
      pkg = if unit ? "package" then
        unit.package
      else if unit ? "public_name" && unit.type == "lib" then
        builtins.head (pkgs.lib.splitString "." unit.public_name)
      else
        "__${util.quote src}__";
      isPseudoPkg = !(unit ? "package")
        && !(unit ? "public_name" && unit.type == "lib");
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
      lib2Pkg' =
        if unit.type == "lib" then extendAcc pkg name pkg lib2Pkg else lib2Pkg;
      pubNames' = if unit.type == "lib" && unit ? "public_name" then
        extendAccDef "" unit.name unit.public_name pubNames
      else
        pubNames;
      exes' = if unit.type == "exe" then
        extendAcc pkg "${src}/${unit.name}.exe" {
          package = pkg;
          inherit name;
        } exes
      else
        exes;
      pseudoPackages' = if isPseudoPkg then
        pseudoPackages // { "${pkg}" = src; }
      else
        pseudoPackages;
    in acc // {
      packages = packages';
      lib2Pkg = lib2Pkg';
      pubNames = pubNames';
      exes = exes';
      pseudoPackages = pseudoPackages';
    };
  foldF = acc0: el:
    handleFileDepMaps el (builtins.foldl' (extendAccLib el.src) acc0 el.units);
in builtins.foldl' foldF {
  packages = { };
  lib2Pkg = { };
  pubNames = { };
  exes = { };
  srcInfo = { };
  fileOuts2Src = { };
  pseudoPackages = { };
}
