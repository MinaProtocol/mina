************
Configurator
************

Configurator is a small library designed to query features available on the
system, in order to generate configuration for dune builds. Such generated
configuration is usually in the form of command line flags, generated headers,
stubs, but there are no limitations on this.

Configurator allows you to query for the following features:

* Variables defined in ``ocamlc -config``,

* pkg-config_ flags for packages,

* Test features by compiling C code,

* Extract compile time information such as ``#define`` variables.

Configurator is designed to be cross compilation friendly and avoids _running_
any compiled code to extract any of the information above.

Configurator started as an `independent library
<https://github.com/janestreet/configurator>`__, but now lives in dune. You do
not need to install anything to use configurator.

Usage
=====

We'll describe configurator with a simple example. Everything else can be easily
learned by studying `configurator's API
<https://github.com/ocaml/dune/blob/master/src/configurator/v1.mli>`__.

To use configurator, we write an executable that will query the system using
configurator's API and output a set of targets reflecting the results. For
example:

.. code-block:: ocaml

  module C = Configurator.V1

  let clock_gettime_code = {|
  #include <time.h>

  int main()
  {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return 0;
  }
  |}

  let () =
    C.main ~name:"foo" (fun c ->
      let has_clock_gettime = C.c_test c clock_gettime_code ~link_flags:["-lrt"] in

      C.C_define.gen_header_file c ~fname:"config.h"
        [ "HAS_CKOCK_GETTIME", Switch has_ckock_gettime ]);

Usually, the module above would be named ``discover.ml``. The next step is to
invoke it as an executable and tell dune about the targets that it produces:

.. code-block:: lisp

  (executable
   (name discover)
   (libraries dune.configurator))

  (rule
   (targets config.h)
   (action (run ./discover.exe)))

Another common pattern is to produce a flags file with configurator and then use
this flag file using ``:include``:

.. code-block:: lisp

  (library
   (name mylib)
   (c_names foo)
   (c_library_flags (:include (flags.sexp))))

For this, generate the list of flags for your library — for example
using ``Configurator.V1.Pkg_config`` — and then write them to a file,
in the above example ``flags.sexp``, with
``Configurator.V1.write_flags "flags.sexp" flags``.

Upgrading from the old Configurator
===================================

The old configurator is the independent `configurator
<https://github.com/janestreet/configurator>`__ opam package. It is deprecated
and users are encouraged to migrate to dune's own configurator. The advantage of
the transition include:

* No extra dependencies,

* No need to manually pass ``-ocamlc`` flag,

* New configurator is cross compilation compatible.

The following steps must be taken to transition from the old configurator:

* Mentions of the ``configurator`` opam package should be removed.

* The library name ``configurator`` should be changed ``dune.configurator``.

* The ``-ocamlc`` flag in rules that run configurator scripts should be removed.
  This information is now passed automatically by dune.

* The new configurator API is versioned explicitly. The version that is
  compatible with old configurator is under the ``V1`` module. Hence, to
  transition one's code it's enough to add this module alias:

.. code-block:: ocaml

   module Configurator = Configurator.V1

.. _pkg-config: https://www.freedesktop.org/wiki/Software/pkg-config/
