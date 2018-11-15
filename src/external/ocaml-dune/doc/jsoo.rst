***********
js_of_ocaml
***********

js_of_ocaml_ is a compiler from OCaml to JavaScript. The compiler works by
translating OCaml bytecode to JS files. From here on, we'll abbreviate
js_of_ocaml to jsoo. The compiler can be installed with opam:

.. code:: bash

   $ opam install js_of_ocaml-compiler

Compiling to JS
===============

Dune has full support building jsoo libraries and executables transparently.
There's no need to customize or enable anything to compile ocaml
libraries/executables to JS.

To build a JS executable, just define an executable as you would normally.
Consider this example:

.. code:: bash

   echo 'print_endline "hello from js"' > foo.ml

With the following dune file:

.. code:: scheme

  (executable (name foo))

And then request the ``.js`` target:

.. code:: bash

   $ dune build ./foo.bc.js
   $ node _build/default/foo.bc.js
   hello from js

Similar targets are created for libraries, but we recommend sticking to the
executable targets.

.. _dune-jsoo-field:

``js_of_ocaml`` field
=====================

In ``library`` and ``executables`` stanzas, you can specify js_of_ocaml options
using ``(js_of_ocaml (<js_of_ocaml-options>))``.

``<js_of_ocaml-options>`` are all optional:

- ``(flags <flags>)`` to specify flags passed to ``js_of_ocaml``. This field
  supports ``(:include ...)`` forms

- ``(javascript_files (<files-list>))`` to specify ``js_of_ocaml`` JavaScript
  runtime files.

``<flags>`` is specified in the :ref:`ordered-set-language`.

The default value for ``(flags ...)`` depends on the selected build profile. The
build profile ``dev`` (the default) will enable sourcemap and the pretty
JavaScript output.

Separate Compilation
====================

Dune supports two modes of compilation

- Direct compilation of a bytecode program to JavaScript. This mode allows
  js_of_ocaml to perform whole program deadcode elimination and whole program
  inlining.

- Separate compilation, where compilation units are compiled to JavaScript
  separately and then linked together. This mode is useful during development as
  it builds more quickly.

The separate compilation mode will be selected when the build profile is
``dev``, which is the default. There is currently no other way to control this
behaviour.

.. _js_of_ocaml: http://ocsigen.org/js_of_ocaml/
