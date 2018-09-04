/** @file
 *****************************************************************************

 Implementation of interfaces for the the R1CS ppzkSNARK verifier gadget.

 See r1cs_se_ppzksnark_verifier_gadget.hpp .

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef R1CS_SE_PPZKSNARK_VERIFIER_GADGET_TCC_
#define R1CS_SE_PPZKSNARK_VERIFIER_GADGET_TCC_

#include <libsnark/gadgetlib1/constraint_profiling.hpp>

namespace libsnark {

template<typename ppT>
r1cs_se_ppzksnark_proof_variable<ppT>::r1cs_se_ppzksnark_proof_variable(protoboard<FieldT> &pb,
                                                                  const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix)
{
    const size_t num_G1 = 2;
    const size_t num_G2 = 1;

    A.reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " A")));
    B.reset(new G2_variable<ppT>(pb, FMT(annotation_prefix, " B")));
    C.reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " C")));

    all_G1_vars = { A, C };
    all_G2_vars = { B };

    all_G1_checkers.resize(all_G1_vars.size());

    for (size_t i = 0; i < all_G1_vars.size(); ++i)
    {
        all_G1_checkers[i].reset(new G1_checker_gadget<ppT>(pb, *all_G1_vars[i], FMT(annotation_prefix, " all_G1_checkers_%zu", i)));
    }
    G2_checker.reset(new G2_checker_gadget<ppT>(pb, *B, FMT(annotation_prefix, " G2_checker")));

    assert(all_G1_vars.size() == num_G1);
    assert(all_G2_vars.size() == num_G2);
}

template<typename ppT>
void r1cs_se_ppzksnark_proof_variable<ppT>::generate_r1cs_constraints()
{
    for (auto &G1_checker : all_G1_checkers)
    {
        G1_checker->generate_r1cs_constraints();
    }

    G2_checker->generate_r1cs_constraints();
}

template<typename ppT>
void r1cs_se_ppzksnark_proof_variable<ppT>::generate_r1cs_witness(const r1cs_se_ppzksnark_proof<other_curve<ppT> > &proof)
{
    std::vector<libff::G1<other_curve<ppT> > > G1_elems;
    std::vector<libff::G2<other_curve<ppT> > > G2_elems;

    G1_elems = { proof.A, proof.C };
    G2_elems = { proof.B };

    assert(G1_elems.size() == all_G1_vars.size());
    assert(G2_elems.size() == all_G2_vars.size());

    for (size_t i = 0; i < G1_elems.size(); ++i)
    {
        all_G1_vars[i]->generate_r1cs_witness(G1_elems[i]);
    }

    for (size_t i = 0; i < G2_elems.size(); ++i)
    {
        all_G2_vars[i]->generate_r1cs_witness(G2_elems[i]);
    }

    for (auto &G1_checker : all_G1_checkers)
    {
        G1_checker->generate_r1cs_witness();
    }

    G2_checker->generate_r1cs_witness();
}

template<typename ppT>
size_t r1cs_se_ppzksnark_proof_variable<ppT>::size()
{
    const size_t num_G1 = 2;
    const size_t num_G2 = 1;
    return (num_G1 * G1_variable<ppT>::num_field_elems + num_G2 * G2_variable<ppT>::num_field_elems);
}

template<typename ppT>
r1cs_se_ppzksnark_verification_key_variable<ppT>::r1cs_se_ppzksnark_verification_key_variable(protoboard<FieldT> &pb,
                                                                                        const size_t input_size,
                                                                                        const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    input_size(input_size)
{
    const size_t num_G1 = 2 + (input_size + 1);
    const size_t num_G2 = 3;
    const size_t num_GT = 1;

    this->H.reset(new G2_variable<ppT>(pb, FMT(annotation_prefix, " H")));
    this->G_alpha.reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " G_alpha")));
    this->H_beta.reset(new G2_variable<ppT>(pb, FMT(annotation_prefix, " H_beta")));
    this->G_gamma.reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " G_gamma")));
    this->H_gamma.reset(new G2_variable<ppT>(pb, FMT(annotation_prefix, " H_gamma")));
    this->G_alpha_H_beta_inv.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix,  "G_alpha_H_beta_inv")));

    all_G1_vars = { };
    this->query.resize(input_size);
    this->query_base.reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " query_base")));
    all_G1_vars.emplace_back(this->query_base);

    for (size_t i = 0; i < input_size; ++i)
    {
        this->query[i].reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " query_%zu", i)));
        all_G1_vars.emplace_back(this->query[i]);
    }
    all_G1_vars.emplace_back(this->G_alpha);
    all_G1_vars.emplace_back(this->G_gamma);

    all_G2_vars = { this->H, this->H_beta, this->H_gamma };
    all_GT_vars = { this->G_alpha_H_beta_inv };

    for (auto &G1_var : all_G1_vars)
    {
        all_vars.insert(all_vars.end(), G1_var->all_vars.begin(), G1_var->all_vars.end());
    }

    for (auto &G2_var : all_G2_vars)
    {
        all_vars.insert(all_vars.end(), G2_var->all_vars.begin(), G2_var->all_vars.end());
    }

    for (auto &GT_var : all_GT_vars)
    {
        all_vars.insert(all_vars.end(), GT_var->all_vars.begin(), GT_var->all_vars.end());
    }

    assert(all_G1_vars.size() == num_G1);
    assert(all_G2_vars.size() == num_G2);
    assert(all_GT_vars.size() == num_GT);
    assert(all_vars.size() == (num_G1 * G1_variable<ppT>::num_variables() + num_G2 * G2_variable<ppT>::num_variables() + num_GT * Fqk_variable<ppT>::num_variables()));
}

template<typename ppT>
void r1cs_se_ppzksnark_verification_key_variable<ppT>::generate_r1cs_witness(const r1cs_se_ppzksnark_verification_key<other_curve<ppT> > &vk)
{
    std::vector<libff::G1<other_curve<ppT> > > G1_elems;
    std::vector<libff::G2<other_curve<ppT> > > G2_elems;
    std::vector<libff::Fqk<other_curve<ppT>>> GT_elems;

    G1_elems = {};
    assert(vk.query.size() == input_size + 1);
    G1_elems.emplace_back(vk.query[0]);
    for (size_t i = 0; i < input_size; ++i)
    {
        G1_elems.emplace_back(vk.query[i+1]);
    }
    G1_elems.emplace_back(vk.G_alpha);
    G1_elems.emplace_back(vk.G_gamma);

    G2_elems = { vk.H, vk.H_beta, vk.H_gamma };

    libff::Fqk< other_curve<ppT> > G_alpha_H_beta_inv = vk.G_alpha_H_beta.unitary_inverse();
    GT_elems = { G_alpha_H_beta_inv };

    assert(G1_elems.size() == all_G1_vars.size());
    assert(G2_elems.size() == all_G2_vars.size());
    assert(GT_elems.size() == all_GT_vars.size());

    for (size_t i = 0; i < G1_elems.size(); ++i)
    {
        all_G1_vars[i]->generate_r1cs_witness(G1_elems[i]);
    }

    for (size_t i = 0; i < G2_elems.size(); ++i)
    {
        all_G2_vars[i]->generate_r1cs_witness(G2_elems[i]);
    }

    for (size_t i = 0; i < GT_elems.size(); ++i)
    {
        all_GT_vars[i]->generate_r1cs_witness(GT_elems[i]);
    }
}

template<typename ppT>
r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT>::r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable()
{
    // will be allocated outside
}

template<typename ppT>
r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT>::r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable(protoboard<FieldT> &pb,
                                                                                                                                                const r1cs_se_ppzksnark_verification_key<other_curve<ppT> > &r1cs_vk,
                                                                                                                                                const std::string &annotation_prefix)
{
    query_base.reset(new G1_variable<ppT>(pb, r1cs_vk.query[0], FMT(annotation_prefix, " query_base")));

    size_t input_size = r1cs_vk.query.size() - 1;
    query.resize(input_size);
    for (size_t i = 0; i < input_size; ++i)
    {
        query[i].reset(new G1_variable<ppT>(pb, r1cs_vk.query[i + 1], FMT(annotation_prefix, " query")));
    }

    G_alpha.reset(new G1_variable<ppT>(pb, r1cs_vk.G_alpha, FMT(annotation_prefix, " G_alpha")));
    H_beta.reset(new G2_variable<ppT>(pb, r1cs_vk.H_beta, FMT(annotation_prefix, " G_alpha")));
    G_alpha_H_beta_inv.reset(
        new Fqk_variable<ppT>(pb, r1cs_vk.G_alpha_H_beta.unitary_inverse(),
          FMT(annotation_prefix, " G_alpha_H_beta_inv")));

    G_gamma_pc.reset(
        new G1_precomputation<ppT>(pb,
          r1cs_vk.G_gamma, FMT(annotation_prefix, " G_gamma_pc")));
    H_gamma_pc.reset(
        new G2_precomputation<ppT>(pb,
          r1cs_vk.H_gamma, FMT(annotation_prefix, " H_gamma_pc")));
    H_pc.reset(
        new G2_precomputation<ppT>(pb,
          r1cs_vk.H, FMT(annotation_prefix, " H_pc")));
}

template<typename ppT>
r1cs_se_ppzksnark_verifier_process_vk_gadget<ppT>::r1cs_se_ppzksnark_verifier_process_vk_gadget(protoboard<FieldT> &pb,
                                                                                          const r1cs_se_ppzksnark_verification_key_variable<ppT> &vk,
                                                                                          r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT> &pvk,
                                                                                          const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    vk(vk),
    pvk(pvk)
{
    pvk.query_base = vk.query_base;
    pvk.query = vk.query;

    pvk.G_alpha = vk.G_alpha;
    pvk.H_beta = vk.H_beta;
    pvk.G_alpha_H_beta_inv = vk.G_alpha_H_beta_inv;

    pvk.G_gamma_pc.reset(new G1_precomputation<ppT>());
    pvk.H_gamma_pc.reset(new G2_precomputation<ppT>());
    pvk.H_pc.reset(new G2_precomputation<ppT>());

    compute_G_gamma_pc.reset(
        new precompute_G1_gadget<ppT>(pb, *vk.G_gamma, *pvk.G_gamma_pc,
          FMT(annotation_prefix, " compute_G_gamma_pc")));
    compute_H_gamma_pc.reset(
        new precompute_G2_gadget<ppT>(pb, *vk.H_gamma, *pvk.H_gamma_pc,
          FMT(annotation_prefix, " compute_H_gamma_pc")));
    compute_H_pc.reset(
        new precompute_G2_gadget<ppT>(pb, *vk.H, *pvk.H_pc,
          FMT(annotation_prefix, " compute_H_pc")));
}

template<typename ppT>
void r1cs_se_ppzksnark_verifier_process_vk_gadget<ppT>::generate_r1cs_constraints()
{
    compute_G_gamma_pc->generate_r1cs_constraints();
    compute_H_gamma_pc->generate_r1cs_constraints();
    compute_H_pc->generate_r1cs_constraints();
}

template<typename ppT>
void r1cs_se_ppzksnark_verifier_process_vk_gadget<ppT>::generate_r1cs_witness()
{
    compute_G_gamma_pc->generate_r1cs_witness();
    compute_H_gamma_pc->generate_r1cs_witness();
    compute_H_pc->generate_r1cs_witness();
}

template<typename ppT>
r1cs_se_ppzksnark_online_verifier_gadget<ppT>::r1cs_se_ppzksnark_online_verifier_gadget(protoboard<FieldT> &pb,
                                                                                  const r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT> &pvk,
                                                                                  const pb_variable_array<FieldT> &input,
                                                                                  const size_t elt_size,
                                                                                  const r1cs_se_ppzksnark_proof_variable<ppT> &proof,
                                                                                  const pb_variable<FieldT> &result,
                                                                                  const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    input_len(input.size())
{
    // accumulate input and store base in acc
    acc.reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " acc")));
    std::vector<G1_variable<ppT> > IC_terms;
    for (size_t i = 0; i < pvk.query.size(); ++i)
    {
        IC_terms.emplace_back(*(pvk.query[i]));
    }
    accumulate_input.reset(
        new G1_multiscalar_mul_gadget<ppT>(pb, *(pvk.query_base), input, elt_size, IC_terms, *acc, FMT(annotation_prefix, " accumulate_input")));
    accumulated_verifier.reset(
        new r1cs_se_ppzksnark_accumulated_online_verifier_gadget<ppT>(
          pb, pvk, *acc, proof, result, FMT(annotation_prefix, " accumulated_verifier")));
}

template<typename ppT>
void r1cs_se_ppzksnark_online_verifier_gadget<ppT>::generate_r1cs_constraints()
{
    PROFILE_CONSTRAINTS(this->pb, "accumulate verifier input")
    {
        libff::print_indent(); printf("* Number of bits as an input to verifier gadget: %zu\n", input_len);
        accumulate_input->generate_r1cs_constraints();
    }

    PROFILE_CONSTRAINTS(this->pb, "rest of the verifier")
    {
        accumulated_verifier->generate_r1cs_constraints();
    }
}

template<typename ppT>
void r1cs_se_ppzksnark_online_verifier_gadget<ppT>::generate_r1cs_witness()
{
    accumulate_input->generate_r1cs_witness();
    accumulated_verifier->generate_r1cs_witness();
}

template<typename ppT>
r1cs_se_ppzksnark_accumulated_online_verifier_gadget<ppT>::r1cs_se_ppzksnark_accumulated_online_verifier_gadget(
    protoboard<FieldT> &pb,
    const r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT> &pvk,
    const G1_variable<ppT> &acc,
    const r1cs_se_ppzksnark_proof_variable<ppT> &proof,
    const pb_variable<FieldT> &result,
    const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    pvk(pvk),
    acc(acc),
    proof(proof),
    result(result)
{
    // allocate results for precomputation
    proof_A_G_alpha_precomp.reset(new G1_precomputation<ppT>());
    proof_B_H_beta_precomp.reset(new G2_precomputation<ppT>());

    acc_precomp.reset(new G1_precomputation<ppT>());

    proof_A_precomp.reset(new G1_precomputation<ppT>());
    proof_B_precomp.reset(new G2_precomputation<ppT>());
    proof_C_precomp.reset(new G1_precomputation<ppT>());

    // do the necessary precomputations
    proof_A_G_alpha.reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " proof_A_G_alpha")));
    compute_proof_A_G_alpha.reset(new G1_add_gadget<ppT>(pb, *(proof.A), *pvk.G_alpha , *proof_A_G_alpha, FMT(annotation_prefix, " compute_proof_A_G_alpha")));
    proof_B_H_beta.reset(new G2_variable<ppT>(pb, FMT(annotation_prefix, " proof_B_H_beta")));
    compute_proof_B_H_beta.reset(
        new G2_add_gadget<ppT>(pb,
          *(proof.B),
          *pvk.H_beta,
          *proof_B_H_beta,
          FMT(annotation_prefix, " compute_proof_B_H_beta")));

    compute_proof_A_G_alpha_precomp.reset(
        new precompute_G1_gadget<ppT>(pb, *proof_A_G_alpha, *proof_A_G_alpha_precomp,
          FMT(annotation_prefix, " compute_proof_A_G_alpha_precomp")));
    compute_proof_B_H_beta_precomp.reset(
        new precompute_G2_gadget<ppT>(pb, *proof_B_H_beta, *proof_B_H_beta_precomp,
          FMT(annotation_prefix, " compute_proof_B_H_beta_precomp")));

    compute_acc_precomp.reset(
        new precompute_G1_gadget<ppT>(pb, acc, *acc_precomp,
          FMT(annotation_prefix, " compute_acc_precomp")));

    compute_proof_A_precomp.reset(
        new precompute_G1_gadget<ppT>(pb, *(proof.A), *proof_A_precomp,
          FMT(annotation_prefix, " compute_proof_A_precomp")));
    compute_proof_B_precomp.reset(
        new precompute_G2_gadget<ppT>(pb, *(proof.B), *proof_B_precomp,
          FMT(annotation_prefix, " compute_proof_B_precomp")));
    compute_proof_C_precomp.reset(
        new precompute_G1_gadget<ppT>(pb, *(proof.C), *proof_C_precomp,
          FMT(annotation_prefix, " compute_proof_C_precomp")));

    // Now do the pairing checks
    /**
     * e(A*G^{alpha}, B*H^{beta}) = e(G^{alpha}, H^{beta}) * e(G^{acc}, H^{gamma}) * e(C, H)
     * where acc = \sum_{i=0}^l input_i pvk.query[i]
     *
     * We check instead (the equivalent condition)
     *
     * e(G^{acc}, H^{gamma}) * e(C, H) / e(A*G^{alpha}, B*H^{beta}) = 1 / e(G^{alpha}, H^{beta})
     */
    first_check_passed.allocate(pb, FMT(annotation_prefix, " first_check_passed"));
    first_check.reset(
        new check_e_times_e_over_e_equals_value_gadget<ppT>(pb,
          *acc_precomp, *(pvk.H_gamma_pc),
          *proof_C_precomp, *(pvk.H_pc),
          *proof_A_G_alpha_precomp, *proof_B_H_beta_precomp,
          *(pvk.G_alpha_H_beta_inv),
          first_check_passed,
          FMT(annotation_prefix, " first_check")));

    /**
     * e(A, H^{gamma}) = e(G^{gamma}, B)
     */
    second_check_passed.allocate(pb, FMT(annotation_prefix, " second_check_passed"));
    second_check.reset(
        new check_e_equals_e_gadget<ppT>(pb,
          *proof_A_precomp, *(pvk.H_gamma_pc),
          *(pvk.G_gamma_pc), *proof_B_precomp,
          second_check_passed,
          FMT(annotation_prefix, " second_check")));

    // final constraint
    all_test_results.emplace_back(first_check_passed);
    all_test_results.emplace_back(second_check_passed);

    all_tests_pass.reset(new conjunction_gadget<FieldT>(pb, all_test_results, result, FMT(annotation_prefix, " all_tests_pass")));
}

