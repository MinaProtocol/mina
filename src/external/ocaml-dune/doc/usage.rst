*****
Usage
*****

This section describe usage of dune from the shell.

.. _finding-root:

Finding the root
================

.. _dune-workspace:

dune-workspace
--------------

The root of the current workspace is determined by looking up a
``dune-workspace`` or ``dune-project`` file in the current directory
and parent directories.

``dune`` prints out the root when starting if it is not the current
directory:

.. code:: bash

    $ dune runtest
    Entering directory '/home/jdimino/code/dune'
    ...

More precisely, it will choose the outermost ancestor directory containing a
``dune-workspace`` file as root. For instance if you are in
``/home/me/code/myproject/src``, then dune will look for all these files in
order:

-  ``/dune-workspace``
-  ``/home/dune-workspace``
-  ``/home/me/dune-workspace``
-  ``/home/me/code/dune-workspace``
-  ``/home/me/code/myproject/dune-workspace``
-  ``/home/me/code/myproject/src/dune-workspace``

The first entry to match in this list will determine the root. In
practice this means that if you nest your workspaces, dune will
always use the outermost one.

In addition to determining the root, ``dune`` will read this file as
to setup the configuration of the workspace unless the ``--workspace``
command line option is used. See the section `Workspace
configuration`_ for the syntax of this file.

Current directory
-----------------

If the previous rule doesn't apply, i.e. no ancestor directory has a
file named ``dune-workspace``, then the current directory will be used
as root.

Forcing the root (for scripts)
------------------------------

You can pass the ``--root`` option to ``dune`` to select the root
explicitly. This option is intended for scripts to disable the automatic lookup.

Note that when using the ``--root`` option, targets given on the command line
will be interpreted relative to the given root, not relative to the current
directory as this is normally the case.

Interpretation of targets
=========================

This section describes how ``dune`` interprets the targets given on
the command line. When no targets are specified, ``dune`` builds the
``default`` alias, see :ref:`default-alias` for more details.

Resolution
----------

All targets that dune knows how to build live in the ``_build``
directory.  Although, some are sometimes copied to the source tree for
the need of external tools. These includes:

- ``.merlin`` files

- ``<package>.install`` files

As a result, if you want to ask ``dune`` to produce a particular ``.exe``
file you would have to type:

.. code:: bash

    $ dune build _build/default/bin/prog.exe

However, for convenience when a target on the command line doesn't
start with ``_build``, ``dune`` will expand it to the
corresponding target in all the build contexts where it knows how to
build it. When using ``--verbose``, It prints out the actual set of
targets when starting:

.. code:: bash

    $ dune build bin/prog.exe --verbose
    ...
    Actual targets:
    - _build/default/bin/prog.exe
    - _build/4.03.0/bin/prog.exe
    - _build/4.04.0/bin/prog.exe

Aliases
-------

Targets starting with a ``@`` are interpreted as aliases. For instance
``@src/runtest`` means the alias ``runtest`` in all descendant of
``src`` in all build contexts where it is defined. If you want to
refer to a target starting with a ``@``, simply write: ``./@foo``.

To build and run the tests for a particular build context, use
``@_build/default/runtest`` instead.

So for instance:

-  ``dune build @_build/foo/runtest`` will run the tests only for
   the ``foo`` build context
-  ``dune build @runtest`` will run the tests for all build contexts

You can also build an alias non-recursively by using ``@@`` instead of
``@``. For instance to run tests only from the current directory:

.. code::

   dune build @@runtest

.. _default-alias:

Default alias
-------------

When no targets are given to ``dune build``, it builds the special
``default`` alias. Effectively ``dune build`` is equivalent to:

.. code::

   dune build @@default

When a directory doesn't explicitly define what the ``default`` alias
means via an :ref:`alias-stanza` stanza, the following implicit
definition is assumed:

.. code::

   (alias
    (name default)
    (deps (alias_rec install)))

Which means that by default ``dune build`` will build everything that
is installable.

When using a directory as a target, it will be interpreted as building the
default target in the directory. The directory must exist in the source tree.

.. code::

   dune build dir

Is equivalent to:

.. code::

   dune build @@dir/default

