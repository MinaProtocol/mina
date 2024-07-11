# A very simple package to manage path filters
# A filter is an incomplete description of a file system organized as an object
# Key `.` of a filter object holds metadata (due to naming it's referred to "dot").
# Dot object contains key "type" that dictates semantics of the filter:
# - include as a whole (both dir and file): 2
# - include files recursively with extension from list: 1
# - include files with extension from list: 0
#
# For types 0 and 1, additional keys are expected:
# - "ext" containing string list of extensions
# - "exclude" containing subdirectories that need to be excluded
#
# Merging algebra is partial, here are some hints:
# - if one of the filters excludes something that is
# included by other, exclusion is simply ignored.
# - if two directories are defined differently in two filters, an error is thrown

{ pkgs, ... }:
let
  # fileFilter type: object
  #
  # If contains ".", this value is an object describing that files
  # in the directory need to be considered
  #
  # If not provided, only children are traversed

  mergeDo = filters:
    if builtins.length filters == 1 then
      builtins.head filters
    else
      let
        dots =
          builtins.concatMap (f: if f ? "." then [ f."." ] else [ ]) filters;
      in if dots == [ ] then
        merge filters
      else
        let someDot = builtins.head dots;
        in if builtins.any (d: someDot != d) dots then
          throw
          "Merging of filters with directories defined at the same level differently is not supported"
        else
        # We overwrite dot so that there is no recursive call
        # to merge on fields of "." (laziness helps)
          merge filters // { "." = someDot; };

  merge = v: pkgs.lib.zipAttrsWith (_: mergeDo) v;

  includeAll = { type = 2; };

  # Creates a filter from filepath
  # Assumes that filepath contains no dots
  create = dot: filepath:
    if filepath == "." then {
      "." = dot;
    } else
      pkgs.lib.setAttrByPath (pkgs.lib.splitString "/" filepath ++ [ "." ]) dot;

  all = create includeAll;

  hasExt = fname: ext: pkgs.lib.hasSuffix ("." + ext) fname;
  withinPath = fpath: exc: pkgs.lib.take (builtins.length exc) fpath == exc;

  checkDot = filetype: isParent: path: dot:
    let
      type = dot.type or 1000;
      filename = pkgs.lib.last path;
    in if type == 0 || type == 1 then
      (type == 1 || isParent) && ((type == 1 && filetype == "directory")
        || builtins.any (hasExt filename) dot.ext)
      && !builtins.any (withinPath path) (dot.exclude or [ ])
    else
      type == 2;

  checkAncestors = filetype: filepath: filter:
    let
      latestDotInfo = builtins.foldl' ({ path, dot, obj, dotPath }:
        el:
        if obj ? "${el}" then
          let
            path' = path ++ [ el ];
            obj' = obj."${el}";
          in if obj' ? "." then {
            path = path';
            obj = obj';
            dot = obj'.".";
            dotPath = path';
          } else {
            path = path';
            obj = obj';
            inherit dot dotPath;
          }
        else {
          inherit path dot dotPath;
          obj = { };
        }) {
          path = [ ];
          dotPath = [ ];
          obj = filter;
          dot = { };
        } filepath;
      rootDot = filter."." or { };
      init = pkgs.lib.init filepath;
    in if init == [ ] then
      checkDot filetype true filepath rootDot
    else if latestDotInfo.dot != { } then
      checkDot filetype (latestDotInfo.dotPath == init)
      (pkgs.lib.drop (builtins.length latestDotInfo.dotPath) filepath)
      latestDotInfo.dot
    else
      checkDot filetype false filepath rootDot;

  toPath = pathParams: filterMap:
    builtins.path (pathParams // {
      filter = ps: t:
        # Strip derivation prefix (if present) and split path string to list of components
        let
          ps' = if pkgs.lib.hasPrefix "${builtins.storeDir}/" ps then
            pkgs.lib.tail (pkgs.lib.splitString "/"
              (pkgs.lib.removePrefix "${builtins.storeDir}/" ps))
          else
            pkgs.lib.splitString "/" ps;
        in pkgs.lib.hasAttrByPath ps' filterMap
        || checkAncestors t ps' filterMap;
    });
in { inherit merge includeAll create toPath all; }
