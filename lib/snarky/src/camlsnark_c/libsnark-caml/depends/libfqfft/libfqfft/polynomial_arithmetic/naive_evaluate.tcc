/** @file
 *****************************************************************************

 Implementation of interfaces for naive evaluation routines.

 See naive_evaluate.hpp .
 
 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef NAIVE_EVALUATE_TCC_
#define NAIVE_EVALUATE_TCC_

#include <algorithm>

namespace libfqfft {

template<typename FieldT>
FieldT evaluate_polynomial(const size_t &m, const std::vector<FieldT> &coeff, const FieldT &t)
{
    if (m != coeff.size()) throw DomainSizeException("expected m == coeff.size()");

    FieldT result = FieldT::zero();

    for (int i = m - 1; i >= 0; i--)
    {
        result = (result * t) + coeff[i];
    }

    return result;
}

template<typename FieldT>
FieldT evaluate_lagrange_polynomial(const size_t &m, const std::vector<FieldT> &domain, const FieldT &t, const size_t &idx)
{
    if (m != domain.size()) throw DomainSizeException("expected m == domain.size()");
    if (idx >= m) throw InvalidSizeException("expected idx < m");

    FieldT num = FieldT::one();
    FieldT denom = FieldT::one();

    for (size_t k = 0; k < m; ++k)
    {
        if (k == idx)
        {
            continue;
        }

        num *= t - domain[k];
        denom *= domain[idx] - domain[k];
    }

    return num * denom.inverse();
}

} // libfqfft

#endif // NAIVE_EVALUATE_TCC_
