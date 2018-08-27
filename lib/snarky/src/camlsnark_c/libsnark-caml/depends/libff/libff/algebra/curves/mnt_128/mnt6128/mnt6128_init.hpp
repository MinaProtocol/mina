/** @file
 *****************************************************************************

 Declaration of interfaces for initializing MNT6.

 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef MNT6128_INIT_HPP_
#define MNT6128_INIT_HPP_

#include <libff/algebra/curves/mnt_128/mnt46128_common.hpp>
#include <libff/algebra/curves/public_params.hpp>
#include <libff/algebra/fields/fp.hpp>
#include <libff/algebra/fields/fp3.hpp>
#include <libff/algebra/fields/fp6_2over3.hpp>

namespace libff {

#define mnt6128_modulus_r mnt46128_modulus_B
#define mnt6128_modulus_q mnt46128_modulus_A

const mp_size_t mnt6128_r_bitcount = mnt46128_B_bitcount;
const mp_size_t mnt6128_q_bitcount = mnt46128_A_bitcount;

const mp_size_t mnt6128_r_limbs = mnt46128_B_limbs;
const mp_size_t mnt6128_q_limbs = mnt46128_A_limbs;

extern bigint<mnt6128_r_limbs> mnt6128_modulus_r;
extern bigint<mnt6128_q_limbs> mnt6128_modulus_q;

typedef Fp_model<mnt6128_r_limbs, mnt6128_modulus_r> mnt6128_Fr;
typedef Fp_model<mnt6128_q_limbs, mnt6128_modulus_q> mnt6128_Fq;
typedef Fp3_model<mnt6128_q_limbs, mnt6128_modulus_q> mnt6128_Fq3;
typedef Fp6_2over3_model<mnt6128_q_limbs, mnt6128_modulus_q> mnt6128_Fq6;
typedef mnt6128_Fq6 mnt6128_GT;

// parameters for twisted short Weierstrass curve E'/Fq3 : y^2 = x^3 + (a * twist^2) * x + (b * twist^3)
extern mnt6128_Fq3 mnt6128_twist;
extern mnt6128_Fq3 mnt6128_twist_coeff_a;
extern mnt6128_Fq3 mnt6128_twist_coeff_b;
extern mnt6128_Fq mnt6128_twist_mul_by_a_c0;
extern mnt6128_Fq mnt6128_twist_mul_by_a_c1;
extern mnt6128_Fq mnt6128_twist_mul_by_a_c2;
extern mnt6128_Fq mnt6128_twist_mul_by_b_c0;
extern mnt6128_Fq mnt6128_twist_mul_by_b_c1;
extern mnt6128_Fq mnt6128_twist_mul_by_b_c2;
extern mnt6128_Fq mnt6128_twist_mul_by_q_X;
extern mnt6128_Fq mnt6128_twist_mul_by_q_Y;

// parameters for pairing
extern bigint<mnt6128_q_limbs> mnt6128_ate_loop_count;
extern bool mnt6128_ate_is_loop_count_neg;
extern bigint<6*mnt6128_q_limbs> mnt6128_final_exponent;
extern bigint<mnt6128_q_limbs> mnt6128_final_exponent_last_chunk_abs_of_w0;
extern bool mnt6128_final_exponent_last_chunk_is_w0_neg;
extern bigint<mnt6128_q_limbs> mnt6128_final_exponent_last_chunk_w1;

void init_mnt6128_params();

class mnt6128_G1;
class mnt6128_G2;

} // libff

#endif // MNT6128_INIT_HPP_