template<typename ppT>
void r1cs_se_ppzksnark_accumulated_online_verifier_gadget<ppT>::generate_r1cs_constraints()
{
    PROFILE_CONSTRAINTS(this->pb, "the accumulated verifier")
    {
        compute_proof_A_G_alpha->generate_r1cs_constraints();
        compute_proof_B_H_beta->generate_r1cs_constraints();

        compute_proof_A_G_alpha_precomp->generate_r1cs_constraints();
        compute_proof_B_H_beta_precomp->generate_r1cs_constraints();

        compute_acc_precomp->generate_r1cs_constraints();

        compute_proof_A_precomp->generate_r1cs_constraints();
        compute_proof_B_precomp->generate_r1cs_constraints();
        compute_proof_C_precomp->generate_r1cs_constraints();

        first_check->generate_r1cs_constraints();
        second_check->generate_r1cs_constraints();

        all_tests_pass->generate_r1cs_constraints();
    }
}

template<typename ppT>
void r1cs_se_ppzksnark_accumulated_online_verifier_gadget<ppT>::generate_r1cs_witness()
{
    compute_proof_A_G_alpha->generate_r1cs_witness();
    compute_proof_B_H_beta->generate_r1cs_witness();

    compute_proof_A_G_alpha_precomp->generate_r1cs_witness();
    compute_proof_B_H_beta_precomp->generate_r1cs_witness();

    compute_acc_precomp->generate_r1cs_witness();

    compute_proof_A_precomp->generate_r1cs_witness();
    compute_proof_B_precomp->generate_r1cs_witness();
    compute_proof_C_precomp->generate_r1cs_witness();

    first_check->generate_r1cs_witness();
    second_check->generate_r1cs_witness();

    all_tests_pass->generate_r1cs_witness();
}

