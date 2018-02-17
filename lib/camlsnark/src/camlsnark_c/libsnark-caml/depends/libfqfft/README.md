<h1 align="center">libfqfft</h1>
<h4 align="center">C++ library for FFTs in Finite Fields</h4>

___libfqfft___ is a C++ library for __Fast Fourier Transforms (FFTs)__ in __finite fields__ with __multithreading__ support (via OpenMP). The library is developed by [SCIPR Lab] and contributors (see [AUTHORS] file) and is released under the MIT License (see [LICENSE] file). The library provides functionality for fast multipoint polynomial evaluation, fast polynomial interpolation, and fast computation of Lagrange polynomials. Check out the [__Performance__](#performance) section for __memory__, __runtime__, and __field operation__ profiling data.

## Table of contents

- [Directory structure](#directory-structure)
- [Introduction](#introduction)
- [Background](#background)
- [Domains](#domains)
  - [Radix-2](#radix-2-ffts)
  - [Arithmetic sequence](#arithmetic-sequence)
  - [Geometric sequence](#geometric-sequence)
- [Performance](#performance)
- [Build guide](#build-guide)
- [Testing](#testing)
- [Profiling](#profiling)
- [Tutorials](#tutorials)
- [References](#references)

## Directory structure

The directory structure is as follows:

* [__libfqfft__](libfqfft): C++ source code, containing the following modules:
  * [__evaluation\_domain__](libfqfft/evaluation_domain): declaration of interfaces for evaluation domains
  * [__kronecker\_substitution__](libfqfft/kronecker_substitution): Kronecker substitution for polynomial multiplication
  * [__polynomial\_arithmetic__](libfqfft/polynomial_arithmetic): polynomial arithmetic and extended GCD
  * [__profiling__](libfqfft/profiling): functionality to profile running time, space usage, and number of field operations
  * [__tests__](libfqfft/tests): collection of GTests
  * [__tools__](libfqfft/tools): tools for evaluation domains
* [__depends__](depends): dependency libraries
* [__tutorials__](tutorials): tutorials for getting started with _libfqfft_

## Introduction

This library implements __Fast Fourier Transform (FFT)__ for finite fields, built to be flexible for a variety of software applications. The implementation has support for fast evaluation/interpolation, by providing FFTs and Lagrange-coefficient computations for various domains. These include the standard __radix-2 FFT__, along with the arithmetic sequence and geometric sequence. The library has multicore support using __OpenMP__ for parallelized computations, where applicable.

Check out the [Tutorials](#tutorials) section for examples with our high-level API.

## Background

There is currently a variety of algorithms for computing the Fast Fourier Transform (FFT) over the field of complex numbers. For this situation, there exists many libraries, such as [FFTW](http://www.fftw.org/), that have been rigorously developed, tested, and optimized. Our goal is to use these existing techniques and develop novel implementations to address the more interesting case of FFT in finite fields. We will see that in many instances, these algorithms can be used for the case of finite fields, but the construction of FFT in finite fields remains, in practice, challenging.

Consider a finite field _F_ with _2^m_ elements. We can define a discrete Fourier transform by choosing a _2^m − 1_ root of unity _ω ∈ F_. Operating over the complex numbers, there exists a variety of FFT algorithms, such as the [Cooley-Tukey algorithm](http://en.wikipedia.org/wiki/Cooley%E2%80%93Tukey_FFT_algorithm) along with its variants, to choose from. And in the case that _2^m - 1_ is prime - consider the Mersenne primes as an example - we can turn to other algorithms, such as [Rader's algorithm](http://en.wikipedia.org/wiki/Rader%27s_FFT_algorithm) and [Bluestein's algorithm](http://en.wikipedia.org/wiki/Bluestein%27s_FFT_algorithm). In addition, if the domain size is an extended power of two or the sum of powers of two, variants of the radix-2 FFT algorithms can be employed to perform the computation.

However, in a finite field, there may not always be a root of unity. If the domain size is not as mentioned, then one can consider adjoining roots to the field. Although, there is no guarantee that adjoining such a root to the field can render the same performance benefits, as it would produce a significantly larger structure that could cancel out benefits afforded by the FFT itself. Therefore, one should consider other algorithms which continue to perform better than the naïve evaluation.

## Domains

Given a domain size, the library will determine and perform computations over the best-fitted domain. Ideally, it is desired to perform evaluation and interpolation over a radix-2 FFT domain, however, this may not always be possible. Thus, the library provides the arithmetic and geometric sequence domains as fallback options, which we show to perform better than naïve evaluation.

|               | Basic Radix-2 | Extended Radix-2 | Step Radix-2 |  Arithmetic Sequence | Geometric Sequence |
|---------------|:-------------:|:----------------:|:------------:|:--------------------:|:------------------:|
| Evaluation    |  O(n log n)   |    O(n log n)    |  O(n log n)  | M(n) log(n) + O(M(n)) |    2M(n) + O(n)    |
| Interpolation |  O(n log n)   |    O(n log n)    |  O(n log n)  | M(n) log(n) + O(M(n)) |    2M(n) + O(n)    |

### Radix-2 FFTs

The radix-2 FFTs are comprised of three domains: basic, extended, and step radix-2. The radix-2 domain implementations make use of pseudocode from [CLRS 2n Ed, pp. 864].

#### Basic radix-2 FFT

The basic radix-2 FFT domain has size _m = 2^k_ and consists of the _m_-th roots of unity. The domain uses the standard FFT algorithm and inverse FFT algorithm to perform evaluation and interpolation. Multi-core support includes parallelizing butterfly operations in the FFT operation.

#### Extended radix-2 FFT

The extended radix-2 FFT domain has size _m = 2^(k + 1)_ and consists of the _m_-th roots of unity, union a coset of these roots. The domain performs two _basic\_radix2\_FFT_ operations for evaluation and interpolation in order to account for the extended domain size.

#### Step radix-2 FFT

The step radix-2 FFT domain has size _m = 2^k + 2^r_ and consists of the _2^k_-th roots of unity, union a coset of _2^r_-th roots of unity. The domain performs two _basic\_radix2\_FFT_ operations for evaluation and interpolation in order to account for the extended domain size.

### Arithmetic sequence

The arithmetic sequence domain is of size _m_ and is applied for more general cases. The domain applies a basis conversion algorithm between the monomial and the Newton bases. Choosing sample points that form an arithmetic progression, _a\_i = a\_1 + (i - 1)*d_, allows for an optimization of computation over the monomial basis, by using the special case of Newton evaluation and interpolation on an arithmetic progression, see \[BS05\].

### Geometric sequence

The geometric sequence domain is of size _m_ and is applied for more general cases. The domain applies a basis conversion algorithm between the monomial and the Newton bases. The domain takes advantage of further simplications to Newton evaluation and interpolation by choosing sample points that form a geometric progression, _a\_n = r^(n-1)_, see \[BS05\].

## Performance

We now discuss performance data of the library in terms of number of field operations, running time, and memory usage, across all evaluation domains.

__Machine Specification:__ The following benchmark data was obtained on a 64-bit Intel i7 Quad-Core machine with 16GB RAM (2x8GB) running Ubuntu 14.04 LTS. The code is compiled using g++ 4.8.4.

```
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                8
On-line CPU(s) list:   0-7
Thread(s) per core:    1
Core(s) per socket:    2
Socket(s):             4
NUMA node(s):          1
Vendor ID:             GenuineIntel
CPU family:            6
Model:                 94
Stepping:              3
CPU MHz:               4008.007
BogoMIPS:              8016.01
Virtualization:        VT-x
L1d cache:             32K
L1i cache:             32K
L2 cache:              256K
L3 cache:              8192K
NUMA node0 CPU(s):     0-7
```

### Runtime

<p align="center"><img src="https://cloud.githubusercontent.com/assets/9260812/16982222/a35bda22-4e23-11e6-909f-8fb8ce95bcf2.png" width="75%"></p>

### Memory

<p align="center"><img src="https://cloud.githubusercontent.com/assets/9260812/16982230/a6b4b536-4e23-11e6-811d-68a46b8dc1c0.png" width="75%"></p>

### Field operations

<p align="center"><img src="https://cloud.githubusercontent.com/assets/9260812/16982233/a9ad26c4-4e23-11e6-924a-dcd3383faa09.png" width="75%"></p>

<p align="center"><img src="https://cloud.githubusercontent.com/assets/9260812/16982235/ab75a35a-4e23-11e6-97fd-0e4480f78b37.png" width="75%"></p>

## Build guide

The library has the following dependencies:

* [CMake](http://cmake.org/)
* [Google Test (GTest)](http://github.com/google/googletest)
* [GMP](http://gmplib.org/)
* [gnuplot](http://www.gnuplot.info/)
* [libff](https://github.com/scipr-lab/libff)
* [libprocps](http://packages.ubuntu.com/trusty/libprocps3-dev)

The library has been tested on Linux, but it is compatible with Windows and Mac OS X. (Nevertheless, memory profiling works only on Linux machines.)

### Installation

On Ubuntu 14.04 LTS:

```
sudo apt-get install build-essential git libboost-all-dev cmake libgmp3-dev libssl-dev libprocps3-dev pkg-config gnuplot-x11
```

### Compilation

Fetch dependencies from their GitHub repos:

```
git submodule init && git submodule update
```

To compile, starting at the project root directory, create the Makefile:

```
mkdir build && cd build && cmake ..
```

#### Options

The following flags change the behavior of the compiled code:

* `cmake .. -DCMAKE_INSTALL_PREFIX=/install/path`
Specifies the install location from the provided install prefix path.

* `cmake .. -DMULTICORE=ON`
Enables parallelized execution using OpenMP. This will utilize all cores on the CPU for heavyweight parallelizable operations such as FFT.

* `cmake .. -DOPT_FLAGS={ FLAGS }`
Passes specified optimizations flags to compiler.

* `cmake .. -PROF_DOUBLE=ON`
Enables profiling with Double (default: ON). If the flag is turned off, profiling will use `Fr<edwards_pp>`.

* `cmake .. -DWITH_PROCPS=OFF`
Links libprocps for usage in memory profiling. If this flag is turned off, memory profiling will not work.

* `cmake .. -DDEPENDS_DIR=...`
Sets the dependency installation directory to the provided absolute path (default: installs dependencies in the respective submodule directories)

Then, to compile the library and profiler, run:

```
make
```

The above makes the `build` folder and compiles the profiling executables to the project root directory. To remove all executables, from the build folder, run `make clean`.

### Using libfqfft as a library

To install the libfqfft library:
```
make install
```

Depending on the specified install location from the optional `-DCMAKE_INSTALL_PREFIX`, this will install the requisite headers into /install/path/include; so your application should be compiled using -I/install/path/include.

## Testing

The library uses Google Test for its unit tests. The unit tests cover polynomial evaluation, polynomial interpolation, Lagrange polynomials evaluation, and vanishing polynomial evaluation, for all evaluation domains. There are also unit tests for polynomial arithmetic, Kronecker substitution, and extended Euclidean GCD. The test suite is easily extensible to support a wide range of fields and domain sizes.

To run the tests for this library, run:

```
make check
```

This will compile and run the tests. Alternatively, from the `build` folder, one can also run `./libfqfft/gtests` after compiling.

The unit tests are divided into three GTest files located under `libfqfft/tests`:

1. __Evaluation domains__: `evaluation_domain_test.cpp`
2. __Polynomial arithmetic__: `polynomial_arithmetic_test.cpp`
3. __Kronecker substitution__: `kronecker_substitution_test.cpp`

## Profiling

__Warning:__ Profiling of memory usage is Linux-specific as it makes use of `getrusage()` from `<sys/resource.h>`. Compatibility of the `getrusage()` BSD syscall equivalent is kernel specific, such as with the `getrusage()` call listed under Darwin/OSX [XNU-3248.20.55](http://opensource.apple.com//source/xnu/xnu-3248.20.55/) in `bsd/kern/kern_resource.c`.

The library includes functionality for profiling running time, memory usage, and number of field operations, and also for plotting the resulting data with [gnuplot](http://www.gnuplot.info/). All profiling and plotting activity is logged in the folder `libfqfft/profiling/logs`; logs are sorted into a directory hierarchy by profiling type and timestamp, respectively. The running time and memory usage profiling also supports multi-threading.

To compile the profiler, run:

```
make profiler profiling_menu
```

To start the profiler, navigate to the project root directory and run:

```
./profiling_menu
```

Below is an explanation of profiling and plotting options.

### Profiling

Radix-2 FFT profiling numbers are in accordance to a vector of input size _n_. Polynomial multiplication computes two polynomials of degree _n_ by performing FFT on a resulting vector of size _2n_. For arithmetic and geometric sequence profiling, both evaluation and interpolation take in vectors of size _n_ and return a vector of degree _n_.

Profiling options include:

1. __Profiling type:__ Running time, memory usage, and/or fieldops count (any combination)
2. __Domain type:__ All domains, radix-2 domains, or arithmetic/geometric sequence domains
3. __Domain sizes:__ Preset small, preset large, or custom size

Profiling results are saved in ```libfqfft/profiling/logs/{datetime}```.

### Plotting

Plotting uses __gnuplot__ scripts that are generalized for varying requests per profiling type. __Runtimes__ are plotted for all domains, comparing domain size to runtime in seconds. __Memory usage__ are plotted for all domains by comparing domain size to memory usage in kilobytes. __Field operations__ are plotted in two graphs: one comparing domain size to total operation counts, another comparing each type of operation - addition, subtraction, multiplication, division, and negation - with its respective count, for all domains.

Plotting options include:

1. __Profiling type:__ Plotting Runtime, Memory, or Field Operation Counts
2. __File selection:__ Lists all previous profile logs of profiling type

Plots are saved in the directory chosen at step 2, _File Selection_.

## Tutorials

The library includes the following tutorial examples, found in the [tutorials](tutorials) folder. To compile the tutorials, run:

```
make tutorials
```

The above will compile the executables to the `build/tutorials` folder, and then run them.

### Polynomial multiplication on FFT

* File: [tutorials/polynomial_multiplication_on_fft_example.cpp](tutorials/polynomial_multiplication_on_fft_example.cpp)

* Run: `./polynomial_multiplication`

We construct two polynomials, _a_ and _b_, and then call the `_polynomial_multiplication()` function in `libfqfft/polynomial_arithmetic/basic_operations.hpp` to perform our operation. The result is stored into polynomial _c_, and then printed out. Note that polynomials are stored in C++ STL vectors in order from lowest to highest degree.

### Polynomial evaluation

* File: [tutorials/polynomial_evaluation_example.cpp](tutorials/polynomial_evaluation_example.cpp)

* Run: `./polynomial_evaluation`

We construct a polynomial _f_ and domain size _m_. Then, we get an evaluation domain by calling `get_evaluation_domain(m)`, which will determine the best suitable domain to perform evaluation on given the domain size. Now we compute the FFT over our determined domain of the polynomial _f_, then print out the result.

### Lagrange polynomial evaluation

* File: [tutorials/lagrange_polynomial_evaluation_example.cpp](tutorials/lagrange_polynomial_evaluation_example.cpp)

* Run: `./lagrange_polynomial_evaluation`

We define an element _t_ and domain size _m_. Then, we determine our evaluation domain by invoking `get_evaluation_domain(m)` as before. Next, we call `evaluate_all_lagrange_polynomials(t)` to evaluate all Lagrange polynomials. The output is a vector _(a[0], ... ,a[m-1])_, where _a[i]_ is the evaluation of _L\_{i,S}(z)_ at _z = t_. Lastly, we print out this result.

## References

**Evaluation Domains:**

\[BS05\] [_Polynomial Evaluation and Interpolation on Special Sets of Points_](http://specfun.inria.fr/bostan/publications/BoSc05.pdf), Alin Bostan and Eric Schost 2005

\[BLS03\] [_Tellegen’s Principle into Practice_](http://specfun.inria.fr/bostan/publications/BoLeSc03.pdf), Alin Bostan, Gregoire Lecerf, and Eric Schost 2003

**Kronecker Substitution:**

\[S15\] [_Arithmetic in Finite Fields_](http://math.mit.edu/classes/18.783/LectureNotes3.pdf), Andrew Sutherland 2015

\[H07\] [_Faster Polynomial Multiplication via Multipoint Kronecker Substitution_](http://arxiv.org/pdf/0712.4046v1.pdf), David Harvey 2007

[SCIPR Lab]: http://www.scipr-lab.org/ (Succinct Computational Integrity and Privacy Research Lab)

[LICENSE]: LICENSE (LICENSE file in top directory of libfqfft distribution)

[AUTHORS]: AUTHORS (AUTHORS file in top directory of libfqfft distribution)
