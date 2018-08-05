/** @file
 *****************************************************************************

 Declaration of interfaces for the the R1CS ppzkSNARK verifier gadget.

 The gadget r1cs_ppzksnark_verifier_gadget verifiers correct computation of r1cs_ppzksnark_verifier_strong_IC.
 The gadget is built from two main sub-gadgets:
 - r1cs_ppzksnark_verifier_process_vk_gadget, which verifies correct computation of r1cs_ppzksnark_verifier_process_vk, and
 - r1cs_ppzksnark_online_verifier_gadget, which verifies correct computation of r1cs_ppzksnark_online_verifier_strong_IC.
 See r1cs_ppzksnark.hpp for description of the aforementioned functions.

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef R1CS_SE_PPZKSNARK_VERIFIER_GADGET_HPP_
#define R1CS_SE_PPZKSNARK_VERIFIER_GADGET_HPP_

#include <libsnark/gadgetlib1/gadgets/basic_gadgets.hpp>
#include <libsnark/gadgetlib1/gadgets/curves/weierstrass_g1_gadget.hpp>
#include <libsnark/gadgetlib1/gadgets/curves/weierstrass_g2_gadget.hpp>
#include <libsnark/gadgetlib1/gadgets/pairing/pairing_checks.hpp>
#include <libsnark/gadgetlib1/gadgets/pairing/pairing_params.hpp>
#include <libsnark/zk_proof_systems/ppzksnark/r1cs_se_ppzksnark/r1cs_se_ppzksnark.hpp>

namespace libsnark {

template<typename ppT>
class r1cs_se_ppzksnark_proof_variable : public gadget<libff::Fr<ppT> > {
public:
    typedef libff::Fr<ppT> FieldT;

    std::shared_ptr<G1_variable<ppT> > A;
    std::shared_ptr<G2_variable<ppT> > B;
    std::shared_ptr<G1_variable<ppT> > C;

    std::vector<std::shared_ptr<G1_variable<ppT> > > all_G1_vars;
    std::vector<std::shared_ptr<G2_variable<ppT> > > all_G2_vars;

    std::vector<std::shared_ptr<G1_checker_gadget<ppT> > > all_G1_checkers;
    std::shared_ptr<G2_checker_gadget<ppT> > G2_checker;

    pb_variable_array<FieldT> proof_contents;

    r1cs_se_ppzksnark_proof_variable(protoboard<FieldT> &pb,
                                  const std::string &annotation_prefix);
    void generate_r1cs_constraints();
    void generate_r1cs_witness(const r1cs_se_ppzksnark_proof<other_curve<ppT> > &proof);
    static size_t size();
};

// TODO: Should we be storing e(G_alpha, H_beta)^{-1} in here?
template<typename ppT>
class r1cs_se_ppzksnark_verification_key_variable : public gadget<libff::Fr<ppT> > {
public:
    typedef libff::Fr<ppT> FieldT;

    std::shared_ptr<G2_variable<ppT> > H;
    std::shared_ptr<G1_variable<ppT> > G_alpha;
    std::shared_ptr<G2_variable<ppT> > H_beta;
    std::shared_ptr<G1_variable<ppT> > G_gamma;
    std::shared_ptr<G2_variable<ppT> > H_gamma;

    std::shared_ptr<Fqk_variable<ppT>> G_alpha_H_beta_inv;

    std::vector<std::shared_ptr<G1_variable<ppT> > > query;
    std::shared_ptr<G1_variable<ppT> > query_base;

    /* TODO
    std::shared_ptr<G1_variable<ppT> > alphaB_g1;
    std::shared_ptr<G2_variable<ppT> > alphaC_g2;
    std::shared_ptr<G2_variable<ppT> > gamma_g2;
    std::shared_ptr<G1_variable<ppT> > gamma_beta_g1;
    std::shared_ptr<G2_variable<ppT> > gamma_beta_g2;
    std::shared_ptr<G2_variable<ppT> > rC_Z_g2;
    std::shared_ptr<G1_variable<ppT> > encoded_IC_base; */

    pb_linear_combination_array<FieldT> all_vars;
    size_t input_size;

    std::vector<std::shared_ptr<G1_variable<ppT> > > all_G1_vars;
    std::vector<std::shared_ptr<G2_variable<ppT> > > all_G2_vars;
    std::vector<std::shared_ptr<Fqk_variable<ppT> > > all_GT_vars;

    // Unfortunately, g++ 4.9 and g++ 5.0 have a bug related to
    // incorrect inlining of small functions:
    // https://gcc.gnu.org/bugzilla/show_bug.cgi?id=65307, which
    // produces wrong assembly even at -O1. The test case at the bug
    // report is directly derived from this code here. As a temporary
    // work-around we mark the key functions noinline to hint compiler
    // that inlining should not be performed.

    // TODO: remove later, when g++ developers fix the bug.

    __attribute__((noinline)) r1cs_se_ppzksnark_verification_key_variable(protoboard<FieldT> &pb,
                                                                       const size_t input_size,
                                                                       const std::string &annotation_prefix);
    void generate_r1cs_constraints();
    void generate_r1cs_witness(const r1cs_se_ppzksnark_verification_key<other_curve<ppT> > &vk);
    /* void generate_r1cs_witness(const libff::bit_vector &vk_bits); */
    /*
    libff::bit_vector get_bits() const;
    static size_t __attribute__((noinline)) size_in_bits(const size_t input_size);
    static libff::bit_vector get_verification_key_bits(const r1cs_se_ppzksnark_verification_key<other_curve<ppT> > &r1cs_vk);
    */
};

