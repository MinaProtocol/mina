Transition to CMake
===================

In August 2017, several incompatible changes were merged into the libsnark `master` branch:

Transitioned to CMake
---------------------

We upgraded libsnark’s build process from a shell script and Makefile for installation and compilation to a new CMake-based process (https://cmake.org/). We are making this transition to better address the growing system-level and modularity needs of libsnark.

Factored out algebraic routines into new libraries
--------------------------------------------------

We have factored out core algebraic components of libsnark to allow developers to use internal classes and functions that are useful in applications beyond libsnark, as well as to simplify the growing directory structure of libsnark.

The two new libraries are:

* [libff](https://github.com/scipr-lab/libff) for finite fields and elliptic curves
* [libfqfft](https://github.com/scipr-lab/libfqfft) for fast polynomial evaluation and interpolation in various finite domains

These libraries are now automatically fetched and installed as Git submodules, in the “depends” (formerly: “third-party”) directory.

Monolithic version of libsnark is archived and unsupported
----------------------------------------------------------

As part of this transition, we will maintain a copy of the deprecated version under the `monolithic` branch. However, we will not support any future development work for the `monolithic` branch. Should a critical vulnerability be found in `monolithic`, we will patch it accordingly.

Transition Notes
----------------

See the [the Building section of README.md](./README.md#building) for the new build  instructions.

The compile flags are mostly analogous, but use different and more consistent notation (e.g.,  instead of `make OPTFLAGS=...` use `cmake -DOPT_FLAGS=... && make`. Notable changes: 

* Use `cmake -DCURVE=curvename ..` instead of the old `make CURVE=curvename`.
* Use `cmake -DLOWMEM=ON`/`OFF ..` instead of the old `make LOWMEM=1`/`0`. Similarly for `MULTICORE`, `MONTGOMERY_OUTPUT`, `USE_ASM`, `USE_MIXED_ADDITION` and `PERFORMANCE`. (The defaults are unchanged.)
* Binary output is now enabled by default; use `cmake -DBINARY_OUTPUT=OFF ..` to disable it for streaming-format compatibility with the old default.
* Use `cmake -DUSE_PT_COMPRESSION=OFF ..` instead of defining `NO_PT_COMPRESSION` (but the default is still to use point compression).
* Use `cmake -DWITH_PROCPS=OFF ..` instead of the old `make NO_PROCPS=1` flag (but the default is still to use procps). Similarly for `SUPERCOP`.
* Removed `NO_GTEST` (that was used to skip tests that use the Google Test library).
* The new `DEPENDS_DIR` flag customizes the dependencies installation directory.

Handling dependencies shared with submodules
--------------------------------------------

The following explains how we handles dependencies shared with submodules; you may need to understand this if you modify these submodules.

The `depends` folder (formerly `third-party`) includes libraries that libsnark depends on, such as libff and libfqfft. Observe that libfqfft also includes a `depends` folder that depends on libff. To prevent library duplication or versioning issues, we have made the dependency requirements explicit at each level. Namely, when fetching libsnark’s dependencies, we will only fetch and build top-level submodules. We will not recursively fetch submodules. This system of enforcing dependencies will ensure CMake can reliably compile dependencies as native code to libsnark, and prevent hidden, shared-library dependency files from arising.

The CMake compilation scripts include optional flags that pass state about the current calling parent to respective dependencies. This prevents CMake from unnecessarily recompiling dependencies and resetting state. We have built this system to ensure code duplication and library duplication do not arise as part of a developer’s workflow.

