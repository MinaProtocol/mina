/** @file
 *****************************************************************************

 Implementation of interfaces for the "arithmetic sequence" evaluation domain.

 See arithmetic_sequence_domain.hpp .

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef ARITHMETIC_SEQUENCE_DOMAIN_TCC_
#define ARITHMETIC_SEQUENCE_DOMAIN_TCC_

#include <libfqfft/evaluation_domain/domains/basic_radix2_domain_aux.hpp>
#include <libfqfft/polynomial_arithmetic/basis_change.hpp>

#ifdef MULTICORE
#include <omp.h>
#endif

namespace libfqfft {

template<typename FieldT>
arithmetic_sequence_domain<FieldT>::arithmetic_sequence_domain(const size_t m, bool &err) : evaluation_domain<FieldT>(m)
{
  if (m <= 1) {
    err = true;
    precomputation_sentinel = false;
    return;
  }

  if (FieldT::arithmetic_generator() == FieldT::zero()) {
    err = true;
    precomputation_sentinel = false;
    return;
  }

  precomputation_sentinel = 0;
}

template<typename FieldT>
void arithmetic_sequence_domain<FieldT>::FFT(std::vector<FieldT> &a)
{
  if (a.size() != this->m) throw DomainSizeException("arithmetic: expected a.size() == this->m");

  if (!this->precomputation_sentinel) do_precomputation();

  /* Monomial to Newton */
  monomial_to_newton_basis(a, this->subproduct_tree, this->m);
  
  /* Newton to Evaluation */
  std::vector<FieldT> S(this->m); /* i! * arithmetic_generator */
  S[0] = FieldT::one();

  FieldT factorial = FieldT::one();
  for (size_t i = 1; i < this->m; i++)
  {
    factorial *= FieldT(i);
    S[i] = (factorial * this->arithmetic_generator).inverse();
  }

  _polynomial_multiplication(a, a, S);
  a.resize(this->m);

#ifdef MULTICORE
  #pragma omp parallel for
#endif
  for (size_t i = 0; i < this->m; i++)
  {
    a[i] *= S[i].inverse();
  }
}

template<typename FieldT>
void arithmetic_sequence_domain<FieldT>::iFFT(std::vector<FieldT> &a)
{
  if (a.size() != this->m) throw DomainSizeException("arithmetic: expected a.size() == this->m");
  
  if (!this->precomputation_sentinel) do_precomputation();

  /* Interpolation to Newton */
  std::vector<FieldT> S(this->m); /* i! * arithmetic_generator */
  S[0] = FieldT::one();

  std::vector<FieldT> W(this->m);
  W[0] = a[0] * S[0];

  FieldT factorial = FieldT::one();
  for (size_t i = 1; i < this->m; i++)
  {
    factorial *= FieldT(i);
    S[i] = (factorial * this->arithmetic_generator).inverse();
    W[i] = a[i] * S[i];
    if (i % 2 == 1) S[i] = -S[i];
  }

  _polynomial_multiplication(a, W, S);
  a.resize(this->m);

  /* Newton to Monomial */
  newton_to_monomial_basis(a, this->subproduct_tree, this->m);
}

template<typename FieldT>
void arithmetic_sequence_domain<FieldT>::cosetFFT(std::vector<FieldT> &a, const FieldT &g)
{
  _multiply_by_coset(a, g);
  FFT(a);
}

template<typename FieldT>
void arithmetic_sequence_domain<FieldT>::icosetFFT(std::vector<FieldT> &a, const FieldT &g)
{
  iFFT(a);
  _multiply_by_coset(a, g.inverse());
}