.. _builtin-aliases:

Built-in Aliases
----------------

There's a few aliases that dune automatically creates for the user

* ``default`` - this alias includes all the targets that dune will build if a
  target isn't specified, i.e. ``$ dune build``. By default, this is set to the
  ``install`` alias.

* ``runtest`` - this is the alias to run al the tests, building them if
  necessary.

* ``install`` - build all public artifacts - those that will be installed.

* ``doc`` - build documentation for public libraries.

* ``doc-private`` - build documentation for all libraries - public & private.

* ``lint`` - run linting tools.

* ``all`` - build all available targets in a directory and installable artifacts
  defined in that directory.

* ``check`` - This alias will build the minimal set of targets required for
  tooling support. Essentially, this is ``.cmi``, ``.cmt``, ``.cmti``, and
  .merlin files.

Finding external libraries
==========================

When a library is not available in the workspace, dune will look it
up in the installed world, and expect it to be already compiled.

It looks up external libraries using a specific list of search paths. A
list of search paths is specific to a given build context and is
determined as follow:

#. if the ``ocamlfind`` is present in the ``PATH`` of the context, use each line
   in the output of ``ocamlfind printconf path`` as a search path
#. otherwise, if ``opam`` is present in the ``PATH``, use the outout of ``opam
   config var lib``
#. otherwise, take the directory where ``ocamlc`` was found, and append
   ``../lib`` to it. For instance if ``ocamlc`` is found in ``/usr/bin``, use
   ``/usr/lib``

.. _running-tests:

Running tests
=============

There are two ways to run tests:

-  ``dune build @runtest``
-  ``dune runtest``

The two commands are equivalent. They will run all the tests defined in the
current directory and its children recursively. You can also run the tests in a
specific sub-directory and its children by using:

-  ``dune build @foo/bar/runtest``
-  ``dune runtest foo/bar``

Watch mode
==========

The ``dune build`` and ``dune runtest`` commands support a ``-w`` (or
``--watch``) flag. When it is passed, dune will perform the action as usual, and
then wait for file changes and rebuild (or rerun the tests). This feature
requires ``inotifywait`` or ``fswatch`` to be installed.

Launching the Toplevel (REPL)
=============================

Dune supports launching a `utop <https://github.com/diml/utop>`__ instance
with locally defined libraries loaded.

.. code:: bash

   $ dune utop <dir> -- <args>

Where ``<dir>`` is a directory under which dune will search (recursively) for
all libraries that will be loaded. ``<args>`` will be passed as arguments to the
utop command itself. For example, ``dune utop lib -- -implicit-bindings`` will
start ``utop`` with the libraries defined in ``lib`` and implicit bindings for
toplevel expressions.

Requirements & Limitations
--------------------------

* utop version >= 2.0 is required for this to work.
* This subcommand only supports loading libraries. Executables aren't supported.
* Libraries that are dependencies of utop itself cannot be loaded. For example
  `Camomile <https://github.com/yoriyuki/Camomile>`__.
* Loading libraries that are defined in different directories into one utop
  instance isn't possible.

Restricting the set of packages
===============================

You can restrict the set of packages from your workspace that dune can see with
the ``--only-packages`` option:

.. code:: bash

    $ dune build --only-packages pkg1,pkg2,... @install

This option acts as if you went through all the dune files and
commented out the stanzas refering to a package that is not in the list
given to ``dune``.

Invocation from opam
====================

You should set the ``build:`` field of your ``<package>.opam`` file as
follows:

::

    build: [
      ["dune" "subst"] {pinned}
      ["dune" "build" "-p" name "-j" jobs]
    ]

``-p pkg`` is a shorthand for ``--root . --only-packages pkg --profile
release --default-target @install``. ``-p`` is the short version of
``--for-release-of-packages``.

This has the following effects:

-  it tells dune to build everything that is installable and to
   ignore packages other than ``name`` defined in your project
-  it sets the root to prevent dune from looking it up
-  it silently ignores all rules with ``(mode promote)``
-  it sets the build profile to ``release``
-  it uses whatever concurrency option opam provides
-  it sets the default target to ``@install`` rather than ``@@default``