template<typename ppT>
r1cs_se_ppzksnark_verifier_gadget<ppT>::r1cs_se_ppzksnark_verifier_gadget(protoboard<FieldT> &pb,
                                                                    const r1cs_se_ppzksnark_verification_key_variable<ppT> &vk,
                                                                    const pb_variable_array<FieldT> &input,
                                                                    const size_t elt_size,
                                                                    const r1cs_se_ppzksnark_proof_variable<ppT> &proof,
                                                                    const pb_variable<FieldT> &result,
                                                                    const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix)
{
    pvk.reset(new r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT>());
    compute_pvk.reset(new r1cs_se_ppzksnark_verifier_process_vk_gadget<ppT>(pb, vk, *pvk, FMT(annotation_prefix, " compute_pvk")));
    online_verifier.reset(new r1cs_se_ppzksnark_online_verifier_gadget<ppT>(pb, *pvk, input, elt_size, proof, result, FMT(annotation_prefix, " online_verifier")));
}

template<typename ppT>
void r1cs_se_ppzksnark_verifier_gadget<ppT>::generate_r1cs_constraints()
{
    PROFILE_CONSTRAINTS(this->pb, "precompute pvk")
    {
        compute_pvk->generate_r1cs_constraints();
    }

    PROFILE_CONSTRAINTS(this->pb, "online verifier")
    {
        online_verifier->generate_r1cs_constraints();
    }
}

