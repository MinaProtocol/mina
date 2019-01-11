/** @file
 *****************************************************************************

 Declaration of interfaces for the "arithmetic sequence" evaluation domain.

 These functions use an arithmetic sequence of size m to perform evaluation.

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef ARITHMETIC_SEQUENCE_DOMAIN_HPP
#define ARITHMETIC_SEQUENCE_DOMAIN_HPP

#include <libfqfft/evaluation_domain/evaluation_domain.hpp>

namespace libfqfft {

  template<typename FieldT>
  class arithmetic_sequence_domain : public evaluation_domain<FieldT> {
  public:
    
    bool precomputation_sentinel;
    std::vector<std::vector<std::vector<FieldT> > > subproduct_tree;
    std::vector<FieldT> arithmetic_sequence;
    FieldT arithmetic_generator;
    void do_precomputation();

    arithmetic_sequence_domain(const size_t m, bool &err);

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

#include <libfqfft/evaluation_domain/domains/arithmetic_sequence_domain.tcc>

#endif // ARITHMETIC_SEQUENCE_DOMAIN_HPP
