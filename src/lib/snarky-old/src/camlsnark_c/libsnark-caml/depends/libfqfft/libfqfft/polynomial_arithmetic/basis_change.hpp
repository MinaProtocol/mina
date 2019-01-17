/** @file
 *****************************************************************************

 Declaration of interfaces for basis change routines.

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef BASIS_CHANGE_HPP_
#define BASIS_CHANGE_HPP_

#include <vector>

namespace libfqfft {

/**
 * Compute the Subproduct Tree of degree 2^M and store it in Tree T.
 * Below we make use of the Subproduct Tree description from
 * [Bostan and Schost 2005. Polynomial Evaluation and Interpolation on Special Sets of Points], on page 7.
 */
template<typename FieldT>
void compute_subproduct_tree(const size_t &m, std::vector<std::vector<std::vector<FieldT> > > &T);

/**
 * Perform the general change of basis from Monomial to Newton Basis with Subproduct Tree T.
 * Below we make use of the MonomialToNewton and TNewtonToMonomial pseudocode from
 * [Bostan and Schost 2005. Polynomial Evaluation and Interpolation on Special Sets of Points], on page 12 and 14.
 */
template<typename FieldT>
void monomial_to_newton_basis(std::vector<FieldT> &a, const std::vector<std::vector<std::vector<FieldT> > > &T, const size_t &n);

/**
 * Perform the general change of basis from Newton to Monomial Basis with Subproduct Tree T.
 * Below we make use of the NewtonToMonomial pseudocode from
 * [Bostan and Schost 2005. Polynomial Evaluation and Interpolation on Special Sets of Points], on page 11.
 */
template<typename FieldT>
void newton_to_monomial_basis(std::vector<FieldT> &a, const std::vector<std::vector<std::vector<FieldT> > > &T, const size_t &n);

/**
 * Perform the change of basis from Monomial to Newton Basis for geometric sequence.
 * Below we make use of the psuedocode from
 * [Bostan & Schost 2005. Polynomial Evaluation and Interpolation on Special Sets of Points] on page 26.
 */
template<typename FieldT>
void monomial_to_newton_basis_geometric(std::vector<FieldT> &a,
                                        const std::vector<FieldT> &geometric_sequence,
                                        const std::vector<FieldT> &geometric_triangular_sequence,
                                        const size_t &n);

/**
 * Perform the change of basis from Newton to Monomial Basis for geometric sequence
 * Below we make use of the psuedocode from
 * [Bostan & Schost 2005. Polynomial Evaluation and Interpolation on Special Sets of Points] on page 26.
 */
template<typename FieldT>
void newton_to_monomial_basis_geometric(std::vector<FieldT> &a,
                                        const std::vector<FieldT> &geometric_sequence,
                                        const std::vector<FieldT> &geometric_triangular_sequence,
                                        const size_t &n);

} // libfqfft

#include <libfqfft/polynomial_arithmetic/basis_change.tcc>

#endif // BASIS_CHANGE_HPP_
