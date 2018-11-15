next
----

- Expand variables in `install` stanzas (#1354, @mseri)

- Add predicate language support for ignoring sub directories. This allows the
  use globs, set operations, and special values in specifying the ignore sub
  directories. For example: `(ignore_subdirs * \ lib*)` ignores all directories
  except those that start with `lib`. (#1517, @rgrinberg)

- Add `binaries` field to the `(env ..)` stanza. This field sets and overrides
  binaries for rules defined in a directory. (#1521, @rgrinberg)

- Fix a crash caused by using an extension in a project without
  dune-project file (#...., fix #1529, @diml)

- Allow `%{bin:..}`, `%{exe:..}`, and other static expansions in the `deps`
  field. (#1155, fix #1531, @rgrinberg)

1.5.1 (7/11/2018)
-----------------

- Fix `dune utop <dir>` when invoked from a sub-directory of the
  project (#1520, fix #1518, @diml)

- Fix bad interaction between on-demand ppx rewriters and polling mode
  (#1525, fix #1524, @diml)

1.5.0 (1/11/2018)
-----------------

- Filter out empty paths from `OCAMLPATH` and `PATH` (#1436, @rgrinberg)

- Do not add the `lib.cma.js` target in lib's directory. Put this target in a
  sub directory instead. (#1435, fix #1302, @rgrinberg)

- Install generated OCaml files with a `.ml` rather than a `.ml-gen` extension
  (#1425, fix #1414, @rgrinberg)

- Allow to use the `bigarray` library in >= 4.07 without ocamlfind and without
  installing the corresponding `otherlib`. (#1455, @nojb)

- Add `@all` alias to build all targets defined in a directory (#1409, fix
  #1220, @rgrinberg)

- Add `@check` alias to build all targets required for type checking and tooling
  support. (#1447, fix #1220, @rgrinberg)

- Produce the odoc index page with the content wrapper to make it consistent
  with odoc's theming (#1469, @rizo)

- Unblock signals in processes started by dune (#1461, fixes #1451,
  @diml)

- Respect `OCAMLFIND_TOOLCHAIN` and add a `toolchain` option to contexts in the
  workspace file. (#1449, fix #1413, @rgrinberg)

- Fix error message when using `copy_files` stanza to copy files from
  a non sub directory with lang set to dune < 1.3 (#1486, fixes #1485,
  @NathanReb)

- Install man pages in the correct subdirectory (#1483, fixes #1441, @emillon)

- Fix version syntax check for `test` stanza's `action` field. Only
  emits a warning for retro-compatibility (#1474, fixes #1471,
  @NathanReb)

- Interpret the `DESTDIR` environment variable (#1475, @emillon)

- Fix interpretation of paths in `env` stanzas (#1509, fixes #1508, @diml)

- Add `context_name` expansion variable (#1507, @rgrinberg)

- Use shorter paths for generated on-demand ppx drivers. This is to
  help Windows builds where paths are limited in length (#1511, fixes
  #1497, @diml)

- Fix interpretation of environment variables under `setenv`. Also forbid
  dynamic environment names or values (#1503, @rgrinberg).

1.4.0 (10/10/2018)
------------------

- Do not fail if the output of `ocamlc -config` doesn't include
  `standard_runtime` (#1326, @diml)

- Let `Configurator.V1.C_define.import` handle negative integers
  (#1334, @Chris00)

- Re-execute actions when a target is modified by the user inside
  `_build` (#1343, fix #1342, @diml)

- Pass `--set-switch` to opam (#1341, fix #1337, @diml)

- Fix bad interaction between multi-directory libraries the `menhir`
  stanza (#1373, fix #1372, @diml)

- Integration with automatic formatters (#1252, fix #1201, @emillon)

- Better error message when using `(self_build_stubs_archive ...)` and
  `(c_names ...)` or `(cxx_names ...)` simultaneously.
  (#1375, fix #1306, @nojb)

- Improve name detection for packages when the prefix isn't an actual package
  (#1361, fix #1360, @rgrinberg)

- Support for new menhir rules (#863, fix #305, @fpottier, @rgrinberg)

- Do not remove flags when compiling compatibility modules for wrapped mode
  (#1382, fix #1364, @rgrinberg)

- Fix reason support when using `staged_pps` (#1384, @charlesetc)

- Add support for `enabled_if` in `rule`, `menhir`, `ocamllex`,
  `ocamlyacc` (#1387, @diml)

- Exit gracefully when a signal is received (#1366, @diml)

- Load all defined libraries recursively into utop (#1384, fix #1344,
  @rgrinberg)

- Allow to use libraries `bytes`, `result` and `uchar` without `findlib`
  installed (#1391, @nojb)

- Take argument to self_build_stubs_archive into account. (#1395, @nojb)

- Fix bad interaction between `env` customization and vendored
  projects: when a vendored project didn't have its own `env` stanza,
  the `env` stanza from the enclosing project was in effect (#1408,
  @diml)

- Fix stop early bug when scanning for watermarks (#1423, @struktured)

1.3.0 (23/09/2018)
------------------

- Support colors on Windows (#1290, @diml)

- Allow `dune.configurator` and `base` to be used together (#1291, fix
  #1167, @diml)

- Support interrupting and restarting builds on file changes (#1246,
  @kodek16)

- Fix findlib-dynload support with byte mode only (#1295, @bobot)

- Make `dune rules -m` output a valid makefile (#1293, @diml)

- Expand variables in `(targets ..)` field (#1301, #1320, fix #1189, @nojb,
  @rgrinberg, @diml)

- Fix a race condition on Windows that was introduced in 1.2.0
  (#1304, fix #1303, @diml)

- Fix the generation of .merlin files to account for private modules
  (@rgrinberg, fix #1314)

- Exclude the local opam switch directory (`_opam`) from the list of watched
  directories (#1315, @dysinger)

- Fix compilation of the module generated for `findlib.dynload`
  (#1317, fix #1310, @diml)

- Lift restriction on `copy_files` and `copy_files#` stanzas that files to be
  copied should be in a subdirectory of the current directory.
  (#1323, fix #911, @nojb)

1.2.1 (17/09/2018)
------------------

- Enrich the `dune` Emacs mode with syntax highlighting and indentation. New
  file `dune-flymake` to provide a hook `dune-flymake-dune-mode-hook` to enable
  linting of dune files. (#1265, @Chris00)

- Pass `link_flags` to `cc` when compiling with `Configurator.V1.c_test` (#1274,
  @rgrinberg)

- Fix digest calculation of aliases. It should take into account extra bindings
  passed to the alias (#1277, fix #1276, @rgrinberg)

- Fix a bug causing `dune` to fail eagerly when an optional library
  isn't available (#1281, @diml)

- ocamlmklib should use response files only if ocaml >= 4.08 (#1268, @bryphe)

1.2.0 (14/09/2018)
------------------

- Ignore stderr output when trying to find out the number of jobs
  available (#1118, fix #1116, @diml)

- Fix error message when the source directory of `copy_files` does not exist.
  (#1120, fix #1099, @emillon)

- Highlight error locations in error messages (#1121, @emillon)

- Display actual stanza when package is ambiguous (#1126, fix #1123, @emillon)

- Add `dune unstable-fmt` to format `dune` files. The interface and syntax are
  still subject to change, so use with caution. (#1130, fix #940, @emillon)

- Improve error message for `dune utop` without a library name (#1154, fix
  #1149, @emillon)

- Fix parsing `ocamllex` stanza in jbuild files (#1150, @rgrinberg)

- Highlight multi-line errors (#1131, @anuragsoni)

- Do no try to generate shared libraries when this is not supported by
  the OS (#1165, fix #1051, @diml)

- Fix `Flags.write_{sexp,lines}` in configurator by avoiding the use of
  `Stdune.Path` (#1175, fix #1161, @rgrinberg)

- Add support for `findlib.dynload`: when linking an executable using
  `findlib.dynload`, automatically record linked in libraries and
  findlib predicates (#1172, @bobot)

- Add support for promoting a selected list of files (#1192, @diml)

- Add an emacs mode providing helpers to promote correction files
  (#1192, @diml)

- Improve message suggesting to remove parentheses (#1196, fix #1173, @emillon)

- Add `(wrapped (transition "..message.."))` as an option that will generate
  wrapped modules but keep unwrapped modules with a deprecation message to
  preserve compatibility. (#1188, fix #985, @rgrinberg)

- Fix the flags passed to the ppx rewriter when using `staged_pps` (#1218, @diml)

- Add `(env var)` to add a dependency to an environment variable.
  (#1186, @emillon)

- Add a simple version of a polling mode: `dune build -w` keeps
  running and restarts the build when something change on the
  filesystem (#1140, @kodek16)

- Cleanup the way we detect the library search path. We no longer call
  `opam config var lib` in the default build context (#1226, @diml)

- Make test stanzas honor the -p flag. (#1236, fix #1231, @emillon)

- Test stanzas take an optional (action) field to customize how they run (#1248,
  #1195, @emillon)

- Add support for private modules via the `private_modules` field (#1241, fix
  #427, @rgrinberg)

- Add support for passing arguments to the OCaml compiler via a
  response file when the list of arguments is too long (#1256, @diml)

- Do not print diffs by default when running inside dune (#1260, @diml)

- Interpret `$ dune build dir` as building the default alias in `dir`. (#1259,
  @rgrinberg)

- Make the `dynlink` library available without findlib installed (#1270, fix
  #1264, @rgrinberg)

1.1.1 (08/08/2018)
------------------

- Fix `$ jbuilder --dev` (#1104, fixes #1103, @rgrinberg)

- Fix dune exec when `--build-dir` is set to an absolute path (#1105, fixes
  #1101, @rgrinberg)

- Fix duplicate profile argument in suggested command when an external library
  is missing (#1109, #1106, @emillon)

- `-opaque` wasn't correctly being added to modules without an interface.
  (#1108, fix #1107, @rgrinberg)

- Fix validation of library `name` fields and make sure this validation also
  applies when the `name` is derived from the `public_name`. (#1110, fix #1102,
  @rgrinberg)

- Fix a bug causing the toplevel `env` stanza in the workspace file to
  be ignored when at least one context had `(merlin)` (#1114, @diml)

1.1.0 (06/08/2018)
------------------

- Fix lookup of command line specified files when `--root` is given. Previously,
  passing in `--root` in conjunction with `--workspace` or `--config` would not
  work correctly (#997, @rgrinberg)

- Add support for customizing env nodes in workspace files. The `env` stanza is
  now allowed in toplevel position in the workspace file, or for individual
  contexts. This feature requires `(dune lang 1.1)` (#1038, @rgrinberg)

- Add `enabled_if` field for aliases and tests. This field controls whether the
  test will be ran using a boolean expression language. (#819, @rgrinberg)

- Make `name`, `names` fields optional when a `public_name`, `public_names`
  field is provided. (#1041, fix #1000, @rgrinberg)

- Interpret `X` in `--libdir X` as relative to `PREFIX` when `X` is relative
  (#1072, fix #1070, @diml)

- Add support for multi directory libraries by writing
  `(include_subdirs unqualified)` (#1034, @diml)

- Add `(staged_pps ...)` to support staged ppx rewriters such as ones
  using the OCaml typer like `ppx_import` (#1080, fix #193, @diml)

- Use `-opaque` in the `dev` profile. This option trades off binary quality for
  compilation speed when compiling .cmx files. (#1079, fix #1058, @rgrinberg)

- Fix placeholders in `dune subst` documentation (#1090, @emillon, thanks
  @trefis for the bug report)

- Add locations to errors when a missing binary in PATH comes from a dune file
  (#1096, fixes #1095, @rgrinberg)

1.0.1 (19/07/2018)
------------------

- Fix parsing of `%{lib:name:file}` forms (#1022, fixes #1019, @diml)

1.0.0 (10/07/2018)
------------------

- Do not load the user configuration file when running inside dune
  (#700 @diml)

- Do not infer ${null} to be a target (#693 fixes #694 @rgrinberg)

- Introduce jbuilder.configurator library. This is a revived version of
  janestreet's configurator library with better cross compilation support, a
  versioned API, and no external dependencies. (#673, #678 #692, #695
  @rgrinberg)

- Register the transitive dependencies of compilation units as the
  compiler might read `.cm*` files recursively (#666, fixes #660,
  @emillon)

- Fix a bug causing `jbuilder external-lib-deps` to crash (#723,
  @diml)

- `-j` now defaults to the number of processing units available rather
  4 (#726, @diml)

- Fix attaching index.mld to documentation (#731, fixes #717 @rgrinberg)

- Scan the file system lazily (#732, fixes #718 and #228, @diml)

- Add support for setting the default ocaml flags and for build
  profiles (#419, @diml)

- Display a better error messages when writing `(inline_tests)` in an
  executable stanza (#748, @diml)

- Restore promoted files when they are deleted or changed in the
  source tree (#760, fix #759, @diml)

- Fix a crash when using an invalid alias name (#762, fixes #761,
  @diml)

- Fix a crash when using c files from another directory (#758, fixes
  #734, @diml)

- Add an `ignored_subdirs` stanza to replace `jbuild-ignore` files
  (#767, @diml)

- Fix a bug where Dune ignored previous occurrences of duplicated
  fields (#779, @diml)

- Allow setting custom build directories using the `--build-dir` flag or
  `DUNE_BUILD_DIR` environment variable (#846, fix #291, @diml @rgrinberg)

- In dune files, remove support for block (`#| ... |#)`) and sexp
  (`#;`) comments. These were very rarely used and complicate the
  language (#837, @diml)

- In dune files, add support for block strings, allowing to nicely
  format blocks of texts (#837, @diml)

- Remove hard-coded knowledge of ppx_driver and
  ocaml-migrate-parsetree when using a `dune` file (#576, @diml)

- Make the output of Dune slightly more deterministic when run from
  inside Dune (#855, @diml)

- Simplify quoting behavior of variables. All values are now multi-valued and
  whether a multi valued variable is allowed is determined by the quoting and
  substitution context it appears in. (#849, fix #701, @rgrinberg)

- Fix documentation generation for private libraries. (#864, fix #856,
  @rgrinberg)

- Use `Marshal` to store digest and incremental databases. This improves the
  speed of 0 rebuilds. (#817, @diml)

* Allow setting environment variables in `findlib.conf` for cross compilation
  contexts. (#733, @rgrinberg)

- Add a `link_deps` field to executables, to specify link-time dependencies
  like version scripts. (#879, fix #852, @emillon)

- Rename `files_recursively_in` to `source_tree` to make it clearer it
  doesn't include generated files (#899, fix #843, @diml)

- Present the `menhir` stanza as an extension with its own version
  (#901, @diml)

- Improve the syntax of flags in `(pps ...)`. Now instead of `(pps
  (ppx1 -arg1 ppx2 (-foo x)))` one should write `(pps ppx1 -arg ppx2
  -- -foo x)` which looks nicer (#910, @diml)

- Make `(diff a b)` ignore trailing cr on Windows and add `(cmp a b)` for
  comparing binary files (#904, fix #844, @diml)

- Make `dev` the default build profile (#920, @diml)

- Version `dune-workspace` and `~/.config/dune/config` files (#932, @diml)

- Add the ability to build an alias non-recursively from the command
  line by writing `@@alias` (#926, @diml)

- Add a special `default` alias that defaults to `(alias_rec install)`
  when not defined by the user and make `@@default` be the default
  target (#926, @diml)

- Forbid `#require` in `dune` files in OCaml syntax (#938, @diml)

- Add `%{profile}` variable. (#938, @rgrinberg)

- Do not require opam-installer anymore (#941, @diml)

- Add the `lib_root` and `libexec_root` install sections (#947, @diml)

- Rename `path:file` to `dep:file` (#944, @emillon)

- Remove `path-no-dep:file` (#948, @emillon)

- Adapt the behavior of `dune subst` for dune projects (#960, @diml)

- Add the `lib_root` and `libexec_root` sections to install stanzas
  (#947, @diml)

- Add a `Configurator.V1.Flags` module that improves the flag reading/writing
  API (#840, @avsm)

- Add a `tests` stanza that simlpified defining regular and expect tests
  (#822, @rgrinberg)

- Change the `subst` subcommand to lookup the project name from the
  `dune-project` whenever it's available. (#960, @diml)

- The `subst` subcommand no longer looks up the root workspace. Previously this
  detection would break the command whenever `-p` wasn't passed. (#960, @diml)

- Add a `# DUNE_GEN` in META template files. This is done for consistency with
  `# JBUILDER_GEN`. (#958, @rgrinberg)

- Rename the following variables in dune files:
  + `SCOPE_ROOT` to `project_root`
  + `@` to `targets`
  + `^` to `deps`
  `<` was renamed in this PR and latter deleted in favor or named dependencies.
  (#957, @rgrinberg)

- Rename `ROOT` to `workspace_root` in dune files (#993, @diml)

- Lowercase all built-in %{variables} in dune files (#956, @rgrinberg)

- New syntax for naming dependencies: `(deps (:x a b) (:y (glob_files *.c*)))`.
  This replaces the use for `${<}` in dune files. (#950, @diml, @rgrinberg)

- Fix detection of dynamic cycles, which in particular may appear when
  using `(package ..)` dependencies (#988, @diml)

1.0+beta20 (10/04/2018)
-----------------------

- Add a `documentation` stanza. This stanza allows one to attach .mld files to
  opam packages. (#570 @rgrinberg)

- Execute all actions (defined using `(action ..)`) in the context's
  environment. (#623 @rgrinberg)

- Add a `(universe)` special dependency to specify that an action depend on
  everything in the universe. Jbuilder cannot cache the result of an action that
  depend on the universe (#603, fixes #255 @diml)

- Add a `(package <package>)` dependency specification to indicate dependency on
  a whole package. Rules depending on whole package will be executed in an
  environment similar to the one we get once the package is installed (#624,
  @rgrinberg and @diml)

- Don't pass `-runtime-variant _pic` on Windows (#635, fixes #573 @diml)

- Display documentation in alphabetical order. This is relevant to packages,
  libraries, and modules. (#647, fixes #606 @rgrinberg)

- Missing asm in ocaml -config on bytecode only architecture is no longer fatal.
  The same kind of fix is preemptively applied to C compilers being absent.
  (#646, fixes $637 @rgrinberg)

- Use the host's PATH variable when running actions during cross compilation
  (#649, fixes #625 @rgrinberg)

- Fix incorrect include (`-I`) flags being passed to odoc. These flags should be
  directories that include .odoc files, rather than the include flags of the
  libraries. (#652 fixes #651 @rgrinberg)

- Fix a regression introduced by beta19 where the generated merlin
  files didn't include the right `-ppx` flags in some cases (#658
  fixes #657 @diml)

- Fix error message when a public library is defined twice. Before
  jbuilder would raise an uncaught exception (Fixes #661, @diml)

- Fix several cases where `external-lib-deps` was returning too little
  dependencies (#667, fixes #644 @diml)

- Place module list on own line in generated entry point mld (#670 @antron)

- Cosmetic improvements to generated entry point mld (#653 @trefis)

- Remove most useless parentheses from the syntax (#915, @diml)

1.0+beta19.1 (21/03/2018)
-------------------------

- Fix regression introduced by beta19 where duplicate environment variables in
  Unix.environ would cause a fatal error. The first defined environment variable
  is now chosen. (#638 fixed by #640)

- Use ';' as the path separator for OCAMLPATH on Cygwin (#630 fixed by #636
  @diml).

- Use the contents of the `OCAMLPATH` environment variable when not relying on
  `ocamlfind` (#642 @diml)

1.0+beta19 (14/03/2018)
-----------------------

- Ignore errors during the generation of the .merlin (#569, fixes #568 and #51)

- Add a workaround for when a library normally installed by the
  compiler is not installed but still has a META file (#574, fixes
  #563)

- Do not depend on ocamlfind. Instead, hard-code the library path when
  installing from opam (#575)

- Change the default behavior regarding the check for overlaps between
  local and installed libraries. Now even if there is no link time
  conflict, we don't allow an external dependency to overlap with a
  local library, unless the user specifies `allow_overlapping_dependencies`
  in the jbuild file (#587, fixes #562)

- Expose a few more variables in jbuild files: `ext_obj`, `ext_asm`,
  `ext_lib`, `ext_dll` and `ext_exe` as well as `${ocaml-config:XXX}`
  for most variables in the output of `ocamlc -config` (#590)

- Add support for inline and inline expectation tests. The system is
  generic and should support several inline test systems such as
  `ppx_inline_test`, `ppx_expect` or `qtest` (#547)

- Make sure modules in the current directory always have precedence
  over included directories (#597)

- Add support for building executables as object or shared object
  files (#23)

- Add a `best` mode which is native with fallback to byte-code when
  native compilation is not available (#23)

- Fix locations reported in error messages (#609)

- Report error when a public library has a private dependency. Previously, this
  would be silently ignored and install broken artifacts (#607).

- Fix display when output is not a tty (#518)

1.0+beta18.1 (14/03/2018)
-------------------------

- Reduce the number of simultaneously opened fds (#578)

- Always produce an implementation for the alias module, for
  non-jbuilder users (Fix #576)

- Reduce interleaving in the scheduler in an attempt to make Jbuilder
  keep file descriptors open for less long (#586)

- Accept and ignore upcoming new library fields: `ppx.driver`,
  `inline_tests` and `inline_tests.backend` (#588)

- Add a hack to be able to build ppxlib, until beta20 which will have
  generic support for ppx drivers

1.0+beta18 (25/02/2018)
-----------------------

- Fix generation of the implicit alias module with 4.02. With 4.02 it
  must have an implementation while with OCaml >= 4.03 it can be an
  interface only module (#549)

- Let the parser distinguish quoted strings from atoms.  This makes
  possible to use "${v}" to concatenate the list of values provided by
  a split-variable.  Concatenating split-variables with text is also
  now required to be quoted.

- Split calls to ocamldep. Before ocamldep would be called once per
  `library`/`executables` stanza. Now it is called once per file
  (#486)

- Make sure to not pass `-I <stdlib-dir>` to the compiler. It is
  useless and it causes problems in some cases (#488)

- Don't stop on the first error. Before, jbuilder would stop its
  execution after an error was encountered. Now it continues until
  all branches have been explored (#477)

- Add support for a user configuration file (#490)

- Add more display modes and change the default display of
  Jbuilder. The mode can be set from the command line or from the
  configuration file (#490)

- Allow to set the concurrency level (`-j N`) from the configuration file (#491)

- Store artifacts for libraries and executables in separate
  directories. This ensure that Two libraries defined in the same
  directory can't see each other unless one of them depend on the
  other (#472)

- Better support for mli/rei only modules (#489)

- Fix support for byte-code only architectures (#510, fixes #330)

- Fix a regression in `external-lib-deps` introduced in 1.0+beta17
  (#512, fixes #485)

- `@doc` alias will now build only documentation for public libraries. A new
  `@doc-private` alias has been added to build documentation for private
  libraries.

- Refactor internal library management. It should now be possible to
  run `jbuilder build @lint` in Base for instance (#516)

- Fix invalid warning about non-existent directory (#536, fixes #534)

1.0+beta17 (01/02/2018)
-----------------------

- Make jbuilder aware that `num` is an external package in OCaml >= 4.06.0
  (#358)

- `jbuilder exec` will now rebuild the executable before running it if
  necessary. This can be turned off by passing `--no-build` (#345)

- Fix `jbuilder utop` to work in any working directory (#339)

- Fix generation of META synopsis that contains double quotes (#337)

- Add `S .` to .merlin by default (#284)

- Improve `jbuilder exec` to make it possible to execute non public executables.
  `jbuilder exec path/bin` will execute `bin` inside default (or specified)
  context relative to `path`. `jbuilder exec /path` will execute `/path` as
  absolute path but with the context's environment set appropriately. Lastly,
  `jbuilder exec` will change the root as to which paths are relative using the
  `-root` option. (#286)

- Fix `jbuilder rules` printing rules when some binaries are missing (#292)

- Build documentation for non public libraries (#306)

- Fix doc generation when several private libraries have the same name (#369)

- Fix copy# for C/C++ with Microsoft C compiler (#353)

- Add support for cross-compilation. Currently we are supporting the
  opam-cross-x repositories such as
  [opam-cross-windows](https://github.com/whitequark/opam-cross-windows)
  (#355)

- Simplify generated META files: do not generate the transitive
  closure of dependencies in META files (#405)

- Deprecated `${!...}`: the split behavior is now a property of the
  variable. For instance `${CC}`, `${^}`, `${read-lines:...}` all
  expand to lists unless used in the middle of a longer atom (#336)

- Add an `(include ...)` stanza allowing one to include another
  non-generated jbuild file in the current file (#402)

- Add a `(diff <file1> <file2>)` action allowing to diff files and
  promote generated files in case of mismatch (#402, #421)

- Add `jbuilder promote` and `--auto-promote` to promote files (#402,
  #421)

- Report better errors when using `(glob_files ...)` with a directory
  that doesn't exist (#413, Fix #412)

- Jbuilder now properly handles correction files produced by
  ppx_driver. This allows to use `[@@deriving_inline]` in .ml/.mli
  files. This require `ppx_driver >= v0.10.2` to work properly (#415)

- Make jbuilder load rules lazily instead of generating them all
  eagerly. This speeds up the initial startup time of jbuilder on big
  workspaces (#370)

- Now longer generate a `META.pkg.from-jbuilder` file. Now the only
  way to customize the generated `META` file is through
  `META.pkg.template`. This feature was unused and was making the code
  complicated (#370)

- Remove read-only attribute on Windows before unlink (#247)

- Use /Fo instead of -o when invoking the Microsoft C compiler to eliminate
  deprecation warning when compiling C++ sources (#354)

- Add a mode field to `rule` stanzas:
  + `(mode standard)` is the default
  + `(mode fallback)` replaces `(fallback)`
  + `(mode promote)` means that targets are copied to the source tree
  after the rule has completed
  + `(mode promote-until-clean)` is the same as `(mode promote)` except
  that `jbuilder clean` deletes the files copied to the source tree.
  (#437)

- Add a flag `--ignore-promoted-rules` to make jbuilder ignore rules
  with `(mode promote)`. `-p` implies `--ignore-promoted-rules` (#437)

- Display a warning for invalid lines in jbuild-ignore (#389)

- Always build `boot.exe` as a bytecode program. It makes the build of
  jbuilder faster and fix the build on some architectures (#463, fixes #446)

- Fix bad interaction between promotion and incremental builds on OSX
  (#460, fix #456)

1.0+beta16 (05/11/2017)
-----------------------

- Fix build on 32-bit OCaml (#313)

1.0+beta15 (04/11/2017)
-----------------------

- Change the semantic of aliases: there are no longer aliases that are
  recursive such as `install` or `runtest`. All aliases are
  non-recursive. However, when requesting an alias from the command
  line, this request the construction of the alias in the specified
  directory and all its children recursively. This allows users to get
  the same behavior as previous recursive aliases for their own
  aliases, such as `example`. Inside jbuild files, one can use `(deps
  (... (alias_rec xxx) ...))` to get the same behavior as on the
  command line. (#268)

- Include sub libraries that have a `.` in the generated documentation index
  (#280).

- Fix "up" links to the top-level index in the odoc generated documentation
  (#282).

- Fix `ARCH_SIXTYFOUR` detection for OCaml 4.06.0 (#303)

1.0+beta14 (11/10/2017)
-----------------------

- Add (copy_files <glob>) and (copy_files# <glob>) stanzas. These
  stanzas setup rules for copying files from a sub-directory to the
  current directory. This provides a reasonable way to support
  multi-directory library/executables in jbuilder (#35, @bobot)

- An empty `jbuild-workspace` file is now interpreted the same as one
  containing just `(context default)`

- Better support for on-demand utop toplevels on Windows and when the
  library has C stubs

- Print `Entering directory '...'` when the workspace root is not the
  current directory. This allows Emacs and Vim to know where relative
  filenames should be interpreted from. Fixes #138

- Fix a bug related to `menhir` stanzas: `menhir` stanzas with a
  `merge_into` field that were in `jbuild` files in sub-directories
  where incorrectly interpreted (#264)

- Add support for locks in actions, for tests that can't be run
  concurrently (#263)

- Support `${..}` syntax in the `include` stanza. (#231)

1.0+beta13 (05/09/2017)
-----------------------

- Generate toplevel html index for documentation (#224, @samoht)

- Fix recompilation of native artifacts. Regression introduced in the last
  version (1.0+beta12) when digests replaces timestamps for checking staleness
  (#238, @dra27)

1.0+beta12 (18/08/2017)
-----------------------

- Fix the quoting of `FLG` lines in generated `.merlin` files (#200,
  @mseri)

- Use the full path of archive files when linking. Before jbuilder
  would do: `-I <path> file.cmxa`, now it does `-I <path>
  <path>/file.cmxa`. Fixes #118 and #177

- Use an absolute path for ppx drivers in `.merlin` files. Merlin
  <3.0.0 used to run ppx commands from the directory where the
  `.merlin` was present but this is no longer the case

- Allow to use `jbuilder install` in contexts other than opam; if
  `ocamlfind` is present in the `PATH` and the user didn't pass
  `--prefix` or `--libdir` explicitly, use the output of `ocamlfind
  printconf destdir` as destination directory for library files (#179,
  @bobot)

- Allow `(:include ...)` forms in all `*flags` fields (#153, @dra27)

- Add a `utop` subcommand. Running `jbuilder utop` in a directory
  builds and executes a custom `utop` toplevel with all libraries
  defined in the current directory (#183, @rgrinberg)

- Do not accept `per_file` anymore in `preprocess` field. `per_file`
  was renamed `per_module` and it is planned to reuse `per_file` for
  another purpose

- Warn when a file is both present in the source tree and generated by
  a rule. Before, jbuilder would silently ignore the rule. One now has
  to add a field `(fallback)` to custom rules to keep the current
  behavior (#218)

- Get rid of the `deprecated-ppx-method` findlib package for ppx
  rewriters (#222, fixes #163)

- Use digests (MD5) of files contents to detect changes rather than
  just looking at the timestamps. We still use timestamps to avoid
  recomputing digests. The performance difference is negligible and we
  avoid more useless recompilations, especially when switching branches
  for instance (#209, fixes #158)

1.0+beta11 (21/07/2017)
-----------------------

- Fix the error message when there are more than one `<package>.opam`
  file for a given package

- Report an error when in a wrapped library, a module that is not the
  toplevel module depends on the toplevel module. This doesn't make as
  such a module would in theory be inaccessible from the outside

- Add `${SCOPE_ROOT}` pointing to the root of the current scope, to
  fix some misuses of `${ROOT}`

- Fix useless hint when all missing dependencies are optional (#137)

- Fix a bug preventing one from generating `META.pkg.template` with a
  custom rule (#190)

- Fix compilation of reason projects: .rei files where ignored and
  caused the build to fail (#184)

1.0+beta10 (08/06/2017)
-----------------------

- Add a `clean` subcommand (@rdavison, #89)

- Add support for generating API documentation with odoc (#74)

- Don't use unix in the bootstrap script, to avoid surprises with
  Cygwin

- Improve the behavior of `jbuilder exec` on Windows

- Add a `--no-buffer` option to see the output of commands in
  real-time. Should only be used with `-j1`

- Deprecate `per_file` in preprocessing specifications and
  rename it `per_module`

- Deprecate `copy-and-add-line-directive` and rename it `copy#`

- Remove the ability to load arbitrary libraries in jbuild file in
  OCaml syntax. Only `unix` is supported since a few released packages
  are using it. The OCaml syntax might eventually be replaced by a
  simpler mechanism that plays better with incremental builds

- Properly define and implement scopes

- Inside user actions, `${^}` now includes files matches by
  `(glob_files ...)` or `(file_recursively_in ...)`

- When the dependencies and targets of a rule can be inferred
  automatically, you no longer need to write them: `(rule (copy a b))`

- Inside `(run ...)`, `${xxx}` forms that expands to lists can now be
  split across multiple arguments by adding a `!`: `${!xxx}`. For
  instance: `(run foo ${!^})`

- Add support for using the contents of a file inside an action:
  - `${read:<file>}`
  - `${read-lines:<file>}`
  - `${read-strings:<file>}` (same as `read-lines` but lines are
    escaped using OCaml convention)

- When exiting prematurely because of a failure, if there are other
  background processes running and they fail, print these failures

- With msvc, `-lfoo` is transparently replaced by `foo.lib` (@dra27, #127)

- Automatically add the `.exe` when installing executables on Windows
  (#123)

- `(run <prog> ...)` now resolves `<prog>` locally if
  possible. i.e. `(run ${bin:prog} ...)` and `(run prog ...)` behave
  the same. This seems like the right default

- Fix a bug where `jbuild rules` would crash instead of reporting a
  proper build error

- Fix a race condition in future.ml causing jbuilder to crash on
  Windows in some cases (#101)

- Fix a bug causing ppx rewriter to not work properly when using
  multiple build contexts (#100)

- Fix .merlin generation: projects in the same workspace are added to
  merlin's source path, so "locate" works on them.

1.0+beta9 (19/05/2017)
----------------------

- Add support for building Reason projects (@rgrinberg, #58)

- Add support for building javascript with js-of-ocaml (@hhugo, #60)

- Better support for topkg release workflow. See
  [topkg-jbuilder](https://github.com/diml/topkg-jbuilder) for more
  details

- Port the manual to rst and setup a jbuilder project on
  readthedocs.org (@rgrinberg, #78)

- Hint for mistyped targets. Only suggest correction on the basename
  for now, otherwise it's slow when the workspace is big

- Add a `(package ...)` field for aliases, so that one can restrict
  tests to a specific package (@rgrinberg, #64)

- Fix a couple of bugs on Windows:
  + fix parsing of end of lines in some cases
  + do not take the case into account when comparing environment
    variable names

- Add AppVeyor CI

- Better error message in case a chain of dependencies *crosses* the
  installed world

- Better error messages for invalid dependency list in jbuild files

- Several improvements/fixes regarding the handling of findlib packages:
  + Better error messages when a findlib package is unavailable
  + Don't crash when an installed findlib package has missing
    dependencies
  + Handle the findlib alternative directory layout which is still
    used by a few packages

- Add `jbuilder installed-libraries --not-available` explaining why
  some libraries are not available

- jbuilder now records dependencies on files of external
  libraries. This mean that when you upgrade a library, jbuilder will
  know what need to be rebuilt.

- Add a `jbuilder rules` subcommand to dump internal compilation
  rules, mostly for debugging purposes

- Ignore all directories starting with a `.` or `_`. This seems to be
  a common pattern:
  - `.git`, `.hg`, `_darcs`
  - `_build`
  - `_opam` (opam 2 local switches)

- Fix the hint for `jbuilder external-lib-deps` (#72)

- Do not require `ocamllex` and `ocamlyacc` to be at the same location
  as `ocamlc` (#75)

1.0+beta8 (17/04/2017)
----------------------

- Added `${lib-available:<library-name>}` which expands to `true` or
  `false` with the same semantic as literals in `(select ...)` stanzas

- Remove hard-coded knowledge of a few specific ppx rewriters to ease
  maintenance moving forward

- Pass the library name to ppx rewriters via the `library-name` cookie

- Fix: make sure the action working directory exist before running it

1.0+beta7 (12/04/2017)
----------------------

- Make the output quieter by default and add a `--verbose` argument
  (@stedolan, #40)

- Various documentation fixes (@adrieng, #41)

- Make `@install` the default target when no targets are specified
  (@stedolan, #47)

- Add predefined support for menhir, similar to ocamlyacc support
  (@rgrinberg, #42)

- Add internal support for sandboxing actions and sandbox the build of
  the alias module with 4.02 to workaround the compiler trying to read
  the cmi of the aliased modules

- Allow to disable dynlink support for libraries via `(no_dynlink)`
  (#55)

- Add a -p/--for-release-of-packages command line argument to simplify
  the jbuilder invocation in opam files and make it more future proof
  (#52)

- Fix the lookup of the executable in `jbuilder exec foo`. Before,
  even if `foo` was to be installed, the freshly built version wasn't
  selected

- Don't generate a `exists_if ...` lines in META files. These are
  useless sine the META files are auto-generated

1.0+beta6 (29/03/2017)
----------------------

- Add an `(executable ...)` stanza for single executables (#33)

- Add a `(package ...)` and `(public_name <name>)/(public_names
   (<names))` to `executable/executables` stanzas to make it easier to
  install executables (#33)

- Fix a bug when using specific rewriters that jbuilder knows about
  without `ppx_driver.runner` (#37). These problem should go away
  soon when we start using `--cookie`

- Fix the interpretation of META files when there is more than one
  applicable assignment. Before this fix, the one with the lowest
  number of formal predicates was selected instead of the one with the
  biggest number of formal predicates

1.0+beta5 (22/03/2017)
----------------------

- When `ocamlfind` is present in the `PATH`, do not attempt to call
  `opam config var lib`

- Make sure the build of jbuilder itself never calls `ocamlfind` or
  `opam`

- Better error message when a jbuild file in OCaml syntax forgets to
  call `Jbuild_plugin.V*.send`

- Added examples of use

- Don't drop inline tests/benchmarks by default

1.0+beta4 (20/03/2017)
----------------------

- Improve error messages about invalid/missing pkg.opam files

- Ignore all errors while running `ocamlfind printconf path`

1.0+beta3 (15/03/2017)
----------------------

- Print optional dependencies as optional in the output of `jbuilder
   external-lib-deps --missing`

- Added a few forms to the DSL:
  - `with-{stderr,outputs}-to`
  - `ignore-{stdout,stderr,outputs}`
- Added `${null}` which expands to `/dev/null` on Unix and `NUL` on
  Windows

- Improve the doc generated by `odoc` for wrapped libraries

- Improve the error reported when an installed package depends on a
  library that is not installed

- Documented `(files_recursively_in ...)`

- Added black box tests

- Fix a bug where `jbuilder` would crash when there was no
  `<package>.opam` file

- Fixed a bug where `.merlin` files where not generated at the root of
  the workspace (#20)

- Fix a bug where a `(glob_files ...)` would cause other dependencies
  to be ignored

- Fix the generated `ppx(...)` line in `META` files

- Fix `(optional)` when a ppx runtime dependency is not available
  (#24)

- Do not crash when an installed package that we don't need has
  missing dependencies (#25)

1.0+beta2 (10/03/2017)
----------------------

- Simplified the rules for finding the root of the workspace as the
  old ones were often picking up the home directory. New rules are:
  + look for a `jbuild-workspace` file in parent directories
  + look for a `jbuild-workspace*` file in parent directories
  + use the current directory
- Fixed the expansion of `${ROOT}` in actions

- Install `quick-start.org` in the documentation directory

- Add a few more things in the log file to help debugging

1.0+beta1 (07/03/2017)
----------------------

- Added a manual

- Support incremental compilation

- Switched the CLI to cmdliner and added a `build` command (#5, @rgrinberg)

- Added a few commands:
  + `runtest`
  + `install`
  + `uninstall`
  + `installed-libraries`
  + `exec`: execute a command in an environment similar to what you
    would get after `jbuilder install`
- Removed the `build-package` command in favor of a `--only-packages`
  option that is common to all commands

- Automatically generate `.merlin` files (#2, @rdavison)

- Improve the output of jbuilder, in particular don't mangle the
  output of commands when using `-j N` with `N > 1`

- Generate a log in `_build/log`

- Versioned the jbuild format and added a first stable version. You
  should now put `(jbuilder_version 1)` in a `jbuild` file at the root
  of your project to ensure forward compatibility

- Switch from `ppx_driver` to `ocaml-migrate-parsetree.driver`. In
  order to use ppx rewriters with Jbuilder, they need to use
  `ocaml-migrate-parsetree.driver`

- Added support for aliases (#7, @rgrinberg)

- Added support for compiling against multiple opam switch
  simultaneously by writing a `jbuild-worspace` file

- Added support for OCaml 4.02.3

- Added support for architectures that don't have natdynlink

- Search the root according to the rules described in the manual
  instead of always using the current directory

- extended the action language to support common actions without using
  a shell:
  + `(with-stdout-to <file> <DSL>)`
  + `(copy <src> <dst>)`
  + ...

- Removed all implicit uses of bash or the system shell. Now one has
  to write explicitly `(bash "...")` or `(system "...")`

- Generate meaningful versions in `META` files

- Strengthen the scope of a package. Jbuilder knows about package
  `foo` only in the sub-tree starting from where `foo.opam` lives

0.1.alpha1 (04/12/2016)
-----------------------

First release
