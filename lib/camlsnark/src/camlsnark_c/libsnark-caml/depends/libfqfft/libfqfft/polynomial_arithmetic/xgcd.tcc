/** @file
 *****************************************************************************

 Implementation of interfaces for extended GCD routines.

 See xgcd.hpp .
 
 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef XGCD_TCC_
#define XGCD_TCC_

#include <algorithm>

#include <libfqfft/evaluation_domain/domains/basic_radix2_domain_aux.hpp>
#include <libfqfft/polynomial_arithmetic/basic_operations.hpp>

namespace libfqfft {

template<typename FieldT>
void _polynomial_xgcd(const std::vector<FieldT> &a, const std::vector<FieldT> &b, std::vector<FieldT> &g, std::vector<FieldT> &u, std::vector<FieldT> &v)
{
    if (_is_zero(b))
    {
        g = a;
        u = std::vector<FieldT>(1, FieldT::one());
        v = std::vector<FieldT>(1, FieldT::zero());
        return;
    }

    std::vector<FieldT> U(1, FieldT::one());
    std::vector<FieldT> V1(1, FieldT::zero());
    std::vector<FieldT> G(a);
    std::vector<FieldT> V3(b);

    std::vector<FieldT> Q(1, FieldT::zero());
    std::vector<FieldT> R(1, FieldT::zero());
    std::vector<FieldT> T(1, FieldT::zero());

    while (!_is_zero(V3))
    {
        _polynomial_division(Q, R, G, V3);
        _polynomial_multiplication(G, V1, Q);
        _polynomial_subtraction(T, U, G);

        U = V1;
        G = V3;
        V1 = T;
        V3 = R;
    }

    _polynomial_multiplication(V3, a, U);
    _polynomial_subtraction(V3, G, V3);
    _polynomial_division(V1, R, V3, b);

    FieldT lead_coeff = G.back().inverse();
    std::transform(G.begin(), G.end(), G.begin(), std::bind1st(std::multiplies<FieldT>(), lead_coeff));
    std::transform(U.begin(), U.end(), U.begin(), std::bind1st(std::multiplies<FieldT>(), lead_coeff));
    std::transform(V1.begin(), V1.end(), V1.begin(), std::bind1st(std::multiplies<FieldT>(), lead_coeff));

    g = G;
    u = U;
    v = V1;
}

} // libfqfft

#endif // XGCD_TCC_
