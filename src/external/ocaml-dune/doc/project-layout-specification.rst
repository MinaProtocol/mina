*****************************************
Project Layout and Metadata Specification
*****************************************

A typical dune project will have a ``dune-project`` and one or more
``<package>.opam`` file at toplevel as well as ``dune`` files wherever
interesting things are: libraries, executables, tests, documents to install,
etc...

It is recommended to organize your project so that you have exactly one library
per directory. You can have several executables in the same directory, as long
as they share the same build configuration. If you'd like to have multiple
executables with different configurations in the same directory, you will have
to make an explicit module list for every executable using ``modules``.

The next sections describe the format of dune metadata files.

Note that the dune metadata format is versioned in order to ensure forward
compatibility. There is currently only one version available, but to be future
proof, you should still specify it in your ``dune`` files. If no version is
specified, the latest one will be used.

.. _metadata-format:

Metadata format
===============

All configuration files read by Dune are using a syntax similar to the
one of S-expressions, which is very simple. The Dune language can
represent three kinds of values: atoms, strings and lists. By
combining these, it is possible to construct arbitrarily complex
project descriptions.

A Dune configuration file is a sequence of atoms, strings or lists
separated by spaces, newlines and comments. The other sections of this
manual describe how each configuration file is interpreted. We
describe below the syntax of the language.

Comments
--------

The Dune language only has end of line comments. End of line comments
are introduced with a semicolon and span up to the end of the end of
the current line. Everything from the semicolon to the end of the line
is ignored. For instance:

.. code::

   ; This is a comment

Atoms
-----

An atom is a non-empty contiguous sequences of character other than
special characters. Special characters are:

- spaces, horizontal tabs, newlines and form feed
- opening and closing parenthesis
- double quotes
- semicolons

For instance ``hello`` or ``+`` are valid atoms.

Note that backslashes inside atoms have no special meaning are always
interpreted as plain backslashes characters.

Strings
-------

A string is a sequence of characters surrounded by double quotes. A
string represent the exact text between the double quotes, except for
escape sequences. Escape sequence are introduced by the a backslash
character. Dune recognizes and interprets the following escape
sequences:

- ``\n`` to represent a newline character
- ``\r`` to represent a carriage return (character with ASCII code 13)
- ``\b`` to represent ASCII character 8
- ``\t`` to represent a horizontal tab
- ``\NNN``, a backslash followed by three decimal characters to
  represent the character with ASCII code ``NNN``
- ``\xHH``, a backslash followed by two hexadecimal characters to
  represent the character with ASCII code ``HH`` in hexadecimal
- ``\\``, a double backslash to represent a single backslash
- ``\%{`` to represent ``%{`` (see :ref:`variables-project`)

Additionally, a backslash that comes just before the end of the line
is used to skip the newline up to the next non-space character. For
instance the following two strings represent the same text:

.. code::

   "abcdef"
   "abc\
      def"

In most places where Dune expect a string, it will also accept an
atom. As a result it possible to write most Dune configuration file
using very few double quotes. This is very convenient in practice.

End of line strings
-------------------

End of line strings are another way to write strings. The are a
convenient way to write blocks of text inside a Dune file.

End of line strings are introduced by ``"\|`` or ``"\>`` and span up
the end of the current line. If the next line starts as well by
``"\|`` or ``"\>`` it is the continuation of the same string. For
readability, it is necessary that the text that follows the delimiter
is either empty or starts with a space that is ignored.

For instance:

.. code::

   "\| this is a block
   "\| of text

represent the same text as the string ``"this is a block\nof text"``.

Escape sequences are interpreted in text that follows ``"\|`` but not
in text that follows ``"\>``. Both delimiters can be mixed inside the
same block of text.

Lists
-----

Lists are sequences of values enclosed by parentheses. For instance
``(x y z)`` is a list containing the three atoms ``x``, ``y`` and
``z``. Lists can be empty, for instance: ``()``.

Lists can be nested, allowing to represent arbitrarily complex
descriptions. For instance:

.. code::

   (html
    (head (title "Hello world!"))
    (body
      This is a simple example of using S-expressions))

.. _variables-project:

Variables
---------

Dune allows variables in a few places. Their interpretation often
depend on the context in which they appear.

The syntax of variables is as follow:

.. code::

   %{var}

or, for more complex forms that take an argument:

.. code::

   %{fun:arg}

In order to write a plain ``%{``, you need to write ``\%{`` in a
string.

.. _opam-files:

dune-project files
==================

These files are used to mark the root of projects as well as define project-wide
parameters. These files are required to have a ``lang`` which controls the names
and contents of all configuration files read by Dune. The ``lang`` stanza looks
like:

.. code:: scheme

          (lang dune 1.0)

Additionally, they can contains the following stanzas.

name
----

Sets the name of the project:

.. code:: scheme

    (name <name>)

version
-------

Sets the version of the project:

.. code:: scheme

    (version <version>)

<package>.opam files
====================

When a ``<package>.opam`` file is present, dune will know that the
package named ``<package>`` exists. It will know how to construct a
``<package>.install`` file in the same directory to handle installation
via `opam <https://opam.ocaml.org/>`__. Dune also defines the
recursive ``install`` alias, which depends on all the buildable
``<package>.install`` files in the workspace. So for instance to build
everything that is installable in a workspace, run at the root:

::

    $ dune build @install

Declaring a package this way will allow you to add elements such as libraries,
executables, documentation, ... to your package by declaring them in ``dune``
files.

Such elements can only be declared in the scope defined by the
corresponding ``<package>.opam`` file. Typically, your
``<package>.opam`` files should be at the root of your project, since
this is where ``opam pin ...`` will look for them.

Note that ``<package>`` must be non-empty, so in particular ``.opam``
files are ignored.

.. _scopes:

Scopes
------

Any directory containing at least one ``<package>.opam`` file defines
a scope. This scope is the sub-tree starting from this directory,
excluding any other scopes rooted in sub-direcotries.

Typically, any given project will define a single scope. Libraries and
executables that are not meant to be installed will be visible inside
this scope only.

Because scopes are exclusive, if you wish to include the dependencies
of the project you are currently working on into your workspace, you
may copy them in a ``vendor`` directory, or any other name of your
choice. Dune will look for them there rather than in the installed
world and there will be no overlap between the various scopes.

Package version
---------------

Note that dune will try to determine the version number of packages
defined in the workspace. While dune itself makes no use of version
numbers, it can be use by external tools such as
`ocamlfind <http://projects.camlcity.org/projects/findlib.html>`__.

Dune determines the version of a package by trying the following
methods in order:

- it looks in the ``<package>.opam`` file for a ``version`` variable
- it looks for a ``<package>.version`` file in the same directory and
  reads the first line
- it looks for the version specified in the ``dune-project`` if present
- it looks for a ``version`` file and reads the first line
- it looks for a ``VERSION`` file and reads the first line

``<package>.version``, ``version`` and ``VERSION`` files may be
generated.

If the version can't be determined, dune just won't assign one.

Odig conventions
----------------

Dune follows the `odig <http://erratique.ch/software/odig>`__
conventions and automatically installs any README\*, CHANGE\*, HISTORY\*
and LICENSE\* files in the same directory as the ``<package>.opam`` file
to a location where odig will find them.

Note that this includes files present in the source tree as well as
generated files. So for instance a changelog generated by a user rule
will be automatically installed as well.

jbuild-ignore (deprecated)
==========================

``jbuild-ignore`` files are deprecated and replaced by
:ref:`dune-ignored_subdirs` stanzas in ``dune`` files.
