/** @file
 *****************************************************************************

 Declaration of interfaces for extended GCD routines.

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef XGCD_HPP_
#define XGCD_HPP_

#include <vector>

namespace libfqfft {

/**
 * Perform the standard Extended Euclidean Division algorithm.
 * Input: Polynomial A, Polynomial B.
 * Output: Polynomial G, Polynomial U, Polynomial V, such that G = (A * U) + (B * V).
 */
template<typename FieldT>
void _polynomial_xgcd(const std::vector<FieldT> &a, const std::vector<FieldT> &b, std::vector<FieldT> &g, std::vector<FieldT> &u, std::vector<FieldT> &v);

} // libfqfft

#include <libfqfft/polynomial_arithmetic/xgcd.tcc>

#endif // XGCD_HPP_