template<typename ppT>
class r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable {
public:
    typedef libff::Fr<ppT> FieldT;

    std::shared_ptr<G1_variable<ppT> > G_alpha;
    std::shared_ptr<G2_variable<ppT> > H_beta;
    std::shared_ptr<Fqk_variable<ppT>> G_alpha_H_beta_inv;

    std::shared_ptr<G1_precomputation<ppT> > G_gamma_pc;
    std::shared_ptr<G2_precomputation<ppT> > H_gamma_pc;
    std::shared_ptr<G2_precomputation<ppT> > H_pc;

    std::shared_ptr<G1_variable<ppT> > query_base;
    std::vector<std::shared_ptr<G1_variable<ppT> > > query;

    r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable();
    r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable(protoboard<FieldT> &pb,
                                                                         const r1cs_se_ppzksnark_verification_key<other_curve<ppT> > &r1cs_vk,
                                                                         const std::string &annotation_prefix);
};

template<typename ppT>
class r1cs_se_ppzksnark_verifier_process_vk_gadget : public gadget<libff::Fr<ppT> > {
public:
    typedef libff::Fr<ppT> FieldT;

    std::shared_ptr<precompute_G1_gadget<ppT> > compute_G_gamma_pc;
    std::shared_ptr<precompute_G2_gadget<ppT> > compute_H_gamma_pc;
    std::shared_ptr<precompute_G2_gadget<ppT> > compute_H_pc;

    r1cs_se_ppzksnark_verification_key_variable<ppT> vk;
    r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT> &pvk; // important to have a reference here

    r1cs_se_ppzksnark_verifier_process_vk_gadget(protoboard<FieldT> &pb,
                                              const r1cs_se_ppzksnark_verification_key_variable<ppT> &vk,
                                              r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT> &pvk,
                                              const std::string &annotation_prefix);
    void generate_r1cs_constraints();
    void generate_r1cs_witness();
};

template<typename ppT>
class r1cs_se_ppzksnark_online_verifier_gadget : public gadget<libff::Fr<ppT> > {
public:
    typedef libff::Fr<ppT> FieldT;

    r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT> pvk;

    pb_variable_array<FieldT> input;
    size_t elt_size;
    r1cs_se_ppzksnark_proof_variable<ppT> proof;
    pb_variable<FieldT> result;
    const size_t input_len;

    std::shared_ptr<G1_variable<ppT> > acc;
    std::shared_ptr<G1_multiscalar_mul_gadget<ppT> > accumulate_input;

    std::shared_ptr<G1_precomputation<ppT> > proof_A_G_alpha_precomp;
      std::shared_ptr<precompute_G1_gadget<ppT> > compute_proof_A_G_alpha_precomp;
    std::shared_ptr<G2_precomputation<ppT> > proof_B_H_beta_precomp;
      std::shared_ptr<precompute_G2_gadget<ppT> > compute_proof_B_H_beta_precomp;

    std::shared_ptr<G1_precomputation<ppT>> acc_precomp;
      std::shared_ptr<precompute_G1_gadget<ppT> > compute_acc_precomp;

    std::shared_ptr<G1_precomputation<ppT> > proof_A_precomp;
      std::shared_ptr<precompute_G1_gadget<ppT> > compute_proof_A_precomp;
    std::shared_ptr<G2_precomputation<ppT> > proof_B_precomp;
      std::shared_ptr<precompute_G2_gadget<ppT> > compute_proof_B_precomp;
    std::shared_ptr<G1_precomputation<ppT> > proof_C_precomp;
      std::shared_ptr<precompute_G1_gadget<ppT> > compute_proof_C_precomp;

    std::shared_ptr<G1_variable<ppT> > proof_A_G_alpha;
    std::shared_ptr<G1_add_gadget<ppT> > compute_proof_A_G_alpha;

    std::shared_ptr<G2_variable<ppT> > proof_B_H_beta;
    std::shared_ptr<G2_add_gadget<ppT> > compute_proof_B_H_beta;

