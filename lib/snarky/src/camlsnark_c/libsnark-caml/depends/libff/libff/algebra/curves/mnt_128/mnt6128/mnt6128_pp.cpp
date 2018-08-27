/** @file
 *****************************************************************************

 Implementation of interfaces for public parameters of MNT6.

 See mnt6128_pp.hpp .

 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#include <libff/algebra/curves/mnt_128/mnt6128/mnt6128_pp.hpp>

namespace libff {

void mnt6128_pp::init_public_params()
{
    init_mnt6128_params();
}

mnt6128_GT mnt6128_pp::final_exponentiation(const mnt6128_Fq6 &elt)
{
    return mnt6128_final_exponentiation(elt);
}

mnt6128_G1_precomp mnt6128_pp::precompute_G1(const mnt6128_G1 &P)
{
    return mnt6128_precompute_G1(P);
}

mnt6128_G2_precomp mnt6128_pp::precompute_G2(const mnt6128_G2 &Q)
{
    return mnt6128_precompute_G2(Q);
}


mnt6128_Fq6 mnt6128_pp::miller_loop(const mnt6128_G1_precomp &prec_P,
                              const mnt6128_G2_precomp &prec_Q)
{
    return mnt6128_miller_loop(prec_P, prec_Q);
}

mnt6128_affine_ate_G1_precomputation mnt6128_pp::affine_ate_precompute_G1(const mnt6128_G1 &P)
{
    return mnt6128_affine_ate_precompute_G1(P);
}

mnt6128_affine_ate_G2_precomputation mnt6128_pp::affine_ate_precompute_G2(const mnt6128_G2 &Q)
{
    return mnt6128_affine_ate_precompute_G2(Q);
}

mnt6128_Fq6 mnt6128_pp::affine_ate_miller_loop(const mnt6128_affine_ate_G1_precomputation &prec_P,
                                         const mnt6128_affine_ate_G2_precomputation &prec_Q)
{
    return mnt6128_affine_ate_miller_loop(prec_P, prec_Q);
}

mnt6128_Fq6 mnt6128_pp::double_miller_loop(const mnt6128_G1_precomp &prec_P1,
                                     const mnt6128_G2_precomp &prec_Q1,
                                     const mnt6128_G1_precomp &prec_P2,
                                     const mnt6128_G2_precomp &prec_Q2)
{
    return mnt6128_double_miller_loop(prec_P1, prec_Q1, prec_P2, prec_Q2);
}

mnt6128_Fq6 mnt6128_pp::affine_ate_e_over_e_miller_loop(const mnt6128_affine_ate_G1_precomputation &prec_P1,
                                                  const mnt6128_affine_ate_G2_precomputation &prec_Q1,
                                                  const mnt6128_affine_ate_G1_precomputation &prec_P2,
                                                  const mnt6128_affine_ate_G2_precomputation &prec_Q2)
{
    return mnt6128_affine_ate_miller_loop(prec_P1, prec_Q1) * mnt6128_affine_ate_miller_loop(prec_P2, prec_Q2).unitary_inverse();
}

mnt6128_Fq6 mnt6128_pp::affine_ate_e_times_e_over_e_miller_loop(const mnt6128_affine_ate_G1_precomputation &prec_P1,
                                                          const mnt6128_affine_ate_G2_precomputation &prec_Q1,
                                                          const mnt6128_affine_ate_G1_precomputation &prec_P2,
                                                          const mnt6128_affine_ate_G2_precomputation &prec_Q2,
                                                          const mnt6128_affine_ate_G1_precomputation &prec_P3,
                                                          const mnt6128_affine_ate_G2_precomputation &prec_Q3)
{
    return ((mnt6128_affine_ate_miller_loop(prec_P1, prec_Q1) * mnt6128_affine_ate_miller_loop(prec_P2, prec_Q2)) *
            mnt6128_affine_ate_miller_loop(prec_P3, prec_Q3).unitary_inverse());
}

mnt6128_Fq6 mnt6128_pp::pairing(const mnt6128_G1 &P,
                          const mnt6128_G2 &Q)
{
    return mnt6128_pairing(P, Q);
}

mnt6128_Fq6 mnt6128_pp::reduced_pairing(const mnt6128_G1 &P,
                                  const mnt6128_G2 &Q)
{
    return mnt6128_reduced_pairing(P, Q);
}

mnt6128_Fq6 mnt6128_pp::affine_reduced_pairing(const mnt6128_G1 &P,
                                         const mnt6128_G2 &Q)
{
    return mnt6128_affine_reduced_pairing(P, Q);
}

} // libff