template<typename ppT>
void r1cs_se_ppzksnark_verifier_gadget<ppT>::generate_r1cs_witness()
{
    compute_pvk->generate_r1cs_witness();
    online_verifier->generate_r1cs_witness();
}

// accumulated verifier
template<typename ppT>
r1cs_se_ppzksnark_accumulated_verifier_gadget<ppT>::r1cs_se_ppzksnark_accumulated_verifier_gadget(protoboard<FieldT> &pb,
                                   const r1cs_se_ppzksnark_verification_key_variable<ppT> &vk,
                                   const G1_variable<ppT> &acc,
                                   const r1cs_se_ppzksnark_proof_variable<ppT> &proof,
                                   const pb_variable<FieldT> &result,
                                   const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix)
{
    pvk.reset(new r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT>());
    compute_pvk.reset(new r1cs_se_ppzksnark_verifier_process_vk_gadget<ppT>(pb, vk, *pvk, FMT(annotation_prefix, " compute_pvk")));
    online_verifier.reset(new r1cs_se_ppzksnark_accumulated_online_verifier_gadget<ppT>(pb, *pvk, acc, proof, result, FMT(annotation_prefix, " online_verifier")));
}

template<typename ppT>
void r1cs_se_ppzksnark_accumulated_verifier_gadget<ppT>::generate_r1cs_constraints()
{
    PROFILE_CONSTRAINTS(this->pb, "precompute pvk")
    {
        compute_pvk->generate_r1cs_constraints();
    }

    PROFILE_CONSTRAINTS(this->pb, "online verifier")
    {
        online_verifier->generate_r1cs_constraints();
    }
}

template<typename ppT>
void r1cs_se_ppzksnark_accumulated_verifier_gadget<ppT>::generate_r1cs_witness()
{
    compute_pvk->generate_r1cs_witness();
    online_verifier->generate_r1cs_witness();
}


} // libsnark

#endif // R1CS_SE_PPZKSNARK_VERIFIER_GADGET_TCC_
