{ pkgs, pathFilter, ... }@args:
let
  canonicalizePath = ps:
    let
      p = pkgs.lib.splitString "/" ps;
      p' = builtins.foldl' (acc: el:
        if el == "." then
          acc
        else if acc == [ ] then
          [ el ]
        else if el == ".." && pkgs.lib.last acc != ".." then
          pkgs.lib.init acc
        else
          acc ++ [ el ]) [ ] p;
    in pkgs.lib.concatStringsSep "/" p';

  # Utility function that builds a path with symlinks replaced with
  # contents of their targets.
  # Takes three arguments:
  #  - prefix of derivation name (string)
  #  - original path (path)
  #  - root of the newly created path (path)
  # It returns a derivation without symlinks that contains
  # everything from the original path, rearranged as relative
  # to the root.
  fixupSymlinksInSource = pkgName: src: root:
    let
      depListDrv = pkgs.stdenv.mkDerivation {
        inherit src;
        name = "${pkgName}-symlink-targets";
        phases = [ "unpackPhase" "installPhase" ];
        installPhase = ''
          find -type l -exec bash -c 'echo "$(dirname {})/$(readlink {})"' ';' > $out
          find \( -type f -o -type l \) >> $out
        '';
      };
      fileListTxt = builtins.readFile depListDrv;
      fileList =
        builtins.map canonicalizePath (pkgs.lib.splitString "\n" fileListTxt);
      filters = builtins.map pathFilter.all fileList;
    in pathFilter.filterToPath {
      path = root;
      name = "source-${pkgName}-with-correct-symlinks";
    } (pathFilter.merge filters);

  quote = builtins.replaceStrings [ "." "/" ] [ "__" "-" ];

  # Overriding a test.xyz attribute with this derivation would mute a particular test
  # (useful when test is temporarily non-functioning)
  skippedTest = pkgs.stdenv.mkDerivation {
    name = "skipped-test";
    phases = [ "installPhase" ];
    installPhase = ''
      echo "echo test is skipped" > $out
    '';
  };

  # Overriding a test.xyz attribute with this derivation allows
  # test to be executed in a custom manner via Makefile provided in the
  # test directory
  makefileTest = root: pkg: src: super:
  let path = root + "/${src}/Makefile"; in
    super.pkgs."${pkg}".overrideAttrs {
      pname = "test-${pkg}";
      installPhase = "touch $out";
      dontCheck = false;
      buildPhase = ''
        runHook preBuild
        cp ${path} ${src}/Makefile
        make -C ${src}
        runHook postBuild
      '';
    };

  # Some attrsets helpers
  attrFold = f: acc: attrs:
    builtins.foldl' (acc: { fst, snd }: f acc fst snd) acc
    (pkgs.lib.zipLists (builtins.attrNames attrs) (builtins.attrValues attrs));
  attrAll = f: attrFold (acc: key: value: acc && f key value) true;
  setAttrByPath = val: attrs: path:
    if path == [ ] then
      val
    else
      let
        hd = builtins.head path;
        tl = builtins.tail path;
      in attrs // { "${hd}" = setAttrByPath val (attrs."${hd}" or { }) tl; };

  # Evaluates predicate against units of a given package
  # and returns true if any of units satisfy the predicate
  packageHasUnit = predicate: pkgDef:
    builtins.foldl' (acc0: v0:
      builtins.foldl' (acc: v: acc || predicate v) acc0
      (builtins.attrValues v0)) false (builtins.attrValues pkgDef);

  # Evaluates to true if any of the units of a package has tests
  packageHasTestDefs =
    packageHasUnit (v: (v.has_inline_tests or false) || v.type == "test");

  artifactEnvVar = pkgs.lib.concatMapStringsSep "_"
    (builtins.replaceStrings [ "-" "." "/" ] [ "___" "__" "___" ]);

in {
  inherit fixupSymlinksInSource quote skippedTest attrFold attrAll setAttrByPath
    packageHasTestDefs packageHasUnit artifactEnvVar makefileTest;
}
