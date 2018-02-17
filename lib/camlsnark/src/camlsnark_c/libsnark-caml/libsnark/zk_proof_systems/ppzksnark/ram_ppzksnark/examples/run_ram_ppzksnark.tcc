/** @file
 *****************************************************************************

 Implementation of functionality that runs the RAM ppzkSNARK for
 a given RAM example.

 See run_ram_ppzksnark.hpp .

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef RUN_RAM_PPZKSNARK_TCC_
#define RUN_RAM_PPZKSNARK_TCC_

#include <sstream>

#include <libff/common/profiling.hpp>

#include <libsnark/zk_proof_systems/ppzksnark/ram_ppzksnark/ram_ppzksnark.hpp>

namespace libsnark {

/**
 * The code below provides an example of all stages of running a RAM ppzkSNARK.
 *
 * Of course, in a real-life scenario, we would have three distinct entities,
 * mangled into one in the demonstration below. The three entities are as follows.
 * (1) The "generator", which runs the ppzkSNARK generator on input a given
 *     architecture and bounds on the computation.
 * (2) The "prover", which runs the ppzkSNARK prover on input the proving key,
 *     a boot trace, and an auxiliary input.
 * (3) The "verifier", which runs the ppzkSNARK verifier on input the verification key,
 *     a boot trace, and a proof.
 */
template<typename ram_ppzksnark_ppT>
bool run_ram_ppzksnark(const ram_example<ram_ppzksnark_machine_pp<ram_ppzksnark_ppT> > &example,
                       const bool test_serialization)
{
    libff::enter_block("Call to run_ram_ppzksnark");

    printf("This run uses an example with the following parameters:\n");
    example.ap.print();
    printf("* Primary input size bound (L): %zu\n", example.boot_trace_size_bound);
    printf("* Time bound (T): %zu\n", example.time_bound);
    printf("Hence, libff::log2(L+2*T) equals %zu\n", libff::log2(example.boot_trace_size_bound+2*example.time_bound));

    libff::print_header("RAM ppzkSNARK Generator");
    ram_ppzksnark_keypair<ram_ppzksnark_ppT> keypair = ram_ppzksnark_generator<ram_ppzksnark_ppT>(example.ap, example.boot_trace_size_bound, example.time_bound);
    printf("\n"); libff::print_indent(); libff::print_mem("after generator");

    if (test_serialization)
    {
        libff::enter_block("Test serialization of keys");
        keypair.pk = libff::reserialize<ram_ppzksnark_proving_key<ram_ppzksnark_ppT> >(keypair.pk);
        keypair.vk = libff::reserialize<ram_ppzksnark_verification_key<ram_ppzksnark_ppT> >(keypair.vk);
        libff::leave_block("Test serialization of keys");
    }

    libff::print_header("RAM ppzkSNARK Prover");
    ram_ppzksnark_proof<ram_ppzksnark_ppT> proof = ram_ppzksnark_prover<ram_ppzksnark_ppT>(keypair.pk, example.boot_trace, example.auxiliary_input);
    printf("\n"); libff::print_indent(); libff::print_mem("after prover");

    if (test_serialization)
    {
        libff::enter_block("Test serialization of proof");
        proof = libff::reserialize<ram_ppzksnark_proof<ram_ppzksnark_ppT> >(proof);
        libff::leave_block("Test serialization of proof");
    }

    libff::print_header("RAM ppzkSNARK Verifier");
    bool ans = ram_ppzksnark_verifier<ram_ppzksnark_ppT>(keypair.vk, example.boot_trace, proof);
    printf("\n"); libff::print_indent(); libff::print_mem("after verifier");
    printf("* The verification result is: %s\n", (ans ? "PASS" : "FAIL"));

    libff::leave_block("Call to run_ram_ppzksnark");

    return ans;
}

} // libsnark

#endif // RUN_RAM_PPZKSNARK_TCC_
