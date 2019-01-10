/** @file
 *****************************************************************************

 Declaration of interfaces for the "basic radix-2" evaluation domain.

 Roughly, the domain has size m = 2^k and consists of the m-th roots of unity.

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef BASIC_RADIX2_DOMAIN_HPP_
#define BASIC_RADIX2_DOMAIN_HPP_

#include <vector>

#include <libfqfft/evaluation_domain/evaluation_domain.hpp>

namespace libfqfft {

template<typename FieldT>
class basic_radix2_domain : public evaluation_domain<FieldT> {
public:

    FieldT omega;

    basic_radix2_domain(const size_t m, bool &err);

    void FFT(std::vector<FieldT> &a);
    void iFFT(std::vector<FieldT> &a);
    void cosetFFT(std::vector<FieldT> &a, const FieldT &g);
    void icosetFFT(std::vector<FieldT> &a, const FieldT &g);
    std::vector<FieldT> evaluate_all_lagrange_polynomials(const FieldT &t);
    FieldT get_domain_element(const size_t idx);
    FieldT compute_vanishing_polynomial(const FieldT &t);
    void add_poly_Z(const FieldT &coeff, std::vector<FieldT> &H);
    void divide_by_Z_on_coset(std::vector<FieldT> &P);

};

} // libfqfft

#include <libfqfft/evaluation_domain/domains/basic_radix2_domain.tcc>

#endif // BASIC_RADIX2_DOMAIN_HPP_
