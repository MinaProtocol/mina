********
Overview
********

Dune is a build system for OCaml and Reason. It is not intended as a
completely generic build system that is able to build any given project
in any language. On the contrary, it makes lots of choices in order to
encourage a consistent development style.

This scheme is inspired from the one used inside Jane Street and adapted
to the opam world. It has matured over a long time and is used daily by
hundred of developers, which means that it is highly tested and
productive.

When using dune, you give very little and high-level information to
the build system, which in turn takes care of all the low-level
details, from the compilation of your libraries, executables and
documentation, to the installation, setting up of tests, setting up of
the development tools such as merlin, etc.

In addition to the normal features one would expect from a build system
for OCaml, dune provides a few additional ones that detach it from
the crowd:

-  you never need to tell dune where things such as libraries are.
   Dune will always discover them automatically. In particular, this
   means that when you want to re-organize your project you need to do no
   more than rename your directories, dune will do the rest

-  things always work the same whether your dependencies are local or
   installed on the system. In particular, this means that you can always
   drop in the source for a dependency of your project in your working
   copy and dune will start using it immediately. This makes dune a
   great choice for multi-project development

-  cross-platform: as long as your code is portable, dune will be
   able to cross-compile it (note that dune is designed internally
   to make this easy but the actual support is not implemented yet)

-  release directly from any revision: dune needs no setup stage. To
   release your project, you can simply point to a specific tag. You can
   of course add some release steps if you want to, but it is not
   necessary

The first section of this document defines some terms used in the rest
of this manual. The second section specifies the dune metadata
format and the third one describes how to use the ``dune`` command.
