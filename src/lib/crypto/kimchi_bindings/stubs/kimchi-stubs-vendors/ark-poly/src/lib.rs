//! This crate implements functions for manipulating polynomials over finite
//! fields, including FFTs.
#![cfg_attr(not(feature = "std"), no_std)]
#![warn(unused, future_incompatible, nonstandard_style, rust_2018_idioms)]
#![forbid(unsafe_code)]
#![allow(
    clippy::many_single_char_names,
    clippy::suspicious_op_assign_impl,
    clippy::suspicious_arithmetic_impl
)]

#[macro_use]
extern crate derivative;

#[macro_use]
extern crate ark_std;

pub mod domain;

pub mod evaluations;
pub mod polynomial;

pub use domain::{
    EvaluationDomain, GeneralEvaluationDomain, MixedRadixEvaluationDomain, Radix2EvaluationDomain,
};
pub use evaluations::multivariate::multilinear::{
    DenseMultilinearExtension, MultilinearExtension, SparseMultilinearExtension,
};
pub use evaluations::univariate::Evaluations;
pub use polynomial::{multivariate, univariate, MVPolynomial, Polynomial, UVPolynomial};

#[cfg(test)]
mod test;
