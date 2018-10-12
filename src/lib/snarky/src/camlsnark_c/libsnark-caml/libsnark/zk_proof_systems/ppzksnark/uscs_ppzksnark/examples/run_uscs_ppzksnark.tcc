/** @file
 *****************************************************************************

 Implementation of functionality that runs the USCS ppzkSNARK for
 a given USCS example.

 See run_uscs_ppzksnark.hpp .

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef RUN_USCS_PPZKSNARK_TCC_
#define RUN_USCS_PPZKSNARK_TCC_

#include <sstream>

#include <libff/common/profiling.hpp>

#include <libsnark/zk_proof_systems/ppzksnark/uscs_ppzksnark/uscs_ppzksnark.hpp>

namespace libsnark {

/**
 * The code below provides an example of all stages of running a USCS ppzkSNARK.
 *
 * Of course, in a real-life scenario, we would have three distinct entities,
 * mangled into one in the demonstration below. The three entities are as follows.
 * (1) The "generator", which runs the ppzkSNARK generator on input a given
 *     constraint system CS to create a proving and a verification key for CS.
 * (2) The "prover", which runs the ppzkSNARK prover on input the proving key,
 *     a primary input for CS, and an auxiliary input for CS.
 * (3) The "verifier", which runs the ppzkSNARK verifier on input the verification key,
 *     a primary input for CS, and a proof.
 */
template<typename ppT>
bool run_uscs_ppzksnark(const uscs_example<libff::Fr<ppT> > &example,
                        const bool test_serialization)
{
    libff::enter_block("Call to run_uscs_ppzksnark");

    libff::print_header("USCS ppzkSNARK Generator");
    uscs_ppzksnark_keypair<ppT> keypair = uscs_ppzksnark_generator<ppT>(example.constraint_system);
    printf("\n"); libff::print_indent(); libff::print_mem("after generator");

    libff::print_header("Preprocess verification key");
    uscs_ppzksnark_processed_verification_key<ppT> pvk = uscs_ppzksnark_verifier_process_vk<ppT>(keypair.vk);

    if (test_serialization)
    {
        libff::enter_block("Test serialization of keys");
        keypair.pk = libff::reserialize<uscs_ppzksnark_proving_key<ppT> >(keypair.pk);
        keypair.vk = libff::reserialize<uscs_ppzksnark_verification_key<ppT> >(keypair.vk);
        pvk = libff::reserialize<uscs_ppzksnark_processed_verification_key<ppT> >(pvk);
        libff::leave_block("Test serialization of keys");
    }

    libff::print_header("USCS ppzkSNARK Prover");
    uscs_ppzksnark_proof<ppT> proof = uscs_ppzksnark_prover<ppT>(keypair.pk, example.primary_input, example.auxiliary_input);
    printf("\n"); libff::print_indent(); libff::print_mem("after prover");

    if (test_serialization)
    {
        libff::enter_block("Test serialization of proof");
        proof = libff::reserialize<uscs_ppzksnark_proof<ppT> >(proof);
        libff::leave_block("Test serialization of proof");
    }

    libff::print_header("USCS ppzkSNARK Verifier");
    bool ans = uscs_ppzksnark_verifier_strong_IC<ppT>(keypair.vk, example.primary_input, proof);
    printf("\n"); libff::print_indent(); libff::print_mem("after verifier");
    printf("* The verification result is: %s\n", (ans ? "PASS" : "FAIL"));

    libff::print_header("USCS ppzkSNARK Online Verifier");
    bool ans2 = uscs_ppzksnark_online_verifier_strong_IC<ppT>(pvk, example.primary_input, proof);
    assert(ans == ans2);

    libff::leave_block("Call to run_uscs_ppzksnark");

    return ans;
}

} // libsnark

#endif // RUN_USCS_PPZKSNARK_TCC_