Note that ``name`` and ``jobs`` are variables expanded by opam. ``name`` expands
to the package name and ``jobs`` to the number of jobs available to build the
package.

Tests
=====

To setup the building and running of tests in opam, add this line to your
``<package>.opam`` file:

::

    build-test: [["dune" "runtest" "-p" name "-j" jobs]]

Installation
============

Installing a package means copying the build artifacts from the build directory
to the installed word.

When installing via opam, you don't need to worry about this step: dune
generates a ``<package>.install`` file that opam will automatically read to
handle installation.

However, when not using opam or doing local development, you can use dune to
install the artifacts by hands. To do that, use the ``install`` command:

::

    $ dune install [PACKAGE]...

without an argument, it will install all the packages available in the
workspace. With a specific list of packages, it will only install these
packages. If several build contexts are configured, the installation will be
performed for all of them.

Destination
-----------

The place where the build artifacts are copied, usually referred as **prefix**,
is determined as follow for a given build context:

#. if an explicit ``--prefix <path>`` argument is passed, use this path
#. if ``opam`` is present in the ``PATH`` and is configured, use the
   output of ``opam config var prefix``
#. otherwise, take the parent of the directory where ``ocamlc`` was found.

As an exception to this rule, library files might be copied to a different
location. The reason for this is that they often need to be copied to a
particular location for the various build system used in OCaml projects to find
them and this location might be different from ``<prefix>/lib`` on some systems.

Historically, the location where to store OCaml library files was configured
through `findlib <http://projects.camlcity.org/projects/findlib.html>`__ and the
``ocamlfind`` command line tool was used to both install these files and locate
them. Many Linux distributions or other packaging systems are using this
mechanism to setup where OCaml library files should be copied.

As a result, if none of ``--libdir`` and ``--prefix`` is passed to ``dune
install`` and ``ocamlfind`` is present in the ``PATH``, then library files will
be copied to the directory reported by ``ocamlfind printconf destdir``. This
ensures that ``dune install`` can be used without opam. When using opam,
``ocamlfind`` is configured to point to the opam directory, so this rule makes
no difference.

Note that ``--prefix`` and ``--libdir`` are only supported if a single build
context is in use.

Workspace configuration
=======================

By default, a workspace has only one build context named ``default`` which
correspond to the environment in which ``dune`` is run. You can define more
contexts by writing a ``dune-workspace`` file.

You can point ``dune`` to an explicit ``dune-workspace`` file with the
``--workspace`` option. For instance it is good practice to write a
``dune-workspace.dev`` in your project with all the version of OCaml your
projects support. This way developers can tests that the code builds with all
version of OCaml by simply running:

.. code:: bash

    $ dune build --workspace dune-workspace.dev @all @runtest

dune-workspace
--------------

The ``dune-workspace`` file uses the S-expression syntax. This is what
a typical ``dune-workspace`` file looks like:

.. code:: scheme

    (lang dune 1.0)
    (context (opam (switch 4.02.3)))
    (context (opam (switch 4.03.0)))
    (context (opam (switch 4.04.0)))

The rest of this section describe the stanzas available.

Note that an empty ``dune-workspace`` file is interpreted the same as one
containing exactly:

.. code:: scheme

    (lang dune 1.0)
    (context default)

This allows you to use an empty ``dune-workspace`` file to mark the root of your
project.

profile
~~~~~~~

The build profile can be selected in the ``dune-workspace`` file by write a
``(profile ...)`` stanza. For instance:

.. code:: scheme

    (profile release)

Note that the command line option ``--profile`` has precedence over this stanza.

env
~~~

The ``env`` stanza can be used to set the base environment for all contexts in
this workspace. This environment has the lowest precedence of all other ``env``
stanzas. The syntax for this stanza is the same dune's :ref:`dune-env` stanza.

context
~~~~~~~

The ``(context ...)`` stanza declares a build context. The argument
can be either ``default`` or ``(default)`` for the default build
context or can be the description of an opam switch, as follows:

.. code:: scheme

    (context (opam (switch <opam-switch-name>)
                   <optional-fields>))

``<optional-fields>`` are:

-  ``(name <name>)`` is the name of the subdirectory of ``_build``
   where the artifacts for this build context will be stored

