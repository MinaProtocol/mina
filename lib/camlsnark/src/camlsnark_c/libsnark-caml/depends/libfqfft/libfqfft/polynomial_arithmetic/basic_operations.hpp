
/** @file
 *****************************************************************************

 Declaration of interfaces for basic polynomial operation routines.

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef BASIC_OPERATIONS_HPP_
#define BASIC_OPERATIONS_HPP_

#include <vector>

namespace libfqfft {

/**
 * Returns true if polynomial A is a zero polynomial.
 */
template<typename FieldT>
bool _is_zero(const std::vector<FieldT> &a);

/**
 * Removes extraneous zero entries from in vector representation of polynomial.
 * Example - Degree-4 Polynomial: [0, 1, 2, 3, 4, 0, 0, 0, 0] -> [0, 1, 2, 3, 4]
 * Note: Simplest condensed form is a zero polynomial of vector form: [0]
 */
template<typename FieldT>
void _condense(std::vector<FieldT> &a);

/**
 * Compute the reverse polynomial up to vector size n (degree n-1).
 * Below we make use of the reversal endomorphism definition from
 * [Bostan, Lecerf, & Schost, 2003. Tellegen's Principle in Practice, on page 38].
 */
template<typename FieldT>
void _reverse(std::vector<FieldT> &a, const size_t n);

/**
 * Computes the standard polynomial addition, polynomial A + polynomial B, and stores result in polynomial C.
 */
template<typename FieldT>
void _polynomial_addition(std::vector<FieldT> &c, const std::vector<FieldT> &a, const std::vector<FieldT> &b);

/**
 * Computes the standard polynomial subtraction, polynomial A - polynomial B, and stores result in polynomial C.
 */
template<typename FieldT>
void _polynomial_subtraction(std::vector<FieldT> &c, const std::vector<FieldT> &a, const std::vector<FieldT> &b);

/**
 * Perform the multiplication of two polynomials, polynomial A * polynomial B, and stores result in polynomial C.
 */
template<typename FieldT>
void _polynomial_multiplication(std::vector<FieldT> &c, const std::vector<FieldT> &a, const std::vector<FieldT> &b);

/**
 * Perform the multiplication of two polynomials, polynomial A * polynomial B, using FFT, and stores result in polynomial C.
 */
template<typename FieldT>
void _polynomial_multiplication_on_fft(std::vector<FieldT> &c, const std::vector<FieldT> &a, const std::vector<FieldT> &b);

/**
 * Perform the multiplication of two polynomials, polynomial A * polynomial B, using Kronecker Substitution, and stores result in polynomial C.
 */
template<typename FieldT>
void _polynomial_multiplication_on_kronecker(std::vector<FieldT> &c, const std::vector<FieldT> &a, const std::vector<FieldT> &b);

/**
 * Compute the transposed, polynomial multiplication of vector a and vector b.
 * Below we make use of the transposed multiplication definition from
 * [Bostan, Lecerf, & Schost, 2003. Tellegen's Principle in Practice, on page 39].
 */
template<typename FieldT>
std::vector<FieldT> _polynomial_multiplication_transpose(const size_t &n, const std::vector<FieldT> &a, const std::vector<FieldT> &c);

/**
 * Perform the standard Euclidean Division algorithm.
 * Input: Polynomial A, Polynomial B, where A / B
 * Output: Polynomial Q, Polynomial R, such that A = (Q * B) + R.
 */
template<typename FieldT>
void _polynomial_division(std::vector<FieldT> &q, std::vector<FieldT> &r, const std::vector<FieldT> &a, const std::vector<FieldT> &b);

} // libfqfft

#include <libfqfft/polynomial_arithmetic/basic_operations.tcc>

#endif // BASIC_OPERATIONS_HPP_
