***********
Terminology
***********

-  **package**: a package is a set of libraries, executables, ... that
   are built and installed as one by opam

-  **project**: a project is a source tree, maybe containing one or more
   packages

-  **root**: the root is the directory from where dune can build
   things. Dune knows how to build targets that are descendents of
   the root. Anything outside of the tree starting from the root is
   considered part of the **installed world**. How the root is
   determined is explained in :ref:`finding-root`.

-  **workspace**: the workspace is the subtree starting from the root.
   It can contain any number of projects that will be built
   simultaneously by dune

-  **installed world**: anything outside of the workspace, that dune
   takes for granted and doesn't know how to build

-  **installation**: this is the action of copying build artifacts or
   other files from the ``<root>/_build`` directory to the installed
   world

-  **scope**: a scope determines where private items are
   visible. Private items include libraries or binaries that will not
   be installed. In dune, scopes are sub-trees rooted where at
   least one ``<package>.opam`` file is present. Moreover, scopes are
   exclusive. Typically, every project defines a single scope. See
   :ref:`scopes` for more details

-  **build context**: a build context is a subdirectory of the
   ``<root>/_build`` directory. It contains all the build artifacts of
   the workspace built against a specific configuration. Without
   specific configuration from the user, there is always a ``default``
   build context, which corresponds to the environment in which dune
   is executed. Build contexts can be specified by writing a
   :ref:`dune-workspace` file

-  **build context root**: the root of a build context named ``foo`` is
   ``<root>/_build/<foo>``

- **alias**: an alias is a build target that doesn't produce any file and has
   configurable dependencies. Aliases are per-directory. However, on the command
   line, asking for an alias to be built in a given directory will trigger the
   construction of the alias in all children directories recursively. Dune
   defines several :ref:`builtin-aliases`.

- **environment**: in dune, each directory has an environment
  attached to it. The environment determines the default values of
  various parameters, such as the compilation flags. Inside a scope,
  each directory inherit the environment from its parent. At the root
  of every scope, a default environment is used. At any point, the
  environment can be altered using an :ref:`dune-env` stanza.

- **build profile**: a global setting that influence various
  defaults. It can be set from the command line using ``--profile
  <profile>`` or from ``dune-workspace`` files. The following
  profiles are standard:

  -  ``release`` which is the profile used for opam releases
  -  ``dev`` which is the default profile when none is set explicitly, it
     has stricter warnings that the ``release`` one
