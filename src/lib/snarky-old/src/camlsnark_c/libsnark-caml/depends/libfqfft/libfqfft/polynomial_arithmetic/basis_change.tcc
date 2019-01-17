/** @file
 *****************************************************************************

 Implementation of interfaces for basis change routines.

 See basis_change.hpp .

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef BASIS_CHANGE_TCC_
#define BASIS_CHANGE_TCC_

#include <algorithm>

#include <libfqfft/evaluation_domain/domains/basic_radix2_domain_aux.hpp>
#include <libfqfft/polynomial_arithmetic/basic_operations.hpp>
#include <libfqfft/polynomial_arithmetic/xgcd.hpp>

namespace libfqfft {

template<typename FieldT>
void compute_subproduct_tree(const size_t &m, std::vector< std::vector < std::vector <FieldT> > > &T)
{
    if (T.size() != m + 1) T.resize(m + 1);

    /*
     * Subproduct tree T is represented as a 2-dimensional array T_{i, j}.
     * T_{i, j} = product_{l = [2^i * j] to [2^i * (j+1) - 1]} (x - x_l)
     * Note: n = 2^m.
     */

    /* Precompute the first row. */
    T[0] = std::vector< std::vector<FieldT> >(pow(2, m));
    for (int j = 0; j < pow(2, m); j++)
    {
        T[0][j] = std::vector<FieldT>(2, FieldT::one());
        T[0][j][0] = FieldT(-j);
    }
    
    std::vector<FieldT> a;
    std::vector<FieldT> b;

    size_t index = 0;
    for (int i = 1; i <= m; i++)
    {
        T[i] = std::vector<std::vector<FieldT> >(pow(2, m-i));
        for (int j = 0; j < pow(2, m-i); j++)
        {
            a = T[i-1][index];
            index++;
            
            b = T[i-1][index];
            index++;

            _polynomial_multiplication(T[i][j], a, b);
        }
        index = 0;
    }
}

template<typename FieldT>
void monomial_to_newton_basis(std::vector<FieldT> &a, const std::vector<std::vector<std::vector<FieldT> > > &T, const size_t &n)
{
    int m = log2(n);
    if (T.size() != m + 1) throw DomainSizeException("expected T.size() == m + 1");

    /* MonomialToNewton */
    std::vector<FieldT> I(T[m][0]);
    _reverse(I, n);

    std::vector<FieldT> mod(n + 1, FieldT::zero());
    mod[n] = FieldT::one();

    _polynomial_xgcd(mod, I, mod, mod, I);

    I.resize(n);

    std::vector<FieldT> Q(_polynomial_multiplication_transpose(n - 1, I, a));
    _reverse(Q, n);

    /* TNewtonToMonomial */
    std::vector< std::vector<FieldT> > c(n);
    c[0] = Q;

    size_t row_length;
    size_t c_vec;
    for (int i = m - 1; i >= 0; i--)
    {
        row_length = T[i].size() - 1;
        c_vec = pow(2, i);

        for (int j = pow(2, m - i - 1) - 1; j >= 0; j--)
        {
            c[2*j+1] = _polynomial_multiplication_transpose(pow(2, i) - 1, T[i][row_length - 2*j], c[j]);
            c[2*j] = c[j];
            c[2*j].resize(c_vec);
        }
    }

    /* Store Computed Newton Basis Coefficients */
    int j = 0;
    for (int i = c.size() - 1; i >= 0; i--) a[j++] = c[i][0];
}

template<typename FieldT>
void newton_to_monomial_basis(std::vector<FieldT> &a, const std::vector<std::vector<std::vector<FieldT> > > &T, const size_t &n)
{
    int m = log2(n);
    if (T.size() != m + 1) throw DomainSizeException("expected T.size() == m + 1");

    std::vector < std::vector <FieldT> > f(n);
    for (int i = 0; i < n; i++)
    {
        f[i] = std::vector<FieldT>(1, a[i]);
    }
    
    /* NewtonToMonomial */
    std::vector<FieldT> temp(1, FieldT::zero());
    for (int i = 0; i < m; i++)
    {
        for (int j = 0; j < pow(2, m - i - 1); j++)
        {
            _polynomial_multiplication(temp, T[i][2*j], f[2*j + 1]);
            _polynomial_addition(f[j], f[2*j], temp);
        }
    }

    a = f[0];
}

template<typename FieldT>
void monomial_to_newton_basis_geometric(std::vector<FieldT> &a,
                                        const std::vector<FieldT> &geometric_sequence,
                                        const std::vector<FieldT> &geometric_triangular_sequence,
                                        const size_t &n)
{
    std::vector<FieldT> u(n, FieldT::zero());
    std::vector<FieldT> w(n, FieldT::zero());
    std::vector<FieldT> z(n, FieldT::zero());
    std::vector<FieldT> f(n, FieldT::zero());
    u[0] = FieldT::one();
    w[0] = a[0];
    z[0] = FieldT::one();
    f[0] = a[0];

    for (size_t i = 1; i < n; i++)
    {
        u[i] = u[i-1] * geometric_sequence[i] * (FieldT::one() - geometric_sequence[i]).inverse();
        w[i] = a[i] * (u[i].inverse());
        z[i] = u[i] * geometric_triangular_sequence[i].inverse();
        f[i] = w[i] * geometric_triangular_sequence[i];

        if (i % 2 == 1)
        {
          z[i] = -z[i];
          f[i] = -f[i];
        }
    }

    w = _polynomial_multiplication_transpose(n - 1, z, f);

#ifdef MULTICORE
    #pragma omp parallel for
#endif
    for (size_t i = 0; i < n; i++)
    {
        a[i] = w[i] * z[i];
    }
}

template<typename FieldT>
void newton_to_monomial_basis_geometric(std::vector<FieldT> &a,
                                        const std::vector<FieldT> &geometric_sequence,
                                        const std::vector<FieldT> &geometric_triangular_sequence,
                                        const size_t &n)
{
    std::vector<FieldT> v(n, FieldT::zero());
    std::vector<FieldT> u(n, FieldT::zero());
    std::vector<FieldT> w(n, FieldT::zero());
    std::vector<FieldT> z(n, FieldT::zero());
    v[0] = a[0];
    u[0] = FieldT::one();
    w[0] = a[0];
    z[0] = FieldT::one();

    for (size_t i = 1; i < n; i++)
    {
        v[i] = a[i] * geometric_triangular_sequence[i];
        if (i % 2 == 1) v[i] = -v[i];

        u[i] = u[i-1] * geometric_sequence[i] * (FieldT::one() - geometric_sequence[i]).inverse();
        w[i] = v[i] * u[i].inverse();

        z[i] = u[i] * geometric_triangular_sequence[i].inverse();
        if (i % 2 == 1) z[i] = -z[i];
    }

    w = _polynomial_multiplication_transpose(n - 1, u, w);

#ifdef MULTICORE
    #pragma omp parallel for
#endif
    for (size_t i = 0; i < n; i++)
    {
        a[i] = w[i] * z[i];
    }
}

} // libfqfft

#endif // BASIS_CHANGE_TCC_
