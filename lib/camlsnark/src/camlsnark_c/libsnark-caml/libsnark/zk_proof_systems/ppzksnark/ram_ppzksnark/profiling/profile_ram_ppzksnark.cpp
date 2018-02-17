/**
 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/
#include <algorithm>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

#include <libff/common/profiling.hpp>

#include <libsnark/common/default_types/ram_ppzksnark_pp.hpp>
#include <libsnark/relations/ram_computations/rams/examples/ram_examples.hpp>
#include <libsnark/relations/ram_computations/rams/tinyram/tinyram_params.hpp>
#include <libsnark/zk_proof_systems/ppzksnark/ram_ppzksnark/examples/run_ram_ppzksnark.hpp>

using namespace libsnark;

int main(int argc, const char * argv[])
{
    ram_ppzksnark_snark_pp<default_ram_ppzksnark_pp>::init_public_params();
    libff::start_profiling();

    if (argc == 2 && strcmp(argv[1], "-v") == 0)
    {
        libff::print_compilation_info();
        return 0;
    }

    if (argc != 6)
    {
        printf("usage: %s word_size reg_count program_size input_size time_bound\n", argv[0]);
        return 1;
    }

    const size_t w = atoi(argv[1]),
                 k = atoi(argv[2]),
                 program_size = atoi(argv[3]),
                 input_size = atoi(argv[4]),
                 time_bound = atoi(argv[5]);

    typedef ram_ppzksnark_machine_pp<default_ram_ppzksnark_pp> machine_ppT;

    const ram_ppzksnark_architecture_params<default_ram_ppzksnark_pp> ap(w, k);

    libff::enter_block("Generate RAM example");
    const size_t boot_trace_size_bound = program_size + input_size;
    const bool satisfiable = true;
    ram_example<machine_ppT> example = gen_ram_example_complex<machine_ppT>(ap, boot_trace_size_bound, time_bound, satisfiable);
    libff::leave_block("Generate RAM example");

    libff::print_header("(enter) Profile RAM ppzkSNARK");
    const bool test_serialization = true;
    run_ram_ppzksnark<default_ram_ppzksnark_pp>(example, test_serialization);
    libff::print_header("(leave) Profile RAM ppzkSNARK");
}
