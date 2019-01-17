/** @file
 *****************************************************************************

 Implementation of functionality that runs the RAM zkSNARK for
 a given RAM example.

 See run_ram_zksnark.hpp .

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef RUN_RAM_ZKSNARK_TCC_
#define RUN_RAM_ZKSNARK_TCC_

#include <sstream>

#include <libff/common/profiling.hpp>

#include <libsnark/zk_proof_systems/zksnark/ram_zksnark/ram_zksnark.hpp>

namespace libsnark {

/**
 * The code below provides an example of all stages of running a RAM zkSNARK.
 *
 * Of course, in a real-life scenario, we would have three distinct entities,
 * mangled into one in the demonstration below. The three entities are as follows.
 * (1) The "generator", which runs the zkSNARK generator on input a given
 *     architecture.
 * (2) The "prover", which runs the zkSNARK prover on input the proving key,
 *     a boot trace, and an auxiliary input.
 * (3) The "verifier", which runs the zkSNARK verifier on input the verification key,
 *     a boot trace, a time bound, and a proof.
 */
template<typename ram_zksnark_ppT>
bool run_ram_zksnark(const ram_example<ram_zksnark_machine_pp<ram_zksnark_ppT> > &example,
                     const bool test_serialization)
{
    libff::enter_block("Call to run_ram_zksnark");

    printf("This run uses an example with the following parameters:\n");
    example.ap.print();
    printf("* Time bound (T): %zu\n", example.time_bound);

    libff::print_header("RAM zkSNARK Generator");
    ram_zksnark_keypair<ram_zksnark_ppT> keypair = ram_zksnark_generator<ram_zksnark_ppT>(example.ap);
    printf("\n"); libff::print_indent(); libff::print_mem("after generator");

    if (test_serialization)
    {
        libff::enter_block("Test serialization of keys");
        keypair.pk = libff::reserialize<ram_zksnark_proving_key<ram_zksnark_ppT> >(keypair.pk);
        keypair.vk = libff::reserialize<ram_zksnark_verification_key<ram_zksnark_ppT> >(keypair.vk);
        libff::leave_block("Test serialization of keys");
    }

    libff::print_header("RAM zkSNARK Prover");
    ram_zksnark_proof<ram_zksnark_ppT> proof = ram_zksnark_prover<ram_zksnark_ppT>(keypair.pk, example.boot_trace, example.time_bound, example.auxiliary_input);
    printf("\n"); libff::print_indent(); libff::print_mem("after prover");

    if (test_serialization)
    {
        libff::enter_block("Test serialization of proof");
        proof = libff::reserialize<ram_zksnark_proof<ram_zksnark_ppT> >(proof);
        libff::leave_block("Test serialization of proof");
    }

    libff::print_header("RAM zkSNARK Verifier");
    bool ans = ram_zksnark_verifier<ram_zksnark_ppT>(keypair.vk, example.boot_trace, example.time_bound, proof);
    printf("\n"); libff::print_indent(); libff::print_mem("after verifier");
    printf("* The verification result is: %s\n", (ans ? "PASS" : "FAIL"));

    libff::leave_block("Call to run_ram_zksnark");

    return ans;
}

} // libsnark

#endif // RUN_RAM_ZKSNARK_TCC_
