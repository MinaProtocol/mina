/** @file
 *****************************************************************************

 Implementation of interfaces for public parameters of MNT4.

 See mnt4128_pp.hpp .

 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#include <libff/algebra/curves/mnt_128/mnt4128/mnt4128_pp.hpp>

namespace libff {

void mnt4128_pp::init_public_params()
{
    init_mnt4128_params();
}

mnt4128_GT mnt4128_pp::final_exponentiation(const mnt4128_Fq4 &elt)
{
    return mnt4128_final_exponentiation(elt);
}

mnt4128_G1_precomp mnt4128_pp::precompute_G1(const mnt4128_G1 &P)
{
    return mnt4128_precompute_G1(P);
}

mnt4128_G2_precomp mnt4128_pp::precompute_G2(const mnt4128_G2 &Q)
{
    return mnt4128_precompute_G2(Q);
}

mnt4128_Fq4 mnt4128_pp::miller_loop(const mnt4128_G1_precomp &prec_P,
                              const mnt4128_G2_precomp &prec_Q)
{
    return mnt4128_miller_loop(prec_P, prec_Q);
}

mnt4128_affine_ate_G1_precomputation mnt4128_pp::affine_ate_precompute_G1(const mnt4128_G1 &P)
{
    return mnt4128_affine_ate_precompute_G1(P);
}

mnt4128_affine_ate_G2_precomputation mnt4128_pp::affine_ate_precompute_G2(const mnt4128_G2 &Q)
{
    return mnt4128_affine_ate_precompute_G2(Q);
}

mnt4128_Fq4 mnt4128_pp::affine_ate_miller_loop(const mnt4128_affine_ate_G1_precomputation &prec_P,
                                         const mnt4128_affine_ate_G2_precomputation &prec_Q)
{
    return mnt4128_affine_ate_miller_loop(prec_P, prec_Q);
}

mnt4128_Fq4 mnt4128_pp::affine_ate_e_over_e_miller_loop(const mnt4128_affine_ate_G1_precomputation &prec_P1,
                                                  const mnt4128_affine_ate_G2_precomputation &prec_Q1,
                                                  const mnt4128_affine_ate_G1_precomputation &prec_P2,
                                                  const mnt4128_affine_ate_G2_precomputation &prec_Q2)
{
    return mnt4128_affine_ate_miller_loop(prec_P1, prec_Q1) * mnt4128_affine_ate_miller_loop(prec_P2, prec_Q2).unitary_inverse();
}

mnt4128_Fq4 mnt4128_pp::affine_ate_e_times_e_over_e_miller_loop(const mnt4128_affine_ate_G1_precomputation &prec_P1,
                                                          const mnt4128_affine_ate_G2_precomputation &prec_Q1,
                                                          const mnt4128_affine_ate_G1_precomputation &prec_P2,
                                                          const mnt4128_affine_ate_G2_precomputation &prec_Q2,
                                                          const mnt4128_affine_ate_G1_precomputation &prec_P3,
                                                          const mnt4128_affine_ate_G2_precomputation &prec_Q3)
{
    return ((mnt4128_affine_ate_miller_loop(prec_P1, prec_Q1) * mnt4128_affine_ate_miller_loop(prec_P2, prec_Q2)) *
            mnt4128_affine_ate_miller_loop(prec_P3, prec_Q3).unitary_inverse());
}

mnt4128_Fq4 mnt4128_pp::double_miller_loop(const mnt4128_G1_precomp &prec_P1,
                                     const mnt4128_G2_precomp &prec_Q1,
                                     const mnt4128_G1_precomp &prec_P2,
                                     const mnt4128_G2_precomp &prec_Q2)
{
    return mnt4128_double_miller_loop(prec_P1, prec_Q1, prec_P2, prec_Q2);
}

mnt4128_Fq4 mnt4128_pp::pairing(const mnt4128_G1 &P,
                          const mnt4128_G2 &Q)
{
    return mnt4128_pairing(P, Q);
}

mnt4128_Fq4 mnt4128_pp::reduced_pairing(const mnt4128_G1 &P,
                                  const mnt4128_G2 &Q)
{
    return mnt4128_reduced_pairing(P, Q);
}

mnt4128_Fq4 mnt4128_pp::affine_reduced_pairing(const mnt4128_G1 &P,
                                         const mnt4128_G2 &Q)
{
    return mnt4128_affine_reduced_pairing(P, Q);
}

} // libff
