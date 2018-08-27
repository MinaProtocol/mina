/** @file
 *****************************************************************************

 Declaration of interfaces for public parameters of MNT6.

 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef MNT6128_PP_HPP_
#define MNT6128_PP_HPP_

#include <libff/algebra/curves/mnt_128/mnt6128/mnt6128_g1.hpp>
#include <libff/algebra/curves/mnt_128/mnt6128/mnt6128_g2.hpp>
#include <libff/algebra/curves/mnt_128/mnt6128/mnt6128_init.hpp>
#include <libff/algebra/curves/mnt_128/mnt6128/mnt6128_pairing.hpp>
#include <libff/algebra/curves/public_params.hpp>

namespace libff {

class mnt6128_pp {
public:
    typedef mnt6128_Fr Fp_type;
    typedef mnt6128_G1 G1_type;
    typedef mnt6128_G2 G2_type;
    typedef mnt6128_affine_ate_G1_precomputation affine_ate_G1_precomp_type;
    typedef mnt6128_affine_ate_G2_precomputation affine_ate_G2_precomp_type;
    typedef mnt6128_G1_precomp G1_precomp_type;
    typedef mnt6128_G2_precomp G2_precomp_type;
    typedef mnt6128_Fq Fq_type;
    typedef mnt6128_Fq3 Fqe_type;
    typedef mnt6128_Fq6 Fqk_type;
    typedef mnt6128_GT GT_type;

    static const bool has_affine_pairing = true;

    static void init_public_params();
    static mnt6128_GT final_exponentiation(const mnt6128_Fq6 &elt);
    static mnt6128_G1_precomp precompute_G1(const mnt6128_G1 &P);
    static mnt6128_G2_precomp precompute_G2(const mnt6128_G2 &Q);
    static mnt6128_Fq6 miller_loop(const mnt6128_G1_precomp &prec_P,
                                const mnt6128_G2_precomp &prec_Q);
    static mnt6128_affine_ate_G1_precomputation affine_ate_precompute_G1(const mnt6128_G1 &P);
    static mnt6128_affine_ate_G2_precomputation affine_ate_precompute_G2(const mnt6128_G2 &Q);
    static mnt6128_Fq6 affine_ate_miller_loop(const mnt6128_affine_ate_G1_precomputation &prec_P,
                                           const mnt6128_affine_ate_G2_precomputation &prec_Q);
    static mnt6128_Fq6 affine_ate_e_over_e_miller_loop(const mnt6128_affine_ate_G1_precomputation &prec_P1,
                                                    const mnt6128_affine_ate_G2_precomputation &prec_Q1,
                                                    const mnt6128_affine_ate_G1_precomputation &prec_P2,
                                                    const mnt6128_affine_ate_G2_precomputation &prec_Q2);
    static mnt6128_Fq6 affine_ate_e_times_e_over_e_miller_loop(const mnt6128_affine_ate_G1_precomputation &prec_P1,
                                                            const mnt6128_affine_ate_G2_precomputation &prec_Q1,
                                                            const mnt6128_affine_ate_G1_precomputation &prec_P2,
                                                            const mnt6128_affine_ate_G2_precomputation &prec_Q2,
                                                            const mnt6128_affine_ate_G1_precomputation &prec_P3,
                                                            const mnt6128_affine_ate_G2_precomputation &prec_Q3);
    static mnt6128_Fq6 double_miller_loop(const mnt6128_G1_precomp &prec_P1,
                                       const mnt6128_G2_precomp &prec_Q1,
                                       const mnt6128_G1_precomp &prec_P2,
                                       const mnt6128_G2_precomp &prec_Q2);

    /* the following are used in test files */
    static mnt6128_Fq6 pairing(const mnt6128_G1 &P,
                            const mnt6128_G2 &Q);
    static mnt6128_Fq6 reduced_pairing(const mnt6128_G1 &P,
                                    const mnt6128_G2 &Q);
    static mnt6128_Fq6 affine_reduced_pairing(const mnt6128_G1 &P,
                                           const mnt6128_G2 &Q);

  mnt6128_Fq3 twist = mnt6128_twist;
  bigint<mnt6128_q_limbs> final_exponent_last_chunk_abs_of_w0 = mnt6128_final_exponent_last_chunk_abs_of_w0;
  bool final_exponent_last_chunk_is_w0_neg = mnt6128_final_exponent_last_chunk_is_w0_neg;
  bigint<mnt6128_q_limbs> final_exponent_last_chunk_w1 = mnt6128_final_exponent_last_chunk_w1;
};

} // libff

#endif // MNT6128_PP_HPP_
