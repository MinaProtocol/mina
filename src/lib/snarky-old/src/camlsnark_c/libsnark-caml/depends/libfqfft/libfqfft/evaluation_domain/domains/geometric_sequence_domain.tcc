/** @file
 *****************************************************************************

 Implementation of interfaces for the "geometric sequence" evaluation domain.

 See geometric_sequence_domain.hpp .

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef GEOMETRIC_SEQUENCE_DOMAIN_TCC_
#define GEOMETRIC_SEQUENCE_DOMAIN_TCC_

#include <libfqfft/evaluation_domain/domains/basic_radix2_domain_aux.hpp>
#include <libfqfft/polynomial_arithmetic/basis_change.hpp>

#ifdef MULTICORE
#include <omp.h>
#endif

namespace libfqfft {

template<typename FieldT>
geometric_sequence_domain<FieldT>::geometric_sequence_domain(const size_t m, bool &err) : evaluation_domain<FieldT>(m)
{
  bool precomputation_sentinel;

  if (m <= 1) {
    err = true;
    precomputation_sentinel = false;
    return;
  }

  if (FieldT::geometric_generator() == FieldT::zero()) {
    err = true;
    precomputation_sentinel = false;
    return;
  }

  precomputation_sentinel = 0;
}

template<typename FieldT>
void geometric_sequence_domain<FieldT>::FFT(std::vector<FieldT> &a)
{ 
  if (a.size() != this->m) throw DomainSizeException("geometric: expected a.size() == this->m");

  if (!this->precomputation_sentinel) do_precomputation();

  monomial_to_newton_basis_geometric(a, this->geometric_sequence, this->geometric_triangular_sequence, this->m);

  /* Newton to Evaluation */
  std::vector<FieldT> T(this->m);
  T[0] = FieldT::one();

  std::vector<FieldT> g(this->m);
  g[0] = a[0];

  for (size_t i = 1; i < this->m; i++)
  {
    T[i] = T[i-1] * (this->geometric_sequence[i] - FieldT::one()).inverse();
    g[i] = this->geometric_triangular_sequence[i] * a[i];
  }

  _polynomial_multiplication(a, g, T);
  a.resize(this->m);

#ifdef MULTICORE
  #pragma omp parallel for
#endif
  for (size_t i = 0; i < this->m; i++)
  {
    a[i] *= T[i].inverse();
  }
}

template<typename FieldT>
void geometric_sequence_domain<FieldT>::iFFT(std::vector<FieldT> &a)
{
  if (a.size() != this->m) throw DomainSizeException("geometric: expected a.size() == this->m");
  
  if (!this->precomputation_sentinel) do_precomputation();

  /* Interpolation to Newton */
  std::vector<FieldT> T(this->m);
  T[0] = FieldT::one();

  std::vector<FieldT> W(this->m);
  W[0] = a[0] * T[0];

  FieldT prev_T = T[0];
  for (size_t i = 1; i < this->m; i++)
  {
    prev_T *= (this->geometric_sequence[i] - FieldT::one()).inverse();

    W[i] = a[i] * prev_T;
    T[i] = this->geometric_triangular_sequence[i] * prev_T;
    if (i % 2 == 1) T[i] = -T[i];
  }

  _polynomial_multiplication(a, W, T);
  a.resize(this->m);

#ifdef MULTICORE
  #pragma omp parallel for
#endif
  for (size_t i = 0; i < this->m; i++)
  {
    a[i] *= this->geometric_triangular_sequence[i].inverse();
  }

  newton_to_monomial_basis_geometric(a, this->geometric_sequence, this->geometric_triangular_sequence, this->m);
}

template<typename FieldT>
void geometric_sequence_domain<FieldT>::cosetFFT(std::vector<FieldT> &a, const FieldT &g)
{
  _multiply_by_coset(a, g);
  FFT(a);
}

template<typename FieldT>
void geometric_sequence_domain<FieldT>::icosetFFT(std::vector<FieldT> &a, const FieldT &g)
{
  iFFT(a);
  _multiply_by_coset(a, g.inverse());
}

