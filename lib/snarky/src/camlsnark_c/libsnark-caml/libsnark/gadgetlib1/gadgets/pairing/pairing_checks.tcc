/** @file
 *****************************************************************************

 Implementation of interfaces for pairing-check gadgets.

 See pairing_checks.hpp .

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef PAIRING_CHECKS_TCC_
#define PAIRING_CHECKS_TCC_

namespace libsnark {

template<typename ppT>
check_e_equals_e_gadget<ppT>::check_e_equals_e_gadget(protoboard<FieldT> &pb,
                                                      const G1_precomputation<ppT> &lhs_G1,
                                                      const G2_precomputation<ppT> &lhs_G2,
                                                      const G1_precomputation<ppT> &rhs_G1,
                                                      const G2_precomputation<ppT> &rhs_G2,
                                                      const pb_variable<FieldT> &result,
                                                      const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    lhs_G1(lhs_G1),
    lhs_G2(lhs_G2),
    rhs_G1(rhs_G1),
    rhs_G2(rhs_G2),
    result(result)
{
    ratio.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " ratio")));
    compute_ratio.reset(new e_over_e_miller_loop_gadget<ppT>(pb, lhs_G1, lhs_G2, rhs_G1, rhs_G2, *ratio, FMT(annotation_prefix, " compute_ratio")));
    check_finexp.reset(new final_exp_gadget<ppT>(pb, *ratio, result, FMT(annotation_prefix, " check_finexp")));
}

template<typename ppT>
void check_e_equals_e_gadget<ppT>::generate_r1cs_constraints()
{
    compute_ratio->generate_r1cs_constraints();
    check_finexp->generate_r1cs_constraints();
}

template<typename ppT>
void check_e_equals_e_gadget<ppT>::generate_r1cs_witness()
{
    compute_ratio->generate_r1cs_witness();
    check_finexp->generate_r1cs_witness();
}

template<typename ppT>
check_e_equals_ee_gadget<ppT>::check_e_equals_ee_gadget(protoboard<FieldT> &pb,
                                                        const G1_precomputation<ppT> &lhs_G1,
                                                        const G2_precomputation<ppT> &lhs_G2,
                                                        const G1_precomputation<ppT> &rhs1_G1,
                                                        const G2_precomputation<ppT> &rhs1_G2,
                                                        const G1_precomputation<ppT> &rhs2_G1,
                                                        const G2_precomputation<ppT> &rhs2_G2,
                                                        const pb_variable<FieldT> &result,
                                                        const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    lhs_G1(lhs_G1),
    lhs_G2(lhs_G2),
    rhs1_G1(rhs1_G1),
    rhs1_G2(rhs1_G2),
    rhs2_G1(rhs2_G1),
    rhs2_G2(rhs2_G2),
    result(result)
{
    ratio.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " ratio")));
    compute_ratio.reset(new e_times_e_over_e_miller_loop_gadget<ppT>(pb, rhs1_G1, rhs1_G2, rhs2_G1, rhs2_G2, lhs_G1, lhs_G2, *ratio, FMT(annotation_prefix, " compute_ratio")));
    check_finexp.reset(new final_exp_gadget<ppT>(pb, *ratio, result, FMT(annotation_prefix, " check_finexp")));
}

template<typename ppT>
void check_e_equals_ee_gadget<ppT>::generate_r1cs_constraints()
{
    compute_ratio->generate_r1cs_constraints();
    check_finexp->generate_r1cs_constraints();
}

template<typename ppT>
void check_e_equals_ee_gadget<ppT>::generate_r1cs_witness()
{
    compute_ratio->generate_r1cs_witness();
    check_finexp->generate_r1cs_witness();
}

template<typename ppT>
check_e_times_e_over_e_equals_value_gadget<ppT>::check_e_times_e_over_e_equals_value_gadget(
    protoboard<FieldT> &pb,
    const G1_precomputation<ppT> &lhs1_G1,
    const G2_precomputation<ppT> &lhs1_G2,
    const G1_precomputation<ppT> &lhs2_G1,
    const G2_precomputation<ppT> &lhs2_G2,
    const G1_precomputation<ppT> &rhs_G1,
    const G2_precomputation<ppT> &rhs_G2,
    const Fqk_variable<ppT> &expected_result,
    const pb_variable<FieldT> &result_is_expected,
    const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    lhs1_G1(lhs1_G1),
    lhs1_G2(lhs1_G2),
    lhs2_G1(lhs2_G1),
    lhs2_G2(lhs2_G2),
    rhs_G1(rhs_G1),
    rhs_G2(rhs_G2),
    expected_result(expected_result),
    result_is_expected(result_is_expected)
{
    result.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " result")));
    ratio.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " ratio")));
    compute_ratio.reset(new e_times_e_over_e_miller_loop_gadget<ppT>(pb, lhs1_G1, lhs1_G2, lhs2_G1, lhs2_G2, rhs_G1, rhs_G2, *ratio, FMT(annotation_prefix, " compute_ratio")));
    check_finexp.reset(new final_exp_value_gadget<ppT>(pb, *ratio, *result, FMT(annotation_prefix, " check_finexp")));
    check_is_expected.reset(new field_vector_equals_gadget<FieldT>(pb, result->all_vars, expected_result.all_vars, result_is_expected, FMT(annotation_prefix, " check_is_expected")));
}

template<typename ppT>
void check_e_times_e_over_e_equals_value_gadget<ppT>::generate_r1cs_constraints()
{
    compute_ratio->generate_r1cs_constraints();
    check_finexp->generate_r1cs_constraints();
    check_is_expected->generate_r1cs_constraints();
}

template<typename ppT>
void check_e_times_e_over_e_equals_value_gadget<ppT>::generate_r1cs_witness()
{
    compute_ratio->generate_r1cs_witness();
    check_finexp->generate_r1cs_witness();
    check_is_expected->generate_r1cs_witness();
}

} // libsnark

#endif // PAIRING_CHECKS_TCC_