    std::shared_ptr<check_e_times_e_over_e_equals_value_gadget<ppT>> first_check;
    std::shared_ptr<check_e_equals_e_gadget<ppT>> second_check;
    /*
    std::shared_ptr<G1_variable<ppT> > proof_g_A_g_acc;
    std::shared_ptr<G1_add_gadget<ppT> > compute_proof_g_A_g_acc;
    std::shared_ptr<G1_variable<ppT> > proof_g_A_g_acc_C;
    std::shared_ptr<G1_add_gadget<ppT> > compute_proof_g_A_g_acc_C;

    std::shared_ptr<G1_precomputation<ppT> > proof_g_A_h_precomp;
    std::shared_ptr<G1_precomputation<ppT> > proof_g_A_g_acc_C_precomp;
    std::shared_ptr<G1_precomputation<ppT> > proof_g_A_g_acc_precomp;
    std::shared_ptr<G1_precomputation<ppT> > proof_g_A_g_precomp;
    std::shared_ptr<G1_precomputation<ppT> > proof_g_B_h_precomp;
    std::shared_ptr<G1_precomputation<ppT> > proof_g_C_h_precomp;
    std::shared_ptr<G1_precomputation<ppT> > proof_g_C_g_precomp;
    std::shared_ptr<G1_precomputation<ppT> > proof_g_K_precomp;
    std::shared_ptr<G1_precomputation<ppT> > proof_g_H_precomp;

    std::shared_ptr<G2_precomputation<ppT> > proof_g_B_g_precomp;

    std::shared_ptr<precompute_G1_gadget<ppT> > compute_proof_g_A_h_precomp;
    std::shared_ptr<precompute_G1_gadget<ppT> > compute_proof_g_A_g_acc_C_precomp;
    std::shared_ptr<precompute_G1_gadget<ppT> > compute_proof_g_A_g_acc_precomp;
    std::shared_ptr<precompute_G1_gadget<ppT> > compute_proof_g_A_g_precomp;
    std::shared_ptr<precompute_G1_gadget<ppT> > compute_proof_g_B_h_precomp;
    std::shared_ptr<precompute_G1_gadget<ppT> > compute_proof_g_C_h_precomp;
    std::shared_ptr<precompute_G1_gadget<ppT> > compute_proof_g_C_g_precomp;
    std::shared_ptr<precompute_G1_gadget<ppT> > compute_proof_g_K_precomp;
    std::shared_ptr<precompute_G1_gadget<ppT> > compute_proof_g_H_precomp;

    std::shared_ptr<precompute_G2_gadget<ppT> > compute_proof_g_B_g_precomp;

    std::shared_ptr<check_e_equals_e_gadget<ppT> > check_kc_A_valid;
    std::shared_ptr<check_e_equals_e_gadget<ppT> > check_kc_B_valid;
    std::shared_ptr<check_e_equals_e_gadget<ppT> > check_kc_C_valid;
    std::shared_ptr<check_e_equals_ee_gadget<ppT> > check_QAP_valid;
    std::shared_ptr<check_e_equals_ee_gadget<ppT> > check_CC_valid;
    */
    //

    pb_variable<FieldT> first_check_passed;
    pb_variable<FieldT> second_check_passed;

    pb_variable_array<FieldT> all_test_results;
    std::shared_ptr<conjunction_gadget<FieldT> > all_tests_pass;

    r1cs_se_ppzksnark_online_verifier_gadget(protoboard<FieldT> &pb,
                                          const r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT> &pvk,
                                          const pb_variable_array<FieldT> &input,
                                          const size_t elt_size,
                                          const r1cs_se_ppzksnark_proof_variable<ppT> &proof,
                                          const pb_variable<FieldT> &result,
                                          const std::string &annotation_prefix);
    void generate_r1cs_constraints();
    void generate_r1cs_witness();
};

template<typename ppT>
class r1cs_se_ppzksnark_verifier_gadget : public gadget<libff::Fr<ppT> > {
public:
    typedef libff::Fr<ppT> FieldT;

    std::shared_ptr<r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT> > pvk;
    std::shared_ptr<r1cs_se_ppzksnark_verifier_process_vk_gadget<ppT> > compute_pvk;
    std::shared_ptr<r1cs_se_ppzksnark_online_verifier_gadget<ppT> > online_verifier;

    r1cs_se_ppzksnark_verifier_gadget(protoboard<FieldT> &pb,
                                   const r1cs_se_ppzksnark_verification_key_variable<ppT> &vk,
                                   const pb_variable_array<FieldT> &input,
                                   const size_t elt_size,
                                   const r1cs_se_ppzksnark_proof_variable<ppT> &proof,
                                   const pb_variable<FieldT> &result,
                                   const std::string &annotation_prefix);

    void generate_r1cs_constraints();
    void generate_r1cs_witness();
};

} // libsnark

#include <libsnark/gadgetlib1/gadgets/verifiers/r1cs_se_ppzksnark_verifier_gadget.tcc>

#endif // R1CS_SE_PPZKSNARK_VERIFIER_GADGET_HPP_