template<typename FieldT>
std::vector<FieldT> geometric_sequence_domain<FieldT>::evaluate_all_lagrange_polynomials(const FieldT &t)
{
  /* Compute Lagrange polynomial of size m, with m+1 points (x_0, y_0), ... ,(x_m, y_m) */
  /* Evaluate for x = t */
  /* Return coeffs for each l_j(x) = (l / l_i[j]) * w[j] */

  /* for all i: w[i] = (1 / r) * w[i-1] * (1 - a[i]^m-i+1) / (1 - a[i]^-i) */

  if (!this->precomputation_sentinel) do_precomputation();

  /**
   * If t equals one of the geometric progression values,
   * then output 1 at the right place, and 0 elsewhere.
   */
  for (size_t i = 0; i < this->m; ++i)
  {
    if (this->geometric_sequence[i] == t) // i.e., t equals a[i]
    {
      std::vector<FieldT> res(this->m, FieldT::zero());
      res[i] = FieldT::one();
      return res;
    }
  }

  /**
   * Otherwise, if t does not equal any of the geometric progression values,
   * then compute each Lagrange coefficient.
   */
  std::vector<FieldT> l(this->m);
  l[0] = t - this->geometric_sequence[0];

  std::vector<FieldT> g(this->m);
  g[0] = FieldT::zero();

  FieldT l_vanish = l[0];
  FieldT g_vanish = FieldT::one();
  for (size_t i = 1; i < this->m; i++)
  {
    l[i] = t - this->geometric_sequence[i];
    g[i] = FieldT::one() - this->geometric_sequence[i];

    l_vanish *= l[i];
    g_vanish *= g[i];
  }

  FieldT r = this->geometric_sequence[this->m-1].inverse();
  FieldT r_i = r;

  std::vector<FieldT> g_i(this->m);
  g_i[0] = g_vanish.inverse();

  l[0] = l_vanish * l[0].inverse() * g_i[0];
  for (size_t i = 1; i < this->m; i++)
  {
    g_i[i] = g_i[i-1] * g[this->m-i] * -g[i].inverse() * this->geometric_sequence[i];
    l[i] = l_vanish * r_i * l[i].inverse() * g_i[i];
    r_i *= r;
  }

  return l;
}

template<typename FieldT>
FieldT geometric_sequence_domain<FieldT>::get_domain_element(const size_t idx)
{
  if (!this->precomputation_sentinel) do_precomputation();

  return this->geometric_sequence[idx];
}

template<typename FieldT>
FieldT geometric_sequence_domain<FieldT>::compute_vanishing_polynomial(const FieldT &t)
{
  if (!this->precomputation_sentinel) do_precomputation();

  /* Notes: Z = prod_{i = 0 to m} (t - a[i]) */
  /* Better approach: Montgomery Trick + Divide&Conquer/FFT */
  FieldT Z = FieldT::one();
  for (size_t i = 0; i < this->m; i++)
  {
    Z *= (t - this->geometric_sequence[i]);
  }
  return Z;
}

template<typename FieldT>
void geometric_sequence_domain<FieldT>::add_poly_Z(const FieldT &coeff, std::vector<FieldT> &H)
{
  if (H.size() != this->m+1) throw DomainSizeException("geometric: expected H.size() == this->m+1");

  if (!this->precomputation_sentinel) do_precomputation();

  std::vector<FieldT> x(2, FieldT::zero());
  x[0] = -this->geometric_sequence[0];
  x[1] = FieldT::one();

  std::vector<FieldT> t(2, FieldT::zero());

  for (size_t i = 1; i < this->m+1; i++)
  {
    t[0] = -this->geometric_sequence[i];
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
void geometric_sequence_domain<FieldT>::divide_by_Z_on_coset(std::vector<FieldT> &P)
{
  const FieldT coset = FieldT::multiplicative_generator; /* coset in geometric sequence? */
  const FieldT Z_inverse_at_coset = this->compute_vanishing_polynomial(coset).inverse();
  for (size_t i = 0; i < this->m; ++i)
  {
    P[i] *= Z_inverse_at_coset;
  }
}

template<typename FieldT>
void geometric_sequence_domain<FieldT>::do_precomputation()
{
  this->geometric_sequence = std::vector<FieldT>(this->m, FieldT::zero());
  this->geometric_sequence[0] = FieldT::one();

  this->geometric_triangular_sequence = std::vector<FieldT>(this->m, FieldT::zero());
  this->geometric_triangular_sequence[0] = FieldT::one();

  for (size_t i = 1; i < this->m; i++)
  {
    this->geometric_sequence[i] = this->geometric_sequence[i-1] * FieldT::geometric_generator();
    this->geometric_triangular_sequence[i] = this->geometric_triangular_sequence[i-1] * this->geometric_sequence[i-1];
  }

  this->precomputation_sentinel = 1;
}

} // libfqfft

#endif // GEOMETRIC_SEQUENCE_DOMAIN_TCC_
