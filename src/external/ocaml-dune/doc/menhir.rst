.. _menhir-main:

******
Menhir
******

To use menhir in a dune project, the language version should be selected in the
``dune-project`` file. For example:

.. code:: scheme

  (using menhir 2.0)

This will enable support for menhir stanzas in the current project. If the
language version is absent, dune will automatically add this line with the
latest menhir version to the project file once a menhir stanza is used anywhere.


Basic Usage
===========

The basic form for defining menhir_ parsers (analogous to ocamlyacc) is:

.. code:: scheme

    (menhir
     (modules <parser1> <parser2> ...))

Modular Menhir
==============

Modular parsers can be defined by adding a ``merge_into`` field. This correspond
to the ``--base`` command line option of ``menhir``. With this option, a single
parser named ``base_name`` is generated.

.. code:: scheme

    (menhir
     (merge_into <base_name>)
     (modules <parser1> <parser2> ...))

Flags
=====

Extra flags can be passed to menhir using the ``flags`` flag:

.. code:: scheme

    (menhir
     (flags <option1> <option2> ...)
     (modules <parser1> <parser2> ...))

``--infer`` mode
================

Menhir language 2.0 automatically enables using menhir with type inference. This
ability can also be manually controlled with the ``infer`` field manually.

.. code:: scheme

  (menhir
    (infer false)
    (modules <parser1> <parser2> ...))


cmly targets
============

Menhir supports writing the grammar and automaton to ``.cmly`` file. Therefore,
if this is flag is passed to menhir, dune will know to introduce a ``.cmly``
target for the module.

.. _menhir: https://gitlab.inria.fr/fpottier/menhir
