/** @file
 *****************************************************************************

 Declaration of interfaces for Kronecker substitution.

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef KRONECKER_SUBSTITUTION_HPP_
#define KRONECKER_SUBSTITUTION_HPP_

#include <vector>

namespace libfqfft {

/**
 * Given two polynomial vectors, A and B, the function performs
 * polynomial multiplication and returns the resulting polynomial vector.
 * The implementation makes use of
 * [Harvey 07, Multipoint Kronecker Substitution, Section 2.1] and
 * [Gathen and Gerhard, Modern Computer Algebra 3rd Ed., Section 8.4].
 */
template<typename FieldT>
void kronecker_substitution(std::vector<FieldT> &v3, const std::vector<FieldT> &v1, const std::vector<FieldT> &v2);

} // libfqfft

#include <libfqfft/kronecker_substitution/kronecker_substitution.tcc>

#endif // KRONECKER_SUBSTITUTION_HPP_
