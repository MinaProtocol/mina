/** @file
 *****************************************************************************
 Profiling program that exercises the ppzkSNARK (first generator, then prover,
 then verifier) on a synthetic TBCS instance.

 The command

     $ libsnark/tbcs_ppzksnark/examples/profile_tbcs_ppzksnark 1000 10

 exercises the ppzkSNARK (first generator, then prover, then verifier) on an TBCS instance with 1000 gates and an input consisting of 10 bits.

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#include <cstdio>

#include <libff/common/profiling.hpp>
#include <libff/common/utils.hpp>

#include <libsnark/common/default_types/tbcs_ppzksnark_pp.hpp>
#include <libsnark/relations/circuit_satisfaction_problems/tbcs/examples/tbcs_examples.hpp>
#include <libsnark/zk_proof_systems/ppzksnark/tbcs_ppzksnark/examples/run_tbcs_ppzksnark.hpp>

using namespace libsnark;

int main(int argc, const char * argv[])
{
    default_tbcs_ppzksnark_pp::init_public_params();
    libff::start_profiling();

    if (argc == 2 && strcmp(argv[1], "-v") == 0)
    {
        libff::print_compilation_info();
        return 0;
    }

    if (argc != 3)
    {
        printf("usage: %s num_gates primary_input_size\n", argv[0]);
        return 1;
    }
    const int num_gates = atoi(argv[1]);
    int primary_input_size = atoi(argv[2]);

    const size_t auxiliary_input_size = 0;
    const size_t num_outputs = num_gates / 2;

    libff::enter_block("Generate TBCS example");
    tbcs_example example = generate_tbcs_example(primary_input_size, auxiliary_input_size, num_gates, num_outputs);
    libff::leave_block("Generate TBCS example");

    libff::print_header("(enter) Profile TBCS ppzkSNARK");
    const bool test_serialization = true;
    run_tbcs_ppzksnark<default_tbcs_ppzksnark_pp>(example, test_serialization);
    libff::print_header("(leave) Profile TBCS ppzkSNARK");
}
