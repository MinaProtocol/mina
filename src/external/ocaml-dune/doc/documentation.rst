.. _documentation:

************************
Generating Documentation
************************

Prerequisites
=============

Documentation in dune is done courtesy of the odoc_ tool. Therefore, to
generate documentation in dune, you will need to install this tool. This
should likely be done with opam:

::

  $ opam install odoc

Writing Documentation
=====================

Documentation comments will be automatically extracted from your OCaml source
files following the syntax described in the the section ``Text formatting`` of
the `OCaml manual <http://caml.inria.fr/pub/docs/manual-ocaml/ocamldoc.html>`_.

Additional documentation pages may by attached to a package can be attached
using the :ref:`doc-stanza`.

Building Documentation
======================

Building the documentation using the ``@doc`` alias. Hence, all that is required
to generate documentation for your project is building this alias:

::

  $ dune build @doc

An index page containing links to all the opam packages in your project can be
found in:

::

  $ open _build/default/_doc/_html/index.html

Documentation for private libraries may also be built with:

::

  $ dune build @doc-private

But this libraries will not be in the main html listing above, since they do not
belong to any particular package. But the generated html will still be found in
``_build/default/_doc/_html/<library>``.

.. _doc-stanza:

Documentation Stanza
====================

Documentation pages will be automatically generated for from .ml and .mli files
that include ocamldoc fragments. Additional manual pages may be attached to
packages using the ``documentation`` stanza. These .mld files must contain text
in the same syntax as ocamldoc comments.

.. code-block:: lisp

  (documentation (<optional-fields>)))


Where ``<optional-fields>`` are:

- ``(package <name>)`` the package this documentation should be attached to. If
  this absent, dune will try to infer it based on the location of the
  stanza.

- ``(mld_files <arg>)`` where ``<arg>`` field follows the
  :ref:`ordered-set-language`. This is a set of extension-less, mld file base
  names that are attached to the package. Where ``:standard`` refers to all the
  ``.mld`` files in the stanza's directory.

The ``index.mld`` file (specified as ``index`` in ``mld_files``) is treated
specially by dune. This will be the file used to generate the entry page for the
package. This is the page that will be linked from the main package listing. If
you omit writing an ``index.mld``, dune will generate one with the entry modules
for your package. But this generated will not be installed.

All mld files attached to a package will be included in the generated
``.install`` file for that package, and hence will be installed by opam.

Examples
--------

This stanza use attach all the .mld files in the current directory in a project
with a single package.

.. code-block:: lisp

   (documentation ())

This stanza will attach three mld files to package foo. The ``mld`` files should
be named ``foo.mld``, ``bar.mld``, and ``baz.mld``

.. code-block:: lisp

   (documentation
    ((package foo)
     (mld_files (foo bar baz))))

This stanza will attach all mld files excluding ``wip.mld`` in the current
directory to the inferred package:

.. code-block:: lisp

   (documentation
    ((mld_files (:standard \ wip))))

.. _odoc: https://github.com/ocaml-doc/odoc