template<typename FieldT>
std::vector<FieldT> arithmetic_sequence_domain<FieldT>::evaluate_all_lagrange_polynomials(const FieldT &t)
{
  /* Compute Lagrange polynomial of size m, with m+1 points (x_0, y_0), ... ,(x_m, y_m) */
  /* Evaluate for x = t */
  /* Return coeffs for each l_j(x) = (l / l_i[j]) * w[j] */

  if (!this->precomputation_sentinel) do_precomputation();

  /**
   * If t equals one of the arithmetic progression values,
   * then output 1 at the right place, and 0 elsewhere.
   */
  for (size_t i = 0; i < this->m; ++i)
  {
    if (this->arithmetic_sequence[i] == t) // i.e., t equals this->arithmetic_sequence[i]
    {
      std::vector<FieldT> res(this->m, FieldT::zero());
      res[i] = FieldT::one();
      return res;
    }
  }

  /**
   * Otherwise, if t does not equal any of the arithmetic progression values,
   * then compute each Lagrange coefficient.
   */
  std::vector<FieldT> l(this->m);
  l[0] = t - this->arithmetic_sequence[0];

  FieldT l_vanish = l[0];
  FieldT g_vanish = FieldT::one();

  for (size_t i = 1; i < this->m; i++)
  {
    l[i] = t - this->arithmetic_sequence[i];
    l_vanish *= l[i];
    g_vanish *= -this->arithmetic_sequence[i];
  }

  std::vector<FieldT> w(this->m);
  w[0] = g_vanish.inverse() * (this->arithmetic_generator^(this->m-1));
  
  l[0] = l_vanish * l[0].inverse() * w[0];
  for (size_t i = 1; i < this->m; i++)
  {
    FieldT num = this->arithmetic_sequence[i-1] - this->arithmetic_sequence[this->m-1];
    w[i] = w[i-1] * num * this->arithmetic_sequence[i].inverse();
    l[i] = l_vanish * l[i].inverse() * w[i];
  }

  return l;
}

template<typename FieldT>
FieldT arithmetic_sequence_domain<FieldT>::get_domain_element(const size_t idx)
{
  if (!this->precomputation_sentinel) do_precomputation();

  return this->arithmetic_sequence[idx];
}

template<typename FieldT>
FieldT arithmetic_sequence_domain<FieldT>::compute_vanishing_polynomial(const FieldT &t)
{
  if (!this->precomputation_sentinel) do_precomputation();

  /* Notes: Z = prod_{i = 0 to m} (t - a[i]) */
  FieldT Z = FieldT::one();
  for (size_t i = 0; i < this->m; i++)
  {
    Z *= (t - this->arithmetic_sequence[i]);
  }
  return Z;
}

template<typename FieldT>
void arithmetic_sequence_domain<FieldT>::add_poly_Z(const FieldT &coeff, std::vector<FieldT> &H)
{
  if (H.size() != this->m+1) throw DomainSizeException("arithmetic: expected H.size() == this->m+1");

  if (!this->precomputation_sentinel) do_precomputation();

  std::vector<FieldT> x(2, FieldT::zero());
  x[0] = -this->arithmetic_sequence[0];
  x[1] = FieldT::one();

  std::vector<FieldT> t(2, FieldT::zero());

  for (size_t i = 1; i < this->m+1; i++)
  {
    t[0] = -this->arithmetic_sequence[i];
    t[1] = FieldT::one();

    _polynomial_multiplication(x, x, t);
  }

#ifdef MULTICORE
  #pragma omp parallel for
#endif
  for (size_t i = 0; i < this->m+1; i++)
  {
    H[i] += (x[i] * coeff);
  }
}

template<typename FieldT>
void arithmetic_sequence_domain<FieldT>::divide_by_Z_on_coset(std::vector<FieldT> &P)
{
  const FieldT coset = this->arithmetic_generator; /* coset in arithmetic sequence? */
  const FieldT Z_inverse_at_coset = this->compute_vanishing_polynomial(coset).inverse();
  for (size_t i = 0; i < this->m; ++i)
  {
    P[i] *= Z_inverse_at_coset;
  }
}

template<typename FieldT>
void arithmetic_sequence_domain<FieldT>::do_precomputation()
{
  compute_subproduct_tree(log2(this->m), this->subproduct_tree);

  this->arithmetic_generator = FieldT::arithmetic_generator();

  this->arithmetic_sequence = std::vector<FieldT>(this->m);
  for (size_t i = 0; i < this->m; i++)
  {
    this->arithmetic_sequence[i] = this->arithmetic_generator * FieldT(i);
  }

  this->precomputation_sentinel = 1;
}

} // libfqfft

#endif // ARITHMETIC_SEQUENCE_DOMAIN_TCC_
