# Bazelizing Coda
[summary]: #summary
by Gregg Reynolds.

Summary: add support for Bazel build system.

## Motivation
[motivation]: #motivation

The current build system is complex and unreliable.  It does not work
"out-of-the-box", at least not on the Mac.  It involves multiple build
tools and languages:

- Make
- CMake
- Dune
- Nix
- lots of Shell scripts

It also involves multiple package managers:

- apt-get
- homebrew
- opam
- others?

The proposal here is to replace all this (to the extent possible) with
Bazel.  The expected result is a build system that:

- "just works" on all officially supported platforms ("just works" and officially supported platforms to be specified).
- supports cross-platform builds
- enables remote caching of (sharable) build artifacts
- enables remote execution of build processes
- is easily maintainable
- affords a smooth transition path from the current situation - Bazel
  support will not interfere with existing code, and may be introduced
  piecemeal
- integrates well with current practice, e.g. continuous integration,
  quality assurance, etc.

### Terminology

**Platform**: an execution environment. Usually synonymous with
"machine", i.e. HW architecture plus OS, but in the context of Bazel a
platform may include e.g. a toolchain.  For example, a machine with
multiple toolchains installed may satisfy multiple platform
specifications.

**Host**:
- **Bazel host**, **orchestration host**: the host on which Bazel runs,
  orchestrating the build.
- **Build host**, **construction host**: the host on which the build tools
  proper (compiler, linker, etc.) run, constructing the output.
- **Target host**: the host for which output is constructed.

**Build type**:
- **Local builds**: the same machine plays all three host roles. This is
  the most common situation.
- **Distributed builds**: Bazel supports remote execution, so
  orchestration and construction could run on different
  machines/platforms, targeting yet a third machine/platform. This
  does not necessarily imply different platforms; the machines could
  be identical, except that the construction machine might faster,
  have more RAM, etc.
- **Mono-builds**: for lack of a better term. Same platform for all three
  host roles.  A "native" build is a local mono-build.
- **Cross-platform builds**: a/k/a "cross builds". The Target host
  platform is different than the Bazel and Build host platforms.  A
  cross-platform build could be either local or distributed.
- **Canadian builds**: all three hosts are distinct platforms.  E.g. you
  run Bazel on a mac, orchstrating build tools that run on a remote
  linux machine, targeting Windows.

### "Just works"

The sense of "just works" is clear enough intuitively, but exactly
what things/tasks should "just work" is a policy matter. For example,
native builds clearly must just work, but which platforms should be
supported is a policy decision. Should Windows native builds just
work? If so, should the Cygwin toolchain be supported?  And so forth.

What counts as just working in general:

- Default local mono-builds ("native" builds) succeed on all supported
  platforms; i.e. running build without passing any options by command
  line or config file. Default settings just work, but may not be
  optimal in every case.
- Build refinements are easy and just work.  It must be easy for the
  developer to express desired properties, and the ensuing build
  configuration must succeed.  For example, optimization or debugging
  flags.
- Supported cross-platform builds must be easily expressible.  For example, it
  should be possible to target Android by something like `$ bazel
  build --platform=android_armv7`.
- Configuration settings must be easily expressible either by command
  line or via a config file (`.bazelrc`, `--bazelrc=file`).

#### Integrated testing

Bazel has builtin support for test targets.

#### Remote caching and execution

Bazel supports both of these, but they are outside the scope of this
proposal.  Adding Bazel support would enable them.

#### Continuous Integration support

