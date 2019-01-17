/** @file
 *****************************************************************************

 Functions to test the algorithms that route on Benes and AS-Waksman networks.

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#include <cassert>

#include <libff/common/profiling.hpp>

#include <libsnark/common/routing_algorithms/as_waksman_routing_algorithm.hpp>
#include <libsnark/common/routing_algorithms/benes_routing_algorithm.hpp>

using namespace libsnark;

/**
 * Test Benes network routing for all permutations on 2^libff::log2(N) elements.
 */
void test_benes(const size_t N)
{
    integer_permutation permutation(1ul << libff::log2(N));

    do {
        const benes_routing routing = get_benes_routing(permutation);
        assert(valid_benes_routing(permutation, routing));
    } while (permutation.next_permutation());
}

/**
 * Test AS-Waksman network routing for all permutations on N elements.
 */
void test_as_waksman(const size_t N)
{
    integer_permutation permutation(N);

    do {
        const as_waksman_routing routing = get_as_waksman_routing(permutation);
        assert(valid_as_waksman_routing(permutation, routing));
    } while (permutation.next_permutation());
}

int main(void)
{
    libff::start_profiling();

    libff::enter_block("Test routing algorithms");

    libff::enter_block("Test Benes network routing algorithm");
    size_t bn_size = 8;
    libff::print_indent(); printf("* for all permutations on %zu elements\n", bn_size);
    test_benes(bn_size);
    libff::leave_block("Test Benes network routing algorithm");


    libff::enter_block("Test AS-Waksman network routing algorithm");
    size_t asw_max_size = 9;
    for (size_t i = 2; i <= asw_max_size; ++i)
    {
        libff::print_indent(); printf("* for all permutations on %zu elements\n", i);
        test_as_waksman(i);
    }
    libff::leave_block("Test AS-Waksman network routing algorithm");

    libff::leave_block("Test routing algorithms");
}
