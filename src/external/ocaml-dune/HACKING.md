# Hacking on Dune

This section is for people who want to work on Dune itself.

## Bootstrap

In order to build itself, Dune uses an OCaml script
([bootstrap.ml](bootstrap.ml)) that dumps most of the sources of Dune into a
single `boot.ml` file. This file is built using `ocamlopt` or `ocamlc`
and used to build everything else.

To get the development version bootstrapped and installed, run the following
while in the project's root directory:

```sh
$ make          # create the dune.exe file and bootstrap the dune build
$ make install  # install the newly built dune
```

Note that we don't include all of the sources in boot.ml. We skip a
few parts to speed up the build. In particular:
- vendored libraries are replaced by simpler implementations taken
  from `vendor/boot`
- a few files in `src` have an alternative version. These alternatives
  versions are named `XXX.boot.EXT`. For instance: `glob_lexer.boot.ml`

## OCaml compatibility test

Install opam switches for all the entries in the
[dune-workspace.dev](dune-workspace.dev) file and run:

```sh
$ make all-supported-ocaml-versions
```

## Repository organization

- `vendor/` contains dependencies of Dune, that have been vendored
- `plugin/` contains the API given to `dune` files that are OCaml
  scripts
- `src/` contains the core of `Dune`
- `bin/` contains the command line interface
- `doc/` contains the manual and rules to generate the manual pages

## Design

Dune (nee "JBuilder") was initially designed to sort out the public release of
Jane Street packages which became incredibly complicated over time. It is still
successfully used for this purpose.

One necessary feature to achieve this is the ability to precisely
report the external dependencies necessary to build a given set of
targets without running any command, just by looking at the source
tree. This is used to automatically generate the `<package>.opam`
files for all Jane Street packages.

To implement this, the build rules are described using a build arrow,
which is defined in [src/build.mli](src/build.mli). In the end it makes the
development of the internal rules of Dune very composable and
quite pleasant.

To deal with process multiplexing, Dune uses a simplified
Lwt/Async-like monad, implemented in [src/fiber/fiber.mli](src/fiber/fiber.mli).

## Tests

Dune uses [cram style](https://blog.janestreet.com/testing-with-expectations/)
tests for its test suite. The test suite is contained in
[test/blackbox-tests](test/blackbox-tests). A single test consists of a test
directory in the test-cases/ sub directory which contains a run.t file defining
the test.

An example `run.t` file:

```
A description of the test. The command running the tests is preceeded by
two spaces and a $. The expected output of the command is also indented by
two spaces and is right below the command (note the absence of a $)

  $ echo "the expected output is below"
  the expected output is below
```

Running the entire test suite is done with `$ make test`. A particular test can
be executed with `$ dune build @<test-name>`.

Running the test will execute the command after the `$` and its output will be
compared against the expected output right below the command. Any differences
will result in a test failure.

### Adding a Test

Simply add a new directory in test/blackbox-tests/test-cases and then `$ make`
generate the rules for the test , followed by `$ make promote` to accept the new
rules.

### Accepting Corrections

A failing expect test will generate a diff between the expected and actual
output. If the new output generate by the command is satisfactory, it can be
*promoted* with the `$ make promote` command.

## Code flow

- [src/dune_file.mli](src/dune_file.mli) contains the internal representation
  of `dune` files and the parsing code
- [src/jbuild_load.mli](src/jbuild_load.mli) contains the code to scan
  a source tree and build the internal database by reading
  the `dune` files
- [src/gen_rules.mli](src/gen_rules.mli) contains all the build rules
  of Dune
- [src/build_system.mli](src/build_system.mli) contains a trivial
  implementation of a Build system. This is what Jenga will provide
  when implementing the bridge