I have no experience with CI systems or processes, but Bazel claims to
  have good support; e.g. see [Using Bazel in a continuous integration
  system](https://blog.bazel.build/2016/01/27/continuous-integration.html)
  and [Remote
  cache](https://github.com/angular/angular/blob/master/docs/BAZEL.md#remote-cache).

#### Maintainability and Extensibility

It must be easy to maintain the build sytem.

It should be easy to extend the system - for example, to add another
target platform, toolchain, etc.  In particular, it should be easy to
introduce new build tools.

## Detailed design
[detailed-design]: #detailed-design

Platform support:
  * Linux - required, I presume
  * MacOS - my development environment
  * Windows - this is a policy decision.  I can design for
    portability, but I do not have a Windows machine so I cannot test
    Windows support.  I do have a copy of Parallels, so if somebody
    can provide me with a licensed copy of Windows I can support it.

### Tasks

General:
* Minimal build (local monobuild).
  * WORKSPACE file, BUILD.bazel files containing target specifications, .bzl files containing macros, global vars, custom rules, etc.
  * `$ bazel build //pkg:target` completes successfully for each target
  * MacOS first, then Linux, then Windows.
* Adaptive builds (local monobuilds with platform-specific adaptations).
  * A Bazel `platform()` is defined for each officially supported platform
    * Platform definition includes architecture, OS, toolchain.
  * Build specifications are adapted to each supported platform
    * For example, the compilers for different platforms take
      different options.  Bazel does a good job of automatically
      setting the compile command for each platform, but in some cases
      additional options should or must be specified.
  * Bazel does not have `./configure` functionality; it cannot detect
    environment features, at least not out of the box.  Such
    functionality could be implemented in Bazel's Starlark language,
    but that is outside the scope of this proposal.  In the meantime,
    Bazel works well with `./configure`; if we need feature detection
    (e.g. to support all three major platforms), a configure script
    can be written to do this, just as in the case of a Make-based
    system.
* Toolchains.
  * Bazel detects and uses a standard set of commonly used toolchains; no effort required.
  * For toolchains not covered by Bazel out of the box, as well as for
    cross-build toolchains, a set of rules defining the toolchain for
    Bazel must be developed.
    * A .bzl file containing code describing the location of tools, API, features, etc.
    * To make the defined toolchain known to Bazel, a BUILD file
      containing rules associating the toolchain with build properties, thus enabling build-time toolchain resolution

Specific tasks:
* C/C++
  * External libs. Most of these are already bazelized (minimal build on MacOS).
    * jemalloc, libffi, libgmp, libomp, libpatch, libpq, libprocps, libre2, libsodium, openssl, zlib
  * libsnark.
    * A special case.  Coda uses a modified fork of libsnark; it
      depends on a handful of C/C++ libs (libff, libfqfft, etc.).
    * I have forked the dependencies on github and added Bazel support
      to each (about 90% complete).  The ideal is to get the
      maintainers to accept the Bazel-enabling patches.
    * For Coda this approach may or may not be desirable.  The
      alternative is to use the same standard approach as used by the
      other external libs, namely an external BUILD file.
  * Internal C/C++ code.  The Code codebase contains some OCaml code
    that generates C/C++ code which it then compiles.  The task is to
    convert this to C/C++ code and let Bazel handle any customizations
    needed.
  * CUDA.  Coda contains a little bit of CUDA code.  I assume Bazel
    will easily handle this, but I do not have a GPU, and have never
    worked with CUDA.
  * Cross-compile toolchains.  I've got a minimal example working
    using a crosstool-NG toolchain on a Mac. The task is to polish it
    and port it to Linux and possibly Windows.
* OCaml
  * Learn enough OCaml/Dune to understand the OCaml/C++ interface source and build code
  * Learn enough Dune to understand how it is used in the Coda codebase.
  * Analyze existing Bazel libraries supporting OCaml
    * https://github.com/jin/rules_ocaml
    * https://github.com/ostera/rules_reason
  * develop `rules_ocaml`
    * Option 1: Integrate Bazel and Dune
      * Analyze `rules_foreign_cc` to see how it handles integration of
    configure and make.
        * Prototype a few Minimal Working Examples of using Bazel together with Dune.
        * Implement `rules_ocaml` using this integrational strategy
    * Option 2: Bazel-only ruleset
      * Analyze `rules_go` (Bazel rules for Golang) as a possible model for `rules_ocaml`
      * Implement `rules_ocaml` using this integrational strategy
  * Use the new `rules_ocaml` to implement bazel support for Coda codebase:
    * External libs
    * Internal OCaml code
    * C/C++ interop code
* Golang
  * Coda uses the Golang implementation of libp2p. Google maintains an
    official set of Bazel rules for Go ([rules_go](https://github.com/bazelbuild/rules_go), so this should be
    straightforward.

**STATUS**

* All of the external C/C++ libs have been bazelized, except one,
  Postgresql, which actually builds correctly, but then fails in the
  Bazel code.  I haven't figured out a fix yet; the workaround is to
  just follow current practice and install Postgresql separately.
* I've got some cross-compile code from a previous project that
  supports Mac->Linux (using a crosstools-NG toolchain) and
  Mac->Android (using the Android NDK toolchain).  Bazel has changed
  its toolchain model, so these must be converted. I've done that with
  the crosstools-NG toolchain and managed a minimal build of some of
  the libraries with it.  It will require a little more work and
  testing, but basically we're in good shape as far as C/C++ cross
  compilation is concerned.
* Haven't really looked into Bazel-Ocaml yet.

### Effort Estimates and Timeline

Effort = estimated remaining work effort in hours.

C/C++

| | Platform | Task | Effort | Due | Notes |
| -- | ----------- | ----------- | ------ | ---------- | ---------------|
| 1  | all | C/C++ external libs | 1 | Fri 5/15 | See note 1 |
| 2 | all | libsnark | 3 | Fri 5/15 |
| 3 | Mac to Linux x86 | cross-platform build | 4 | Fri 5/15 | Code adapted from previous project needs polish and testing |
| 4 | Mac to Linux arm | cross-platform build | 2 | W 5/20 | Once an x86 toolchain is working adding support for other target archs should be easy |
| 5 | Mac to Android | cross-platform build | 8 | W 5/20 |Reusing and adapting code from previous project |
| 6 | linux | configure dev. env | 2 | Fri 5/22 |assuming a docker container can be used as a linux dev environment on Mac |
| 7 | linux | C/C++ min. bld | 2 | Fri 5/22 |the Mac stuff should work with few changes |
| 8 | windows | configure dev. env | 4 | TBD | setup VM image, install windows, install tools, etc. |
| 9 | windows | C/C++ min. bld | 8 | TBD |paths, compiler flags, etc. will take some work, depending on toolchain |

Notes:

1. External libs:
  * Assumption: what works on the mac will require little or no effort to work on Linux and Windows
  * libpq (Postgresql) won't build (possible bug in Bazel); workaround is to just install it manually

**OCaml**

| | Platform | Task | Effort | Due | Notes |
| -- | ----------- | ----------- | ------ | ---------- | ---------------|
| 10 | all | OCaml/Dune learning curve | 4 | ongoing |  I can usually fake it, since all languages are alike, but darnit, sometimes I have to sit down and actually learn something. |
| 11 | all | Analyze existing Bazel/OCaml libs | 4 | ongoing | |
| 12 | all | Develop rules_ocaml | 12 |Sun 5/31 |
| 13 | all | Implement Bazel support for Coda OCaml code | 16 | Sun 5/31 |

**Golang, CUDA**

| | Platform | Task | Effort | Due | Notes |
| -- | ----------- | ----------- | ------ | ---------- | ---------------|
| 14 | all | go-libp2p | 4 | W 5/27  |
| 15 | all | CUDA code in Coda | 1 | TBD | cuda-fixnum, cuda-prover, etc. |

Note: I don't have a GPU, and I'm not sure if I can compile CUDA code
without one.  If I can, task 15 will be completed by end of month.

## Drawbacks
[drawbacks]: #drawbacks

The learning curve for Bazel is little steep in places, plus it has
its own languge, Starlark - yet another language to learn.  It's a
Python dialect, but still, somebody on staff will probably have to be
tasked with learning the stuff.  On the other hand, once the build
system is in place it will probably not require much further work,
just like Makefiles are usually left alone once they stabilize.

Another issue with Bazel is feature detection.  Bazel just builds
stuff; it does not provide the feature-detection functionality
supported by GNU autoconf tools.  So it has no analog to
`./configure`; you have to explicitly tell it about all features.
That means that a Bazel build, in cases where feature detection is
required, must be complimented by a traditional `configure` file or
something similar.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

Descriptions of the general benefits of Bazel are easily found with a
simple websearch, so I'll keep it brief:
* Reliable, replicable builds.
* Support for multiple languages.
* Developed and heavily used by Google; also used by many other major projects.
* Eliminates the need to separately install/config/build third-party
  dependencies (apt-get, homebrew, etc.) Bazel will download and build
  everything.
* Support for remote caching and execution is (probably) unique.

Alternatives
* Stick with current situation.  That might work for o(1) internally
  but is not so attractive for outside volunteers who would have to
  struggle with the build system.  My guess is that improving the
  current system would probably be more expensive in the long run than
  switching to Bazel.
* Nix may be an alternative, but according to the folks who provide
  Bazel support for Haskell, Bazel and Nix work well together: [NIX +
  BAZEL = FULLY REPRODUCIBLE, INCREMENTAL
  BUILDS](https://www.tweag.io/posts/2018-03-15-bazel-nix.html).

## Prior art
[prior-art]: #prior-art

Blogposts about switching to Bazel can be found with a little web searching.

I spent considerable effort a few years ago converting a modestly
sized but somewhat complex C/C++ project
([OpenOCF](https://github.com/OpenOCF/iochibity)) from SCons to Bazel.
Though the project was never completed, the switch to Bazel was, and
was (in my opinion) quite successful.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

* What parts of the design do you expect to resolve through the RFC process before this gets merged?

  * Which platforms and toolchains are to be officially supported.

* What parts of the design do you expect to resolve through the implementation of this feature before merge?
  * Optimal OCaml/Bazel integration strategy

* What related issues do you consider out of scope for this RFC that could be addressed in the future independently of the solution that comes out of this RFC?
  * Packaging and distribution.  Bazel just builds stuff; it does not
    install or package.  But presumably one could write a Bazel
    package that would do this.
  * Distributed builds ([Remote Execution](https://docs.bazel.build/versions/master/remote-execution.html))
  * [Remote caching](https://docs.bazel.build/versions/master/remote-caching.html)
  * Implementation of feature-testing in Starlark.

#### Known Unknowns

- Will Bazel and the OCaml ecosystem play nice?  Bazel is design as a
  polyglot system, and already supports a variety of languages, so we
  have reason to be optimistic about this.
- Will it really be cheaper/more efficient etc. to rely on one generic
  build tool, instead of mashing up multiple specialized tools?  Bazel
  is a kind of meta-tool that orchestrates other tools. It has good
  support for integrating shell scripts and other tools into a build
  flow.  And it will always be possible to fall back to some other
  solution for particular tasks, should Bazel prove inapproprite.

#### Unknown Unknowns

TBD