-  ``(root <opam-root>)`` is the opam root. By default it will take
   the opam root defined by the environment in which ``dune`` is
   run which is usually ``~/.opam``

- ``(merlin)`` instructs dune to use this build context for
  merlin

- ``(profile <profile>)`` to set a different profile for a build
  context. This has precedence over the command line option
  ``--profile``

- ``(env <env>)`` to set the environment for a particular context. This is of
  higher precedence than the toplevel ``env`` stanza in the workspace file. This
  field the same options as the :ref:`dune-env` stanza.

- ``(toolchain <findlib_coolchain>)`` set findlib toolchain for the context.

Both ``(default ...)`` and ``(opam ...)`` accept a ``targets`` field in order to
setup cross compilation. See :ref:`advanced-cross-compilation` for more
information.

Merlin reads compilation artifacts and it can only read the compilation
artifacts of a single context. Usually, you should use the artifacts from the
``default`` context, and if you have the ``(context default)`` stanza in your
``dune-workspace`` file, that is the one dune will use.

For rare cases where this is not what you want, you can force dune to use a
different build contexts for merlin by adding the field ``(merlin)`` to this
context.

Distributing Projects
=====================

Dune provides support for building and installing your project. However it
doesn't provide helpers for distributing it. It is recommended to use
`dune-release <https://github.com/samoht/dune-release>`__ for this purpose.

The common defaults are that your projects include the following files:

- ``README.md``
- ``CHANGES.md``
- ``LICENSE.md``

And that if your project contains several packages, then all the package names
must be prefixed by the shortest one.

Watermarking
============

One of the feature dune-release provides is watermarking; it replaces
various strings of the form ``%%ID%%`` in all files of your project
before creating a release tarball or when the package is pinned by the
user using opam.

This is especially interesting for the ``VERSION`` watermark, which gets
replaced by the version obtained from the vcs. For instance if you are using
git, dune-release invokes this command to find out the version:

.. code:: bash

    $ git describe --always --dirty
    1.0+beta9-79-g29e9b37

Projects using dune usually only need dune-release for creating and
publishing releases. However they might still want to substitute the
watermarks when the package is pinned by the user. To help with this,
dune provides the ``subst`` sub-command.

dune subst
==========

``dune subst`` performs the same substitution ``dune-release`` does
with the default configuration. i.e. calling ``dune subst`` at the
root of your project will rewrite in place all the files in your
project.

More precisely, it replaces all the following watermarks in source files:

- ``NAME``, the name of the project
- ``VERSION``, output of ``git describe --always --dirty``
- ``VERSION_NUM``, same as ``VERSION`` but with a potential leading
  ``v`` or ``V`` dropped
- ``VCS_COMMIT_ID``, commit hash from the vcs
- ``PKG_MAINTAINER``, contents of the ``maintainer`` field from the
  opam file
- ``PKG_AUTHORS``, contents of the ``authors`` field from the opam file
- ``PKG_HOMEPAGE``, contents of the ``homepage`` field from the opam file
- ``PKG_ISSUES``, contents of the ``issues`` field from the opam file
- ``PKG_DOC``, contents of the ``doc`` field from the opam file
- ``PKG_LICENSE``, contents of the ``license`` field from the opam file
- ``PKG_REPO``, contents of the ``repo`` field from the opam file

The name of the project is obtained by reading the ``dune-project``
file in the directory where ``dune subst`` is called. The
``dune-project`` file must exist and contain a valid ``(name ...)``
field.

Note that ``dune subst`` is meant to be called from the opam file and
in particular behaves a bit different to other ``dune`` commands. In
particular it doesn't try to detect the root of the workspace and must
be called from the root of the project.

Custom Build Directory
======================

By default dune places all build artifacts in the ``_build`` directory relative
to the user's workspace. However, one can customize this directory by using the
``--build-dir`` flag or the ``DUNE_BUILD_DIR`` environment variable.

.. code:: bash

   $ dune build --build-dir _build-foo

   # this is equivalent to:
   $ DUNE_BUILD_DIR=_build-foo dune build

   # Absolute paths are also allowed
   $ dune build --build-dir /tmp/build foo.exe
