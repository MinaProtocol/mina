/**
 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifdef CURVE_BN128
#include <libff/algebra/curves/bn128/bn128_pp.hpp>
#endif
#include <libff/algebra/curves/edwards/edwards_pp.hpp>
#include <libff/algebra/curves/mnt/mnt4/mnt4_pp.hpp>
#include <libff/algebra/curves/mnt/mnt6/mnt6_pp.hpp>

#include <libsnark/gadgetlib1/gadgets/hashes/sha256/sha256_gadget.hpp>
#include <libsnark/gadgetlib1/gadgets/set_commitment/set_commitment_gadget.hpp>

using namespace libsnark;

template<typename ppT>
void test_all_set_commitment_gadgets()
{
    typedef libff::Fr<ppT> FieldT;
    test_set_commitment_gadget<FieldT, CRH_with_bit_out_gadget<FieldT> >();
    test_set_commitment_gadget<FieldT, sha256_two_to_one_hash_gadget<FieldT> >();
}

int main(void)
{
    libff::start_profiling();

#ifdef CURVE_BN128       // BN128 has fancy dependencies so it may be disabled
    libff::bn128_pp::init_public_params();
    test_all_set_commitment_gadgets<libff::bn128_pp>();
#endif

    libff::edwards_pp::init_public_params();
    test_all_set_commitment_gadgets<libff::edwards_pp>();

    libff::mnt4_pp::init_public_params();
    test_all_set_commitment_gadgets<libff::mnt4_pp>();

    libff::mnt6_pp::init_public_params();
    test_all_set_commitment_gadgets<libff::mnt6_pp>();
}
