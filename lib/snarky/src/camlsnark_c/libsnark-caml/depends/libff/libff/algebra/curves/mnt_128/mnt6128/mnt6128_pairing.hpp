/** @file
 *****************************************************************************

 Declaration of interfaces for pairing operations on MNT6.

 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef MNT6128_PAIRING_HPP_
#define MNT6128_PAIRING_HPP_

#include <vector>

#include <libff/algebra/curves/mnt_128/mnt6128/mnt6128_init.hpp>

namespace libff {

/* final exponentiation */

mnt6128_Fq6 mnt6128_final_exponentiation_last_chunk(const mnt6128_Fq6 &elt,
                                              const mnt6128_Fq6 &elt_inv);
mnt6128_Fq6 mnt6128_final_exponentiation_first_chunk(const mnt6128_Fq6 &elt,
                                               const mnt6128_Fq6 &elt_inv);
mnt6128_GT mnt6128_final_exponentiation(const mnt6128_Fq6 &elt);

/* affine ate miller loop */

struct mnt6128_affine_ate_G1_precomputation {
    mnt6128_Fq PX;
    mnt6128_Fq PY;
    mnt6128_Fq3 PY_twist_squared;
};

struct mnt6128_affine_ate_coeffs {
    // TODO: trim (not all of them are needed)
    mnt6128_Fq3 old_RX;
    mnt6128_Fq3 old_RY;
    mnt6128_Fq3 gamma;
    mnt6128_Fq3 gamma_twist;
    mnt6128_Fq3 gamma_X;
};

struct mnt6128_affine_ate_G2_precomputation {
    mnt6128_Fq3 QX;
    mnt6128_Fq3 QY;
    std::vector<mnt6128_affine_ate_coeffs> coeffs;
};

mnt6128_affine_ate_G1_precomputation mnt6128_affine_ate_precompute_G1(const mnt6128_G1& P);
mnt6128_affine_ate_G2_precomputation mnt6128_affine_ate_precompute_G2(const mnt6128_G2& Q);

mnt6128_Fq6 mnt6128_affine_ate_miller_loop(const mnt6128_affine_ate_G1_precomputation &prec_P,
                                     const mnt6128_affine_ate_G2_precomputation &prec_Q);

/* ate pairing */

struct mnt6128_ate_G1_precomp {
    mnt6128_Fq PX;
    mnt6128_Fq PY;
    mnt6128_Fq3 PX_twist;
    mnt6128_Fq3 PY_twist;

    bool operator==(const mnt6128_ate_G1_precomp &other) const;
    friend std::ostream& operator<<(std::ostream &out, const mnt6128_ate_G1_precomp &prec_P);
    friend std::istream& operator>>(std::istream &in, mnt6128_ate_G1_precomp &prec_P);
};

struct mnt6128_ate_dbl_coeffs {
    mnt6128_Fq3 c_H;
    mnt6128_Fq3 c_4C;
    mnt6128_Fq3 c_J;
    mnt6128_Fq3 c_L;

    bool operator==(const mnt6128_ate_dbl_coeffs &other) const;
    friend std::ostream& operator<<(std::ostream &out, const mnt6128_ate_dbl_coeffs &dc);
    friend std::istream& operator>>(std::istream &in, mnt6128_ate_dbl_coeffs &dc);
};

struct mnt6128_ate_add_coeffs {
    mnt6128_Fq3 c_L1;
    mnt6128_Fq3 c_RZ;

    bool operator==(const mnt6128_ate_add_coeffs &other) const;
    friend std::ostream& operator<<(std::ostream &out, const mnt6128_ate_add_coeffs &dc);
    friend std::istream& operator>>(std::istream &in, mnt6128_ate_add_coeffs &dc);
};

struct mnt6128_ate_G2_precomp {
    mnt6128_Fq3 QX;
    mnt6128_Fq3 QY;
    mnt6128_Fq3 QY2;
    mnt6128_Fq3 QX_over_twist;
    mnt6128_Fq3 QY_over_twist;
    std::vector<mnt6128_ate_dbl_coeffs> dbl_coeffs;
    std::vector<mnt6128_ate_add_coeffs> add_coeffs;

    bool operator==(const mnt6128_ate_G2_precomp &other) const;
    friend std::ostream& operator<<(std::ostream &out, const mnt6128_ate_G2_precomp &prec_Q);
    friend std::istream& operator>>(std::istream &in, mnt6128_ate_G2_precomp &prec_Q);
};

mnt6128_ate_G1_precomp mnt6128_ate_precompute_G1(const mnt6128_G1& P);
mnt6128_ate_G2_precomp mnt6128_ate_precompute_G2(const mnt6128_G2& Q);

mnt6128_Fq6 mnt6128_ate_miller_loop(const mnt6128_ate_G1_precomp &prec_P,
                              const mnt6128_ate_G2_precomp &prec_Q);
mnt6128_Fq6 mnt6128_ate_double_miller_loop(const mnt6128_ate_G1_precomp &prec_P1,
                                     const mnt6128_ate_G2_precomp &prec_Q1,
                                     const mnt6128_ate_G1_precomp &prec_P2,
                                     const mnt6128_ate_G2_precomp &prec_Q2);

mnt6128_Fq6 mnt6128_ate_pairing(const mnt6128_G1& P,
                          const mnt6128_G2 &Q);
mnt6128_GT mnt6128_ate_reduced_pairing(const mnt6128_G1 &P,
                                 const mnt6128_G2 &Q);

/* choice of pairing */

typedef mnt6128_ate_G1_precomp mnt6128_G1_precomp;
typedef mnt6128_ate_G2_precomp mnt6128_G2_precomp;

mnt6128_G1_precomp mnt6128_precompute_G1(const mnt6128_G1& P);

mnt6128_G2_precomp mnt6128_precompute_G2(const mnt6128_G2& Q);

mnt6128_Fq6 mnt6128_miller_loop(const mnt6128_G1_precomp &prec_P,
                          const mnt6128_G2_precomp &prec_Q);

mnt6128_Fq6 mnt6128_double_miller_loop(const mnt6128_G1_precomp &prec_P1,
                                 const mnt6128_G2_precomp &prec_Q1,
                                 const mnt6128_G1_precomp &prec_P2,
                                 const mnt6128_G2_precomp &prec_Q2);

mnt6128_Fq6 mnt6128_pairing(const mnt6128_G1& P,
                      const mnt6128_G2 &Q);

mnt6128_GT mnt6128_reduced_pairing(const mnt6128_G1 &P,
                             const mnt6128_G2 &Q);

mnt6128_GT mnt6128_affine_reduced_pairing(const mnt6128_G1 &P,
                                    const mnt6128_G2 &Q);

} // libff

#endif // MNT6128_PAIRING_HPP_
