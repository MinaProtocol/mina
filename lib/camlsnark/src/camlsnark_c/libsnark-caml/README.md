libsnark: a C++ library for zkSNARK proofs
================================================================================

--------------------------------------------------------------------------------
Authors and contacts
--------------------------------------------------------------------------------

The libsnark library is developed by the [SCIPR Lab] project and contributors
and is released under the MIT License (see the [LICENSE] file).

Copyright (c) 2012-2017 SCIPR Lab and contributors (see [AUTHORS] file).

For announcements and discussions, see the [libsnark mailing list](https://groups.google.com/forum/#!forum/libsnark).

--------------------------------------------------------------------------------
[TOC]

<!---
  NOTE: the file you are reading is in Markdown format, which is is fairly readable
  directly, but can be converted into an HTML file with much nicer formatting.
  To do so, run "make doc" (this requires the python-markdown package) and view
  the resulting file README.html. Alternatively, view the latest HTML version at
  https://github.com/scipr-lab/libsnark .
-->

--------------------------------------------------------------------------------
Overview
--------------------------------------------------------------------------------

This library implements __zkSNARK__ schemes, which are a cryptographic method
for proving/verifying, in zero knowledge, the integrity of computations.

A computation can be expressed as an NP statement, in forms such as the following:

- "The C program _foo_, when executed, returns exit code 0 if given the input _bar_ and some additional input _qux_."
- "The Boolean circuit _foo_ is satisfiable by some input _qux_."
- "The arithmetic circuit _foo_ accepts the partial assignment _bar_, when extended into some full assignment _qux_."
- "The set of constraints _foo_ is satisfiable by the partial assignment _bar_, when extended into some full assignment _qux_."

A prover who knows the witness for the NP statement (i.e., a satisfying input/assignment) can produce a short proof attesting to the truth of the NP statement. This proof can be verified by anyone, and offers the following properties.

-   __Zero knowledge:__
    the verifier learns nothing from the proof beside the truth of the statement (i.e., the value _qux_, in the above examples, remains secret).
-   __Succinctness:__
    the proof is short and easy to verify.
-   __Non-interactivity:__
    the proof is a string (i.e. it does not require back-and-forth interaction between the prover and the verifier).
-   __Soundness:__
    the proof is computationally sound (i.e., it is infeasible to fake a proof of a false NP statement). Such a proof system is also called an _argument_.
-   __Proof of knowledge:__
    the proof attests not just that the NP statement is true, but also that the
    prover knows why (e.g., knows a valid _qux_).

These properties are summarized by the _zkSNARK_ acronym, which stands for _Zero-Knowledge Succinct Non-interactive ARgument of Knowledge_ (though zkSNARKs are also knows as
_succinct non-interactive computationally-sound zero-knowledge proofs of knowledge_).
For formal definitions and theoretical discussions about these, see
\[BCCT12], \[BCIOP13], and the references therein.

The libsnark library currently provides a C++ implementation of:

1.  General-purpose proof systems:
    1. A preprocessing zkSNARK for the NP-complete language "R1CS"
       (_Rank-1 Constraint Systems_), which is a language that is similar to arithmetic
       circuit satisfiability.

       This zkSNARK construction follows, extends, and
       optimizes the approach described in \[BCTV14a], itself an extension of
       \[BCGTV13], following the approach of \[GGPR13] and \[BCIOP13]. (An alternative
       implementation of this approach is the _Pinocchio_ system of \[PGHR13].)
    2. A preprocessing SNARK for a language of arithmetic circuits, "BACS"
       (_Bilinear Arithmetic Circuit Satisfiability_). This simplifies the writing
       of NP statements when the additional flexibility of R1CS is not needed.
       Internally, it reduces to R1CS.
    3. A preprocessing SNARK for the language "USCS"
       (_Unitary-Square Constraint Systems_). This abstracts and implements the core
       contribution of \[DFGK14]
    4. A preprocessing SNARK for a language of Boolean circuits, "TBCS"
       (_Two-input Boolean Circuit Satisfiability_). Internally, it reduces to USCS.
       This is much more  efficient than going through R1CS.
    5. A simulation-extractable preprocessing SNARK for R1CS.
       This construction uses the approach described in \[GM17]. For arithmetic
       circuits, it is slower than the \[BCTV14a] approach, but produces shorter
       proofs.
    6. ADSNARK, a preprocessing SNARKs for proving statements on authenticated
       data, as described in \[BBFR15].
    7. Proof-Carrying Data (PCD). This uses recursive composition of SNARKs, as
       explained in \[BCCT13] and optimized in \[BCTV14b].
2.  Gadget libraries (gadgetlib1 and gadgetlib2) for constructing R1CS
    instances out of modular "gadget" classes.
3.  Examples of applications that use the above proof systems to prove
    statements about:
    1. Several toy examples.
    2. Execution of TinyRAM machine code, as explained in \[BCTV14a] and
       \[BCGTV13]. (Such machine code can be obtained, e.g., by compiling from C.)
       This is easily adapted to any other Random Access Machine that satisfies a
       simple load-store interface.
    3. A scalable for TinyRAM using Proof-Carrying Data, as explained in \[BCTV14b]
    4. Zero-knowldge cluster MapReduce, as explained in \[CTV15].

See the above references for discussions of efficiency aspects that arise in
practical use of such constructions, as well as security and trust
considerations.

This scheme is a _preprocessing zkSNARK_ (_ppzkSNARK_): before proofs can be
created and verified, one needs to first decide on a size/circuit/system
representing the NP statements to be proved, and run a _generator_ algorithm to
create corresponding public parameters (a long proving key and a short
verification key).

Using the library involves the following high-level steps:

1.  Express the statements to be proved as an R1CS (or any of the other
    languages above, such as arithmetic circuits, Boolean circuits, or TinyRAM).
    This is done by writing C++ code that constructs an R1CS, and linking this code
    together with libsnark
2.  Use libsnark's generator algorithm to create the public parameters for this
    statement (once and for all).
3.  Use libsnark's prover algorithm to create proofs of true statements about
    the satisfiability of the R1CS.
4.  Use libsnark's verifier algorithm to check proofs for alleged statements.


--------------------------------------------------------------------------------
The NP-complete language R1CS
--------------------------------------------------------------------------------

The ppzkSNARK supports proving/verifying membership in a specific NP-complete
language: R1CS (*rank-1 constraint systems*). An instance of the language is
specified by a set of equations over a prime field F, and each equation looks like:
                   < A, (1,X) > * < B , (1,X) > = < C, (1,X) >
where A,B,C are vectors over F, and X is a vector of variables.

In particular, arithmetic (as well as boolean) circuits are easily reducible to
this language by converting each gate into a rank-1 constraint. See \[BCGTV13]
Appendix E (and "System of Rank 1 Quadratic Equations") for more details about this.


--------------------------------------------------------------------------------
Elliptic curve choices
--------------------------------------------------------------------------------

The ppzkSNARK can be instantiated with different parameter choices, depending on
which elliptic curve is used. The [libff](https://github.com/scipr-lab/libff) library
currently provides three options:

* "edwards":
   an instantiation based on an Edwards curve, providing 80 bits of security.

* "bn128":
   an instantiation based on a Barreto-Naehrig curve, providing 128
   bits of security. The underlying curve implementation is
   \[ate-pairing], which has incorporated our patch that changes the
   BN curve to one suitable for SNARK applications.

    *   This implementation uses dynamically-generated machine code for the curve
        arithmetic. Some modern systems disallow execution of code on the heap, and
        will thus block this implementation.

        For example, on Fedora 20 at its default settings, you will get the error
        `zmInit ERR:can't protect` when running this code. To solve this,
        run `sudo setsebool -P allow_execheap 1` to allow execution,
        or use `make CURVE=ALT_BN128` instead.

* "alt_bn128":
   an alternative to "bn128", somewhat slower but avoids dynamic code generation.

Note that bn128 requires an x86-64 CPU while the other curve choices
should be architecture-independent; see [portability](#portability).


--------------------------------------------------------------------------------
Gadget libraries
--------------------------------------------------------------------------------

The libsnark library currently provides two libraries for conveniently constructing
R1CS instances out of reusable "gadgets". Both libraries provide a way to construct
gadgets on other gadgets as well as additional explicit equations. In this way,
complex R1CS instances can be built bottom up.

### gadgetlib1

This is a low-level library which expose all features of the preprocessing
zkSNARK for R1CS. Its design is based on templates (as does the ppzkSNARK code)
to efficiently support working on multiple elliptic curves simultaneously. This
library is used for most of the constraint-building in libsnark, both internal
(reductions and Proof-Carrying Data) and examples applications.

### gadgetlib2

This is an alternative library for constructing systems of polynomial equations
and, in particular, also R1CS instances. It is better documented and easier to
use than gadgetlib1, and its interface does not use templates. However, fewer
useful gadgets are provided.


--------------------------------------------------------------------------------
Security
--------------------------------------------------------------------------------

The theoretical security of the underlying mathematical constructions, and the
requisite assumptions, are analyzed in detailed in the aforementioned research
papers.

**
This code is a research-quality proof of concept, and has not
yet undergone extensive review or testing. It is thus not suitable,
as is, for use in critical or production systems.
**

Known issues include the following:

* The ppzkSNARK's generator and prover exhibit data-dependent running times
  and memory usage. These form timing and cache-contention side channels,
  which may be an issue in some applications.

* Randomness is retrieved from /dev/urandom, but this should be
  changed to a carefully considered (depending on system and threat
  model) external, high-quality randomness source when creating
  long-term proving/verification keys.


--------------------------------------------------------------------------------
Build instructions
--------------------------------------------------------------------------------

### Dependencies

The libsnark library relies on the following:

- C++ build environment
- CMake build infrastructure
- GMP for certain bit-integer arithmetic
- libprocps for reporting memory usage
- Fetched and compiled via Git submodules:
    - [libff](https://github.com/scipr-lab/libff) for finite fields and elliptic curves
    - [libfqfft](https://github.com/scipr-lab/libfqfft) for fast polynomial evaluation and interpolation in various finite domains
    - [Google Test](https://github.com/google/googletest) (GTest) for unit tests
    - [ate-pairing](https://github.com/herumi/ate-pairing) for the BN128 elliptic curve
    - [xbyak](https://github.com/herumi/xbyak) just-in-time assembler, for the BN128 elliptic curve
    - [Subset of SUPERCOP](https://github.com/mbbarbosa/libsnark-supercop) for crypto primitives needed by ADSNARK

So far we have tested these only on Linux, though we have been able to make the
libsnark work, with some features disabled (such as memory profiling or GTest tests),
on Windows via Cygwin and on Mac OS X. See also the notes on [portability](#portability)
below. (If you port libsnark to additional platforms, please let us know!)

Concretely, here are the requisite packages in some Linux distributions:

* On Ubuntu 16.04 LTS:

        $ sudo apt-get install build-essential cmake git libgmp3-dev libprocps4-dev python-markdown libboost-all-dev libssl-dev

* On Ubuntu 14.04 LTS:

        $ sudo apt-get install build-essential cmake git libgmp3-dev libprocps3-dev python-markdown libboost-all-dev libssl-dev

* On Fedora 21 through 23:

        $ sudo yum install gcc-c++ cmake make git gmp-devel procps-ng-devel python2-markdown

* On Fedora 20:

        $ sudo yum install gcc-c++ cmake make git gmp-devel procps-ng-devel python-markdown

### Building

Fetch dependencies from their GitHub repos:

    $ git submodule init && git submodule update

Create the Makefile:

    $ mkdir build && cd build && cmake ..

Then, to compile the library, tests, and profiling harness, run this within the `build directory:

    $ make

To create the HTML documentation, run

    $ make doc

and then view the resulting `README.html` (which contains the very text you are reading now).

To compile and run the tests for this library, run:

    $ make check

### Using libsnark as a library

To develop an application that uses libsnark, it's recommended to use your own build system that incorporates libsnark and dependencies. If you're using CMake, add libsnark as a git submodule, and then add it as a subdirectory. Then, add `snark` as a library dependency to the appropriate rules.

To build *and install* the libsnark library:

    $ DESTDIR=/install/path make install

This will install `libsnark.a` into `/install/path/lib`; so your application should be linked using `-L/install/path/lib -lsnark`. It also installs the requisite headers into `/install/path/include`; so your application should be compiled using `-I/install/path/include`.

In addition, unless you use `WITH_SUPERCOP=OFF`, `libsnark_adsnark.a` will be installed and should be linked in using `-lsnark_adsnark`.

When you use compile you application against `libsnark`, you must have the same conditional defines (`#define FOO` or `g++ -DFOO`) as when you compiled `libsnark`, due to the use of templates. One way to figure out the correct conditional defines is to look at `build/libsnark/CMakeFiles/snark.dir/flags.make` after running `cmake`. ([Issue #21](https://github.com/scipr-lab/libsnark/issues/21))

### Building on Windows using Cygwin

Install Cygwin using the graphical installer, including the `g++`, `libgmp`, `cmake`,
and `git` packages. Then disable the dependencies not easily supported under CygWin,
using:

    $ cmake -DWITH_PROCPS=OFF ..

### Building on Mac OS X

On Mac OS X, install GMP from MacPorts (`port install gmp`). Then disable the
dependencies not easily supported under OS X, using:

    $ cmake -DWITH_PROCPS=OFF ..

MacPorts does not write its libraries into standard system folders, so you
might need to explicitly provide the paths to the header files and libraries by
appending `CXXFLAGS=-I/opt/local/include LDFLAGS=-L/opt/local/lib` to the line
above.


--------------------------------------------------------------------------------
Build options
--------------------------------------------------------------------------------

The following flags change the behavior of the compiled code. Use

     $ cmake -Dname1=ON -Dname2=OFF ...

to control these (you can see the default at the top of CMakeLists.txt).

*   `cmake -DCURVE=choice` (where `choice` is one of: ALT_BN128, BN128, EDWARDS, MNT4, MNT6)

     Set the default curve to one of the above (see [elliptic curve choices](#elliptic-curve-choices)).

*   `cmake -DLOWMEM=ON`

     Limit the size of multi-exponentiation tables, for low-memory platforms.

*   `cmake -DWITH_PROCPS=OFF`

     Do not link against libprocps. This disables memory profiling.

*   `cmake -DWITH_SUPERCOP=OFF`

     Do not link against SUPERCOP for optimized crypto. The ADSNARK executables will not be built.

*   `cmake -DMULTICORE=ON`

     Enable parallelized execution of the ppzkSNARK generator and prover, using OpenMP.
     This will utilize all cores on the CPU for heavyweight parallelizabe operations such as
     FFT and multiexponentiation. The default is single-core.

     To override the maximum number of cores used, set the environment variable `OMP_NUM_THREADS`
     at runtime (not compile time), e.g., `OMP_NUM_THREADS=8 test_r1cs_sp_ppzkpc`. It defaults
     to the autodetected number of cores, but on some devices, dynamic core management confused
     OpenMP's autodetection, so setting `OMP_NUM_THREADS` is necessary for full utilization.

*   `cmake -DUSE_PT_COMPRESSION=OFF`

    Do not use point compression.
    This gives much faster serialization times, at the expense of ~2x larger
    sizes for serialized keys and proofs.

*   `cmake -DMONTGOMERY_OUTPUT=ON` (enabled by default)

    Serialize Fp elements as their Montgomery representations. If this
    option is disabled then Fp elements are serialized as their
    equivalence classes, which is slower but produces human-readable
    output.

*    `cmake -DBINARY_OUTPUT=ON` (enabled by default)

     In serialization, output raw binary data (instead of decimal), which is smaller and faster.

*   `cmake -DPROFILE_OP_COUNTS=ON`

    Collect counts for field and curve operations inside static variables
    of the corresponding algebraic objects. This option works for all
    curves except bn128.

*    `cmake -DUSE_ASM=ON` (enabled by default)

    Use architecture-specific assembly routines for F[p] arithmetic and heap in
    multi-exponentiation. (If disabled, use GMP's `mpn_*` routines instead.)

*   `cmake -DUSE_MIXED_ADDITION=ON`

    Convert each element of the proving key and verification key to
    affine coordinates. This allows using mixed addition formulas in
    multiexponentiation and results in slightly faster prover and
    verifier runtime at expense of increased generator runtime.

*   `cmake -DPERFORMANCE=ON`

    Enables compiler optimizations such as link-time optimization, and disables debugging aids.
    (On some distributions this causes a `plugin needed to handle lto object` link error and `undefined reference`s, which can be remedied by `AR=gcc-ar make ...`.)

*   `cmake -DOPT_FLAGS=...`

    Set the C++ compiler optimization flags, overriding the default (e.g., `-DOPT_FLAGS="-Os -march=i386"`).

*   `cmake -DDEPENDS_DIR=...`

    Sets the dependency installation directory to the provided absolute path (default: installs dependencies in the respective submodule directories)

Not all combinations are tested together or supported by every part of the codebase.


--------------------------------------------------------------------------------
Tutorials
--------------------------------------------------------------------------------

libsnark includes a tutorial, and some usage examples, for the high-level API.

* `libsnark/gadgetlib1/examples1` contains a simple example for constructing a
  constraint system using gadgetlib1.

* `libsnark/gadgetlib2/examples` contains a tutorial for using gadgetlib2 to express
  NP statements as constraint systems. It introduces basic terminology, design
  overview, and recommended programming style. It also shows how to invoke
  ppzkSNARKs on such constraint systems. The main file, `tutorial.cpp`, builds
  into a standalone executable.

* `libsnark/zk_proof_systems/ppzksnark/r1cs_ppzksnark/profiling/profile_r1cs_ppzksnark.cpp`
  constructs a simple constraint system and runs the ppzksnark. See below for how to
   run it.


--------------------------------------------------------------------------------
Executing profiling example
--------------------------------------------------------------------------------

The command

     $ libsnark/zk_proof_systems/ppzksnark/r1cs_ppzksnark/profiling/profile_r1cs_ppzksnark 1000 10 Fr

exercises the ppzkSNARK (first generator, then prover, then verifier) on an
R1CS instance with 1000 equations and an input consisting of 10 field elements.

(If you get the error `zmInit ERR:can't protect`, see the discussion
[above](#elliptic-curve-choices).)

The command

     $ libsnark/zk_proof_systems/ppzksnark/r1cs_ppzksnark/profiling/profile_r1cs_ppzksnark 1000 10 bytes

does the same but now the input consists of 10 bytes.


--------------------------------------------------------------------------------
Portability
--------------------------------------------------------------------------------

libsnark is written in fairly standard C++11.

However, having been developed on Linux on x86-64 CPUs, libsnark has some limitations
with respect to portability. Specifically:

1. libsnark's algebraic data structures assume little-endian byte order.

2. Profiling routines use `clock_gettime` and `readproc` calls, which are Linux-specific.

3. Random-number generation is done by reading from `/dev/urandom`, which is
   specific to Unix-like systems.

4. libsnark binary serialization routines (see `BINARY_OUTPUT` above) assume
   a fixed machine word size (i.e. sizeof(mp_limb_t) for GMP's limb data type).
   Objects serialized in binary on a 64-bit system cannot be de-serialized on
   a 32-bit system, and vice versa.
   (The decimal serialization routines have no such limitation.)

5. libsnark requires a C++ compiler with good C++11 support. It has been
   tested with g++ 4.7 and newer, and clang 3.4 and newer.

6. On x86-64, we by default use highly optimized assembly implementations for some
   operations (see `USE_ASM` above). On other architectures we fall back to a
   portable C++ implementation, which is slower.

7. The ate-pairing library, require by the BN128 curve, can be compiled only on i686 and x86-64. (On other platforms, use other `-DCURVE=...` choices.)

8. The SUPERCOP library, required by ADSNARK, can be compiled only on i686 and x86-64. (On other platforms, use `-DWITH_SUPERCOP=OFF`.)

Tested configurations include:

* Debian jessie with g++ 4.7 on x86-64
* Debian jessie with clang 3.4 on x86-64
* Fedora 20/21 with g++ 4.8.2/4.9.2 on x86-64
* Fedora 21 with g++ 4.9.2 on x86-32, for non-BN128 curves (`-DWITH_SUPERCOP=OFF`)
* Ubuntu 14.04 LTS with g++ 4.8 on x86-64
* Ubuntu 14.04 LTS with g++ 4.8 on x86-32, for non-BN128 curves (`-DWITH_SUPERCOP=OFF`)
* Ubuntu 15.04/16.04 LTS with g++ 4.9.2/5.3.1 on ARM AArch32/AArch64, for non-BN128 curve choices
* Debian wheezy with g++ 4.7 on ARM little endian (Debian armel port) inside QEMU, for EDWARDS and ALT_BN128 curve choices
* Windows 7 with g++ 4.8.3 under Cygwin 1.7.30 on x86-64 for EDWARDS and ALT_BN128 curve choices (`-DWITH_PROCPS=OFF` and GTestdisabled)
* Mac OS X 10.9.4 (Mavericks) with Apple LLVM version 5.1 (based on LLVM 3.4svn) on x86-64 (`-DWITH_PROCPS=OFF` and GTest disabled)


--------------------------------------------------------------------------------
Directory structure
--------------------------------------------------------------------------------

The directory structure of the libsnark library is as follows:

* [__libsnark__](libsnark): main C++ source code, containing the following modules:
    * [__common__](libsnark/common): miscellaneous utilities
    * [__gadgetlib1__](libsnark/gadgetlib1): gadgetlib1, a library to construct R1CS instances
        * [__gadgets__](libsnark/gadgetlib1/gadgets): basic gadgets for gadgetlib1
    * [__gadgetlib2__](libsnark/gadgetlib2): gadgetlib2, a library to construct R1CS instances
    * [__relations__](libsnark/relations): interfaces for expressing statement (relations between instances and witnesses) as various NP-complete languages
        * [__constraint_satisfaction_problems__](libsnark/relations/constraint_satisfaction_problems): R1CS and USCS languages
        * [__circuit_satisfaction_problems__](libsnark/relations/circuit_satisfaction_problems):  Boolean and arithmetic circuit satisfiability languages
        * [__ram_computations__](libsnark/relations/ram_computations): RAM computation languages
    * [__zk_proof_systems__](libsnark/zk_proof_systems): interfaces and implementations of the proof systems
    * [__reductions__](libsnark/reductions): reductions between languages (used internally, but contains many examples of building constraints)
* [__depends__](libsnark/depends): external dependencies which are automatically fetched and compiled (overridable by `cmake -DDEPENDS_DIR=...`)

Some of these module directories have the following subdirectories:

* ...
    * [__examples__](): example code and tutorials for this module
    * [__tests__](): unit tests for this module

In particular, the top-level API examples are at `libsnark/r1cs_ppzksnark/examples/` and `libsnark/gadgetlib2/examples/`.


--------------------------------------------------------------------------------
Further considerations
--------------------------------------------------------------------------------

### Multiexponentiation window size

The ppzkSNARK's generator has to solve a fixed-base multi-exponentiation
problem.  We use a window-based method in which the optimal window size depends
on the size of the multiexponentiation instance *and* the platform.

On our benchmarking platform (a 3.40 GHz Intel Core i7-4770 CPU), we have
computed for each curve optimal windows, provided as
`fixed_base_exp_window_table` initialization sequences, for each curve; see
`X_init.cpp` for X=edwards,bn128,alt_bn128.

Performance on other platforms may not be optimal (but probably not be far off).
Future releases of the libsnark library will include a tool that generates
optimal window sizes.


--------------------------------------------------------------------------------
References
--------------------------------------------------------------------------------

\[BBFR15] [
  _ADSNARK: nearly practical and privacy-preserving proofs on authenticated data_
](https://eprint.iacr.org/2014/617),
  Michael Backes, Manuel Barbosa, Dario Fiore, Raphael M. Reischuk,
  IEEE Symposium on Security and Privacy (Oakland) 2015

\[BCCT12] [
  _From extractable collision resistance to succinct non-Interactive arguments of knowledge, and back again_
](http://eprint.iacr.org/2011/443),
  Nir Bitansky, Ran Canetti, Alessandro Chiesa, Eran Tromer,
  Innovations in Computer Science (ITCS) 2012

\[BCCT13] [
  _Recursive composition and bootstrapping for SNARKs and proof-carrying data_
](http://eprint.iacr.org/2012/095)
  Nir Bitansky, Ran Canetti, Alessandro Chiesa, Eran Tromer,
  Symposium on Theory of Computing (STOC) 13

\[BCGTV13] [
  _SNARKs for C: Verifying Program Executions Succinctly and in Zero Knowledge_
](http://eprint.iacr.org/2013/507),
  Eli Ben-Sasson, Alessandro Chiesa, Daniel Genkin, Eran Tromer, Madars Virza,
  CRYPTO 2013

\[BCIOP13] [
  _Succinct non-interactive arguments via linear interactive Proofs_
](http://eprint.iacr.org/2012/718),
  Nir Bitansky, Alessandro Chiesa, Yuval Ishai, Rafail Ostrovsky, Omer Paneth,
  Theory of Cryptography Conference 2013

\[BCTV14a] [
  _Succinct non-interactive zero knowledge for a von Neumann architecture_
](http://eprint.iacr.org/2013/879),
  Eli Ben-Sasson, Alessandro Chiesa, Eran Tromer, Madars Virza,
  USENIX Security 2014

\[BCTV14b] [
  _Scalable succinct non-interactive arguments via cycles of elliptic curves_
](https://eprint.iacr.org/2014/595),
  Eli Ben-Sasson, Alessandro Chiesa, Eran Tromer, Madars Virza,
  CRYPTO 2014

\[CTV15] [
  _Cluster computing in zero knowledge_
](https://eprint.iacr.org/2015/377),
  Alessandro Chiesa, Eran Tromer, Madars Virza,
  Eurocrypt 2015

\[DFGK14] [
  Square span programs with applications to succinct NIZK arguments
](https://eprint.iacr.org/2014/718),
  George Danezis, Cedric Fournet, Jens Groth, Markulf Kohlweiss,
  ASIACCS 2014

\[GM17] [
  Snarky Signatures: Minimal Signatures of Knowledge from Simulation-Extractable
  SNARKs
](https://eprint.iacr.org/2017/540),
  Jens Groth and Mary Maller,
  IACR-CRYPTO-2017

\[GGPR13] [
  _Quadratic span programs and succinct NIZKs without PCPs_
](http://eprint.iacr.org/2012/215),
  Rosario Gennaro, Craig Gentry, Bryan Parno, Mariana Raykova,
  EUROCRYPT 2013

\[ate-pairing] [
  _High-Speed Software Implementation of the Optimal Ate Pairing over Barreto-Naehrig Curves_
](https://github.com/herumi/ate-pairing),
  MITSUNARI Shigeo, TERUYA Tadanori

\[PGHR13] [
  _Pinocchio: Nearly Practical Verifiable Computation_
](http://eprint.iacr.org/2013/279),
  Bryan Parno, Craig Gentry, Jon Howell, Mariana Raykova,
  IEEE Symposium on Security and Privacy (Oakland) 2013

[SCIPR Lab]: http://www.scipr-lab.org/ (Succinct Computational Integrity and Privacy Research Lab)

[LICENSE]: LICENSE (LICENSE file in top directory of libsnark distribution)

[AUTHORS]: AUTHORS (AUTHORS file in top directory of libsnark distribution)
