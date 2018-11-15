This file describe how the jbuilder test suite is organized.

# Unit testing

The `unit-tests` directory contains unit tests, written in expectation
style. The test logic is implemented in `unit-tests/expect_test.mll`
and the various tests are in `.mlt` files.

The way they work is quite simple; each `.mlt` file is a succession of
toplevel phrases followed by the output reported by the OCaml toplevel
enclosed in an `[%%expect]` extension point. For instance:

```ocaml
6 * 7;;
[%%expect{|
- : int = 42
|}]
```

# Blackbox testing

The `blackbox-tests` contains blackbox tests. I.e. we are testing the
fully built `jbuilder` executable on various example projects.

The tests are written in [cram](https://bitheap.org/cram/) style. The
logic is implemented in `blackbox-tests/cram.mll`. It only implements
a minimal subset of cram testing. In particular the shell environment
is currently not preserved between commands, so you cannot define a
variable and use it.

Test cases are in `blackbox-tests/test-cases`. Each sub-directory is a
full blown jbuilder project. Each sub-directory contains a `run.t`
file, which represents a few invocations of jbuilder along with the
expected output.

Here is a sample `.t` file:

```
This is a comment

  $ echo 'Hello, world!'
  Hello, world!

  $ cat plop
  cat: plop: No such file or directory
  [1]

The [1] represent the exit code of the command. It is printed when it
is non-zero
```
