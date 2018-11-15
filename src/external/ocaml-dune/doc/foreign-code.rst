******************************
Dealing with foreign libraries
******************************

The OCaml programming language allows to interface libraries written
in foreign languages such as C. This section explains how to do this
with Dune. Note that it does not cover how to write the C stubs
themselves, this is covered by the
`OCaml manual <https://caml.inria.fr/pub/docs/manual-ocaml/intfc.html>`_

More precisely, this section covers:
- how to add C/C++ stubs to an OCaml library
- how to pass specific compilation flags for compiling the stubs
- how to build a library with a foreign build system

Note that in general Dune has limited support for building source
files written in foreign languages. This support is suitable for most
OCaml projects containing C stubs, but is too limited for building
complex libraries written in C or other languages. For such cases,
Dune allows to integrate a foreign build system into a normal Dune
build.

Adding C/C++ stubs to an OCaml library
======================================

To add C stubs to an OCaml library, simply list the C files without
the ``.c`` extension via the ``c_names`` field of the :ref:`library`
stanza. For instance:

.. code:: scheme

          (library
           (name mylib)
           (c_names file1 file2))

Similarly, you can add C++ stubs to an OCaml library by listing them
without the ``.cpp`` extension via the ``cxx_names`` field.

Dune is currently not flexible regarding the extension of the C/C++
source files. They have to be ``.c`` and ``.cpp``. If you have source
files that that do not follow this extension and you want to build
them with Dune, you need to rename them first. Alternatively, you can
use the :ref:`foreign build sandboxing <foreign-sandboxing>` method
described bellow.

Header files
------------

C/C++ source files may include header files in the same directory as
the C/C++ source files or in the same directory group when using
:ref:`include_subdirs`.

The header files must have the ``.h`` extension.

Installing header files
-----------------------

It is sometimes desirable to install header files with the
library. For that you have two choices: install them explicitely with
an :ref:`install` stanza or use the ``install_c_headers`` field of the
:ref:`library` stanza. This field takes a list of header files names
without the ``.h`` extension. When a library install header files,
these are made visible to users of the library via the include search
path.

.. _foreign-sandboxing:

Foreign build sandboxing
========================

When the build of a C library is too complicated to express in the
Dune language, it is possible to simply *sandbox* a foreign
build. Note that this method can be used to build other things, not
just C libraries.

To do that, follow the following procedure:
- put all the foreign code in a sub-directory
- tell Dune not to interpret configuration files in this directory via
  an :ref:`ignored_subdirs <dune-ignored_subdirs>` stanza
- write a custom rule that:
  + depend on this directory recursively via :ref:`source_tree`
  + invoke the external build system
  + copy the C archive files (``.a``, ``.so``, ...) in main library
    directory with a specific names (see bellow)
- *attach* the C archive files to an OCaml library via the
  :ref:`self_build_stubs_archive` field

For instance, let's assume that you want to build a C library
``libfoo`` using ``libfoo``'s own build system and attach it to an
OCaml library called ``foo``.

The first step is to put the sources of ``libfoo`` in your project,
for instance in ``src/libfoo``. Then tell dune to consider
``src/libfoo`` as raw data by writing the following in ``src/dune``:

.. code:: scheme

          (ignored_subdirs (libfoo))

The next step is to setup the rule to build ``libfoo``. For this,
writing the following code ``src/dune``:

.. code:: scheme

          (rule
           (deps (source_tree libfoo))
           (targets libfoo_stubs.a dllfoo_stubs.so)
           (action (progn
                    (chdir libfoo (run make)))
                    (copy libfoo/libfoo.a libfoo_stubs.a)
                    (copy libfoo/libfoo.so dllfoo_stubs.so)))

Note that the rule copies the files to ``libfoo_stubs.a`` and
``dllfoo_stubs.so``. It is important that the files produced are
named ``lib<ocaml-lib-name>_stubs.a`` and
``dll<ocaml-lib-name>_stubs.so``.

The last step is to attach these archives to an OCaml library as
follows:

.. code:: scheme

          (library
           (name bar)
           (self_build_stubs_archive foo))

Then, whenever you use the ``bar`` library, you will also be able to
use C functions from ``libfoo``.

Limitations
-----------

When using the sandboxing method, the following limitations apply:

- the build of the foreign code will be sequential
- the build of the foreign code won't be incremental

both these points could be improved. If you are interested in helping
make this happen, please let the Dune team know and someone will guide
you.

Real example
------------

The `re2 project <https://github.com/janestreet/re2>`_ uses this
method to build the re2 C library. You can look at the file
``re2/src/re2_c/jbuild`` in this project to see a full working
example.
