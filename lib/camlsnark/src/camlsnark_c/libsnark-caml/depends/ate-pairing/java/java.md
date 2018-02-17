# Java class files(under construction)

## Build

* Install [swig](http://www.swig.org/) and Java.

### Windows

* set SWIG to the path to swig in make_wrap.bat
* set JAVA_DIR to the path to java in set-java-path.bat.
* Use the follogin commands:
```
    > cd java
    > make_wrap.bat
```
* bin/bn254_if_wrap.dll is a dll for java.

### Linux

* set JAVA_INC to the path to Java in Makefile

    > make test

* bin/libbn254_if_wrap.so is a shared library for java.

## API and Class

### Setup

* At first, call these functions.
```
    > System.loadLibrary("bn254_if_wrap");
	> BN254.SystemInit();
```
### class Mpz

* a wrapped class of mpz_class of GMP.

* Mpz(int), Mpz(String)
* void set(int x)
    * Set x to this.
* void set(String x)
    * Set x to this.
* void add(Mpz x)
    * Set (this + x) to this.
* void sub(Mpz x)
    * Set (this - x) to this.
* void mul(Mpz x)
    * Set (this * x) to this.
* void mod(Mpz x)
    * Set (this % x) to this.

### class Fp, Fp2, Fp12

* a wrapped class of bn::Fp, bn::Fp2, bn::Fp12.

#### common method

* Fp(int), Fp(String)
* void set(int x)
    * Set x to this.
* void set(String x)
    * Set x to this.
    * The format of Fp is "123", "0xabc"
    * The format of Fp2 is "[a,b]" ; a, b are the format of Fp
    * The format of Fp12 is "[[[a0,b0],[a1,b1],[a2,b2]], [[a3,b3],[a4,b4],[a5,b5]]]"
* void add(Fp x)
    * Set (this + x) to this.
* void sub(Fp x)
    * Set (this - x) to this.
* void mul(Fp x)
    * Set (this * x) to this.
* void power(Mpz x)
    * Set (this ^ x) to this.

#### Fp2
* Fp2(int a, int b)
    * Set (a, b) to this.
* Fp2(Fp a, Fp b)
    * Set (a, b) to this.
* Fp2(String a, String b)
    * Set (a, b) to this.
* Fp getA()
    * Return the reference to a where this = (a, b).
* Fp getB()
    * Return the reference to b where this = (a, b).

#### Fp12
* pairing(Ec2 ec2, Ec1 ec1)
    * Set opt_ate_pairing(ec2, ec1) to this.

### Ec1, Ec2

* a wrapped class of bn::Ec1 and bn::Ec2.

* Ec1(Fp x, Fp y)
    * Set (x, y, 1) to this.
* Ec1(Fp x, Fp y, Fp z)
    * Set (x:y:z) to this.
* Ec1(String x)
    * Set x to this.
    * The format of Ec1 is "x_y" or "0" ; x, y are the format of Fp. "0" is the infinity point.
    * The format of Ec2 is "x_y" or "0" ; x, y are the format of Fp2.
* Boolean isValid()
    * Is (x:y:z) on the curve?
* Boolean isZero()
    * Is this equal to the infinity point?
* void clear()
    * set this to the infinity point.
* dbl()
    * set (this * 2) to this.
* neg()
    * Set (-this) to this.
* add(Ec1 x)
    * Set (this + x) to this.
* sub(Ec1 x)
    * Set (this - x) to this.
* mul(Mpz& x)
    * Set (this * x) to this.
* Fp getX()
    * Return the value of x.
* Fp getY()
    * Return the value of y.
* Fp getZ()
    * Return the value of z.

