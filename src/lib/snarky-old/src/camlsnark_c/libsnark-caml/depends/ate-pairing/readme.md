
High-Speed Software Implementation of the Optimal Ate Pairing over Barreto-Naehrig Curves
=============

This library provides functionality to compute the optimal ate pairing over Barreto-Naehrig (BN) curves.
It is released under the [BSD 3-Clause License](http://opensource.org/licenses/BSD-3-Clause).

Now I'm developing a new pairing library [mcl](https://github.com/herumi/mcl/), which is more portable and supports larger primes than this library though it is a little slower.

History
-------------

* 2015/May/15: add [java api](java/java.md)
* 2014/Jun/15: support a BN curve for SNARKs, incorporating code from [libsnark](https://github.com/scipr-lab/libsnark)
* 2013/Jun/02: support `mulx` on [Haswell](http://en.wikipedia.org/wiki/Haswell_%28microarchitecture%29)
* 2013/Mar/08: add elliptic curve class
* 2012/Jan/30: rewrite ate pairing according to [Faster explicit formulas for computing pairings over ordinary curves](http://www.patricklonga.bravehost.com/speed_pairing.html)
* 2010/Sep/8: change twist xi from u + 12 to u
* 2010/Jul/15: use cyclotomic squaring for final exponentiation
* 2010/Jun/18: first release

Overview
-------------

The following two BN curves are supported:

1. a BN curve over the 254-bit prime p = 36z^4 + 36z^3 + 24z^2 + 6z + 1 where z = -(2^62 + 2^55 + 1); and
2. a BN curve over a 254-bit prime p such that n := p + 1 - t has high 2-adicity.

By default, the first curve (we call it as CurveFp254BNb) is used; when setting the flag `SUPPORT_SNARK`, the second curve (we call it as CurveSNARK) is used instead.

* __CurveFp254BNb__
The value of z is found by [\[NASKM\]](http://dx.doi.org/10.1007/978-3-540-85538-5_13) first.
The curve instantiated by z is investigated by [\[PSNB\]](http://eprint.iacr.org/2010/429) for an efficient implementation.
Our library implements a fast algorithm, which is proposed by [\[AKLGL\]](http://eprint.iacr.org/2010/526) for this curve.
The performance of this library is competitive to the state-of-the-art implementation report in [\[ABLR\]](http://sac2013.irmacs.sfu.ca/slides/s1.pdf).

* __CurveSNARK__
Support for the second curve builds on code provided by [SCIPR Lab](http://www.scipr-lab.org/) in [libsnark](https://github.com/scipr-lab/libsnark). The curve was specifically selected for speeding up __Succinct Non-interactive ARguments of Knowledge__ (SNARKs), which benefit from its high 2-adicity (see [\[BCGTV13\]](http://eprint.iacr.org/2013/507) and [\[BCTV14\]](http://eprint.iacr.org/2013/879)).

Pairing computations on the first curve are more efficient, and the performance numbers reported below (and in our papers) are achieved using this curve (which is prefered for applications that do not benefit from high 2-adicity).
Note that the old parameters in \[BDMOHT\] are not used now.


Parameters
-------------

The curve equation for a BN curve is:

	E/Fp: y^2 = x^3 + b .

The two supported BN curves have the following parameters:

1. b = 2 and p = 16798108731015832284940804142231733909889187121439069848933715426072753864723; and
2. b = 3 and p = 21888242871839275222246405745257275088696311157297823662689037894645226208583.

As usual,

* the cyclic group G1 (aka Ec1) is instantiated as E(Fp)[n] where n := p + 1 - t;
* the cyclic group G2 (aka Ec2) is instantiated as the inverse image of E'(Fp^2)[n] under a twisting isomorphism from E' to E; and
* the pairing e: G1 x G2 -> Fp12 is the optimal ate pairing.

The field Fp12 is constructed via the following tower:

* Fp2 = Fp[u] / (u^2 + 1)
* Fp6 = Fp2[v] / (v^3 - Xi) where Xi = u + 1
* Fp12 = Fp6[w] / (w^2 - v)

Requirements
-------------

* OS: 64-bit Windows; 64-bit Linux; Mac OS X
* CPU: x64 Intel; AMD processor
* C++ compiler: Visual Studio 2012; gcc 4.4.1 or later


Build instructions
-------------

### Windows

    > git clone git://github.com/herumi/xbyak.git
    > git clone git://github.com/herumi/ate-pairing.git
    > git clone git://github.com/herumi/cybozulib-ext.git ; compiled binary of mpir

Open `ate/ate.sln` and compile `test_bn` with Release mode. The produced binary is `ate/x64/Release/test_bn.exe`.

### Cygwin

Install `mingw64-x86_64-gcc-g++` (run Cygwin setup and search `mingw64`). Then use the following commands:

    PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin/:$PATH
    make -j
    test/bn.exe

Note that `test/bn.exe` uses `mulx` if possible; if you do not want to use it, run the executable as `test/bn.exe -mulx 0`. (This allows you to verify the difference with/without mulx on Haswell.)

### Linux

Use the following commands:

    $ git clone git://github.com/herumi/xbyak.git
    $ git clone git://github.com/herumi/ate-pairing.git
    $ cd ate-pairing
    $ make -j
    $ test/bn

The library [xbyak](https://github.com/herumi/xbyak) is a x86/x86-64 JIT assembler for C++, developed for efficient pairing implementations. (See also [this webpage](http://homepage1.nifty.com/herumi/soft/xbyak_e.html).) Note that binaries other than `test/bn` are used for testing purposes only.

* This implementation uses dynamically-generated code, so you will get the error
`zmInit ERR:can't protect` if execution of code on the heap is disallowed by
some modern systems.
For example, on Fedora 20, run `sudo setsebool -P allow_execheap 1` to allow execution to solve this.

By the default, the first BN curve is used. If instead you want to use the second BN curve (specialized to SNARKs), modify the fourth line above to:

    $ make -j SUPPORT_SNARK=1

* REMARK. You *defined* `BN_SUPPORT_SNARK` macro for a compile when if you use a library(libzm.a) made by `SUPPORT_SNARK=1`.


Usage
-------------

See the function `sample2()` in [sample.cpp](https://github.com/herumi/ate-pairing/blob/master/test/sample.cpp). Also, use can use `mpz_class` for scalar multiplication of points on the elliptic curves,
if `MIE_ATE_USE_GMP` is defined. For instance:

    using namespace bn;
    Param::init();
    const Ec2 g2(...);
    const Ec1 g1(...);
    mpz_class a("123456789");
    mpz_class b("98765432");
    Ec1 g1a = g1 * a;
    Ec2 g2b = g2 * b;
    Fp12 e;
    opt_atePairing(e, g2b, g1a);

Usage for Java
-------------
See [java.md](java/java.md).
A sample code is [BN254Test.java](java/BN254Test.java).

Operation costs
-------------

Let mu be the cost of _unreduced multiplication_ producing double-precision result (i.e., 256-bit int x 256-bit int to 512-bit int); and let r be the cost of _modular reduction_ of double-precision integers (i.e., 512-bit int to 256-bit int in Fp). Then, for us,

* Fp::mul = mu + r
* Fp2::mul = 3mu + 2r
* Fp2::square = 2mu + 2r

Next, we compare the costs of our library with the one of [\[AKLGL10\]](http://eprint.iacr.org/2010/526):

Phase               | [AKLGL10]     | This work
--------------------|---------------|---------------
Miller loop         | 6792mu + 3022r| 6785mu + 3022r
Final exponentiation| 3753mu + 2006r| 3526mu + 1932r
Optimal ate pairing |10545mu + 5028r|10311mu + 4954r

Note: [\[Table 2 in p. 17, AKLGL10\]](http://eprint.iacr.org/2010/526) does not contain the cost of (m, r) so we have added the costs of (282m + 6mu + 4r) and (30m + 75mu + 50r) to ML and FE respectively.

Finally, at the moment, our implementation does not support the algorithm in [PSNB10](https://eprint.iacr.org/2010/429).

Benchmark
-------------

The cost of a pairing is __1.17M__ clock cycles on Core i7 4700MQ (Haswell) 2.4GHz processor with TurboBoost disabled. Below, we also include clock cycle counts on Core i7 2600 3.4GHz, Xeon X5650 2.6GHz, and Core i7 4700MQ 2.4GHz.
The formal benchmark is written in \[ZPMRTH\].

    % sudo sh -c "echo 0 > /sys/devices/system/cpu/cpufreq/boost"
    % cat /sys/devices/system/cpu/cpufreq/boost
    0

operation   | i7 2600|Xeon X5650|Haswell|Haswell with mulx
------------|--------|----------|-------|-----------------
TurboBoost  |on      |on        |off    |off
            |        |          |       |
mu          | 50     |60        |42     |38
r           | 80     |98        |69     |65
Fp:mul      |124     |146       |98     |90
Fp2:mul     |360     |412       |       |
Fp2:square  |288     |335       |       |
            |        |          |       |
G1::double  |1150    |1300      |       |
G1::add     |2200    |2600      |       |
G2::double  |2500    |2900      |       |
G2::add     |5650    |6500      |       |
Fp12::square|4500    |5150      |       |
Fp12::mul   |6150    |7000      |       |
            |        |          |       |
Miller loop |0.83M   |0.97M     |0.82M  |0.71M
final_exp   |0.53M   |0.63M     |0.51M  |0.46M
            |        |          |       |
pairing     |1.36M   |1.60M     |1.33M  |1.17M



References
-------------

* \[ABLR\] [_The Realm of the Pairings_](http://dx.doi.org/10.1007/978-3-662-43414-7_1) (Invited Talk),
 Diego F. Aranha, Paulo S. L. M. Barreto, Patrick Longa, and Jefferson E. Ricardini,
 SAC 2013, ([preprint](http://eprint.iacr.org/2013/722), [slide](http://sac2013.irmacs.sfu.ca/slides/s1.pdf))

* \[NASKM\] [_Integer Variable chi-Based Ate Pairing_](http://dx.doi.org/10.1007/978-3-540-85538-5_13), Y. Nogami, M. Akane, Y. Sakemi, H. Kato, and Y. Morikawa,
 Pairing 2008

* \[PSNB\] [_A Family of Implementation-Friendly BN Elliptic Curves_](http://dx.doi.org/10.1016/j.jss.2011.03.083),
 G.C.C.F. Pereira, M.A. Simplicio Jr, M. Naehrig, P.S.L.M. Barreto, J. Systems and Software 2011, ([preprint](http://eprint.iacr.org/2010/429))

* \[AKLGL\] [_Faster Explicit Formulas for Computing Pairings over Ordinary Curves_](http://dx.doi.org/10.1007/978-3-642-20465-4_5),
 D.F. Aranha, K. Karabina, P. Longa, C.H. Gebotys, J. Lopez,
 EUROCRYPTO 2011, ([preprint](http://eprint.iacr.org/2010/526))

* \[BDMOHT\] [_High-Speed Software Implementation of the Optimal Ate Pairing over Barreto-Naehrig Curves_](http://dx.doi.org/10.1007/978-3-642-17455-1_2),
   Jean-Luc Beuchat, Jorge Enrique González Díaz, Shigeo Mitsunari, Eiji Okamoto, Francisco Rodríguez-Henríquez, Tadanori Teruya,
  Pairing 2010, ([preprint](http://eprint.iacr.org/2010/354))

* [_A Fast Implementation of the Optimal Ate Pairing over BN curve on Intel Haswell Processor_](http://eprint.iacr.org/2013/362),
  Shigeo Mitsunari,
  IACR ePrint 2013/362

* [_Succinct Non-Interactive Zero Knowledge for a von Neumann Architecture_](http://eprint.iacr.org/2013/879),
  Eli Ben-Sasson, Alessandro Chiesa, Eran Tromer, Madars Virza,
  USENIX Security 2014

* \[ZPMRTH\] [_Software implementation of an Attribute-Based Encryption scheme_](http://dx.doi.org/10.1109/TC.2014.2329681),
  Eric Zavattoni and Luis J. Dominguez Perez and Shigeo Mitsunari and Ana H. Sanchez-Ramirez and Tadanori Teruya and Francisco Rodriguez-Henriquez,
  IEEE Transactions on Computers, To appear, ([preprint](https://eprint.iacr.org/2014/401), [project Web page and source code](http://sandia.cs.cinvestav.mx/index.php?n=Site.CPABE))

* [This library's old webpage](http://homepage1.nifty.com/herumi/crypt/ate-pairing.html)


Authors
-------------

* MITSUNARI Shigeo (`herumi@nifty.com`)
* TERUYA Tadanori (`tadanori.teruya@gmail.com`)

Contributors
-------------

* Alessandro Chiesa (`alexch@mit.edu`)
* Madars Virza (`madars@mit.edu`)
