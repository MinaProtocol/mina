**********
Quickstart
**********

This document gives simple usage examples of dune. You can also look at
`examples <https://github.com/ocaml/dune/tree/master/example>`__ for complete
examples of projects using dune.

Building a hello world program
==============================

In a directory of your choice, write this ``dune`` file:

.. code:: scheme

    ;; This declares the hello_world executable implemented by hello_world.ml
    (executable
     (name hello_world))

This ``hello_world.ml`` file:

.. code:: ocaml

    print_endline "Hello, world!"

And build it with:

.. code:: bash

    dune build hello_world.exe

The executable will be built as ``_build/default/hello_world.exe``. Note that
native code executables will have the ``.exe`` extension on all platforms
(including non-Windows systems). The executable can be built and run in a single
step with ``dune exec ./hello_world.exe``.

Building a hello world program using Lwt
========================================

In a directory of your choice, write this ``dune`` file:

.. code:: scheme

    (executable
     (name hello_world)
     (libraries lwt.unix))

This ``hello_world.ml`` file:

.. code:: ocaml

    Lwt_main.run (Lwt_io.printf "Hello, world!\n")

And build it with:

.. code:: bash

    dune build hello_world.exe

The executable will be built as ``_build/default/hello_world.exe``

Building a hello world program using Core and Jane Street PPXs
==============================================================

Write this ``dune`` file:

.. code:: scheme

    (executable
     (name hello_world)
     (libraries core)
     (preprocess (pps ppx_jane)))

This ``hello_world.ml`` file:

.. code:: ocaml

    open Core

    let () =
      Sexp.to_string_hum [%sexp ([3;4;5] : int list)]
      |> print_endline

And build it with:

.. code:: bash

    dune build hello_world.exe

The executable will be built as ``_build/default/hello_world.exe``

Defining a library using Lwt and ocaml-re
=========================================

Write this ``dune`` file:

.. code:: scheme

    (library
     (name        mylib)
     (public_name mylib)
     (libraries re lwt))

The library will be composed of all the modules in the same directory.
Outside of the library, module ``Foo`` will be accessible as
``Mylib.Foo``, unless you write an explicit ``mylib.ml`` file.

You can then use this library in any other directory by adding ``mylib``
to the ``(libraries ...)`` field.

Setting the OCaml compilation flags globally
============================================

Write this ``dune`` file at the root of your project:

.. code:: scheme

    (env
     (dev
      (flags (:standard -w +42)))
     (release
      (flags (:standard -O3))))

`dev` and `release` correspond to build profiles. The build profile
can be selected from the command line with `--profile foo` or from a
`dune-workspace` file by writing:

.. code:: scheme

    (profile foo)

Using cppo
==========

Add this field to your ``library`` or ``executable`` stanzas:

.. code:: scheme

    (preprocess (action (run %{bin:cppo} -V OCAML:%{ocaml_version} %{input-file})))

Additionally, if you are include a ``config.h`` file, you need to
declare the dependency to this file via:

.. code:: scheme

    (preprocessor_deps config.h)

Using the .cppo.ml style like the ocamlbuild plugin
---------------------------------------------------

Write this in your ``dune`` file:

.. code:: scheme

    (rule
     (targets foo.ml)
     (deps    (:first-dep foo.cppo.ml) <other files that foo.ml includes>)
     (action  (run %{bin:cppo} %{first-dep} -o %{targets})))

Defining a library with C stubs
===============================

Assuming you have a file called ``mystubs.c``, that you need to pass
``-I/blah/include`` to compile it and ``-lblah`` at link time, write
this ``dune`` file:

.. code:: scheme

    (library
     (name            mylib)
     (public_name     mylib)
     (libraries       re lwt)
     (c_names         mystubs)
     (c_flags         (-I/blah/include))
     (c_library_flags (-lblah)))

Defining a library with C stubs using pkg-config
================================================

Same context as before, but using ``pkg-config`` to query the
compilation and link flags. Write this ``dune`` file:

.. code:: scheme

    (library
     (name            mylib)
     (public_name     mylib)
     (libraries       re lwt)
     (c_names         mystubs)
     (c_flags         (:include c_flags.sexp))
     (c_library_flags (:include c_library_flags.sexp)))

    (rule
     (targets c_flags.sexp c_library_flags.sexp)
     (deps    (:discover config/discover.exe))
     (action  (run %{discover} -ocamlc %{OCAMLC})))

Then create a ``config`` subdirectory and write this ``dune`` file:

.. code:: scheme

    (executable
     (name discover)
     (libraries base stdio configurator))

as well as this ``discover.ml`` file:

.. code:: ocaml


    module C = Configurator.V1

    let () =
    C.main ~name:"foo" (fun c ->
    let default : C.Pkg_config.package_conf =
      { libs   = ["-lgst-editing-services-1.0"]
      ; cflags = []
      }
    in
    let conf =
      match C.Pkg_config.get c with
      | None -> default
      | Some pc ->
         match (C.Pkg_config.query pc ~package:"gst-editing-services-1.0") with
         | None -> default
         | Some deps -> deps
    in


    C.Flags.write_sexp "c_flags.sexp"         conf.cflags;
    C.Flags.write_sexp "c_library_flags.sexp" conf.libs)


Using a custom code generator
=============================

To generate a file ``foo.ml`` using a program from another directory:

.. code:: scheme

    (rule
     (targets foo.ml)
     (deps    (:gen ../generator/gen.exe))
     (action  (run %{gen} -o %{targets})))

Defining tests
==============

Write this in your ``dune`` file:

.. code:: scheme

    (test (name my_test_program))

And run the tests with:

.. code:: bash

    dune runtest

It will run the test program (the main module is ``my_test_program.ml``) and
error if it exits with a nonzero code.

In addition, if a ``my_test_program.expected`` file exists, it will be compared
to the standard output of the test program and the differences will be
displayed. It is possible to replace the ``.expected`` file with the last output
using:

.. code:: bash

    dune promote

Building a custom toplevel
==========================

A toplevel is simply an executable calling ``Topmain.main ()`` and linked with
the compiler libraries and ``-linkall``. Moreover, currently toplevels can only
be built in bytecode.

As a result, write this in your ``dune`` file:

.. code:: scheme

    (executable
     (name       mytoplevel)
     (libraries  compiler-libs.toplevel mylib)
     (link_flags (-linkall))
     (modes      byte))

And write this in ``mytoplevel.ml``

.. code:: ocaml

    let () = Topmain.main ()
