<h1 align="center">ark-poly</h1>
<p align="center">
    <img src="https://github.com/arkworks-rs/algebra/workflows/CI/badge.svg?branch=master">
    <a href="https://github.com/arkworks-rs/algebra/blob/master/LICENSE-APACHE"><img src="https://img.shields.io/badge/license-APACHE-blue.svg"></a>
    <a href="https://github.com/arkworks-rs/algebra/blob/master/LICENSE-MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
    <a href="https://deps.rs/repo/github/arkworks-rs/algebra"><img src="https://deps.rs/repo/github/arkworks-rs/algebra/status.svg"></a>
</p>

This crate implements traits and implementations for polynomials, FFT-friendly subsets of a field (dubbed "domains"), and FFTs for these domains.

### Polynomials

The `polynomial` module provides the following traits for defining polynomials in coefficient form:

- [`Polynomial`](./src/polynomial/mod.rs#L16):
Requires implementors to support common operations on polynomials,
such as `Add`, `Sub`, `Zero`, evaluation at a point, degree, etc,
and defines methods to serialize to and from the coefficient representation of the polynomial.
- [`UVPolynomial`](./src/polynomial/mod.rs#L43) :
Specifies that a `Polynomial` is actually a *univariate* polynomial.
- [`MVPolynomial`](./src/polynomial/mod.rs#L59):
Specifies that a `Polynomial` is actually a *multivariate* polynomial.

This crate also provides the following data structures that implement these traits:

- [`univariate/DensePolynomial`](./src/polynomial/univariate/dense.rs#L22):
Represents degree `d` univariate polynomials via a list of `d + 1` coefficients.
This struct implements the [`UVPolynomial`](./src/polynomial/mod.rs#L43) trait.
- [`univariate/SparsePolynomial`](./src/polynomial/univariate/sparse.rs#L15):
Represents degree `d` univariate polynomials via a list containing all non-zero monomials.
This should only be used when most coefficients of the polynomial are zero.
This struct implements the [`Polynomial`](./src/polynomial/mod.rs#L16) trait
(but *not* the `UVPolynomial` trait).
- [`multivariate/SparsePolynomial`](./src/polynomial/multivariate/sparse.rs#L21):
Represents multivariate polynomials via a list containing all non-zero monomials.

This crate also provides the [`univariate/DenseOrSparsePolynomial`](./src/polynomial/univariate/mod.rs#L16) enum, which allows the user to abstract over the type of underlying univariate polynomial (dense or sparse).

### Evaluations

The `evaluations` module provides data structures to represent univariate polynomials in lagrange form.

- [`univariate/Evaluations`](./src/evaluations/univariate/mod.rs#L18)
Represents a univariate polynomial in evaluation form, which can be used for FFT.

The `evaluations` module also provides the following traits for defining multivariate polynomials in lagrange form:

- [`multivariate/multilinear/MultilinearExtension`](./src/evaluations/multivariate/multilinear/mod.rs#L23)
Specifies a multilinear polynomial evaluated over boolean hypercube.
  
This crate provides some data structures to implement these traits.

- [`multivariate/multilinear/DenseMultilinearExtension`](./src/evaluations/multivariate/multilinear/dense.rs#L17)
Represents multilinear extension via a list of evaluations over boolean hypercube.
  
- [`multivariate/multilinear/SparseMultilinearExtension`](./src/evaluations/multivariate/multilinear/sparse.rs#L20)
Represents multilinear extension via a list of non-zero evaluations over boolean hypercube.

### Domains

TODO
