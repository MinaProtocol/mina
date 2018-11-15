.. _formatting-main:

********************
Automatic formatting
********************

Dune can be set up to run automatic formatters for source code.

It can use ocamlformat_ to format OCaml source code (``*.ml`` and ``*.mli``
files) and refmt_ to format Reason source code (``*.re`` and ``*.rei`` files).

.. _ocamlformat: https://github.com/ocaml-ppx/ocamlformat
.. _refmt: https://github.com/facebook/reason/tree/master/src/refmt

Enabling automatic formatting
=============================

This feature is enabled by adding the following to the ``dune-project`` file:

.. code:: scheme

    (using fmt 1.0)

Formatting a project
====================

When this feature is active, an alias named ``fmt`` is defined. When built, it
will format the source files in the corresponding project and display the
differences:

.. code::

    $ dune build @fmt
    --- hello.ml
    +++ hello.ml.formatted
    @@ -1,3 +1 @@
    -let () =
    -  print_endline
    -    "hello, world"
    +let () = print_endline "hello, world"

It is then possible to accept the correction by calling ``dune promote`` to
replace the source files by the corrected versions.

.. code::

    $ dune promote
    Promoting _build/default/hello.ml.formatted to hello.ml.

As usual with promotion, it is possible to combine these two steps by running
``dune build @fmt --auto-promote``.

Only enabling it for certain languages
======================================

By default, formatting will be enabled for all languages present in the project
that dune knows about. This is not always desirable, for example if in a mixed
Reason/OCaml project, one only wants to format the Reason files to avoid pulling
``ocamlformat`` as a dependency.

In these cases, it is possible to use the ``enabled_for`` argument to restrict
the languages that are considered for formatting.

.. code:: scheme

    (using fmt 1.0 (enabled_for reason))
