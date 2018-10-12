/** @file
 *****************************************************************************

 Implementation of interfaces for the the R1CS ppzkSNARK verifier gadget.

 See r1cs_gg_ppzksnark_verifier_gadget.hpp .

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef R1CS_GG_PPZKSNARK_VERIFIER_GADGET_TCC_
#define R1CS_GG_PPZKSNARK_VERIFIER_GADGET_TCC_

#include <libsnark/gadgetlib1/constraint_profiling.hpp>

namespace libsnark {

template<typename ppT>
r1cs_gg_ppzksnark_proof_variable<ppT>::r1cs_gg_ppzksnark_proof_variable(protoboard<FieldT> &pb,
                                                                  const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix)
{
    const size_t num_G1 = 2;
    const size_t num_G2 = 1;

    g_A.reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " g_A")));
    g_B.reset(new G2_variable<ppT>(pb, FMT(annotation_prefix, " g_B")));
    g_C.reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " g_C")));

    all_G1_vars = { g_A, g_C };
    all_G2_vars = { g_B };

    all_G1_checkers.resize(all_G1_vars.size());

    for (size_t i = 0; i < all_G1_vars.size(); ++i)
    {
        all_G1_checkers[i].reset(new G1_checker_gadget<ppT>(pb, *all_G1_vars[i], FMT(annotation_prefix, " all_G1_checkers_%zu", i)));
    }
    G2_checker.reset(new G2_checker_gadget<ppT>(pb, *g_B, FMT(annotation_prefix, " G2_checker")));

    assert(all_G1_vars.size() == num_G1);
    assert(all_G2_vars.size() == num_G2);
}

template<typename ppT>
void r1cs_gg_ppzksnark_proof_variable<ppT>::generate_r1cs_constraints()
{
    for (auto &G1_checker : all_G1_checkers)
    {
        G1_checker->generate_r1cs_constraints();
    }

    G2_checker->generate_r1cs_constraints();
}

template<typename ppT>
void r1cs_gg_ppzksnark_proof_variable<ppT>::generate_r1cs_witness(const r1cs_gg_ppzksnark_proof<other_curve<ppT> > &proof)
{
    std::vector<libff::G1<other_curve<ppT> > > G1_elems;
    std::vector<libff::G2<other_curve<ppT> > > G2_elems;

    G1_elems = { proof.g_A, proof.g_C };
    G2_elems = { proof.g_B };

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
size_t r1cs_gg_ppzksnark_proof_variable<ppT>::size()
{
    const size_t num_G1 = 2;
    const size_t num_G2 = 1;
    return (num_G1 * G1_variable<ppT>::num_field_elems + num_G2 * G2_variable<ppT>::num_field_elems);
}

template<typename ppT>
r1cs_gg_ppzksnark_verification_key_variable<ppT>::r1cs_gg_ppzksnark_verification_key_variable(protoboard<FieldT> &pb,
                                                                                        const pb_variable_array<FieldT> &all_bits,
                                                                                        const size_t input_size,
                                                                                        const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    all_bits(all_bits),
    input_size(input_size)
{
    const size_t num_G1 = (input_size + 1);
    const size_t num_G2 = 2;
    const size_t num_GT = 1;

    assert(all_bits.size() ==
        (G1_variable<ppT>::size_in_bits() * num_G1
         + G2_variable<ppT>::size_in_bits() * num_G2
         + Fqk_variable<ppT>::size_in_bits() * num_GT));

    this->alpha_g1_beta_g2_inv.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix,  "alpha_g1_beta_g2_inv")));
    this->gamma_g2.reset(new G2_variable<ppT>(pb, FMT(annotation_prefix, " gamma_g2")));
    this->delta_g2.reset(new G2_variable<ppT>(pb, FMT(annotation_prefix, " delta_g2")));

    all_G1_vars = { };
    all_G2_vars = { this->gamma_g2, this->delta_g2 };
    all_GT_vars = { this->alpha_g1_beta_g2_inv };

    this->gamma_ABC_g1.resize(input_size);
    this->encoded_IC_base.reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " encoded_IC_base")));
    this->all_G1_vars.emplace_back(this->encoded_IC_base);

    for (size_t i = 0; i < input_size; ++i)
    {
        this->gamma_ABC_g1[i].reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " gamma_ABC_g1_%zu", i)));
        all_G1_vars.emplace_back(this->gamma_ABC_g1[i]);
    }

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

    packer.reset(new multipacking_gadget<FieldT>(pb, all_bits, all_vars, FieldT::size_in_bits(), FMT(annotation_prefix, " packer")));
}

template<typename ppT>
void r1cs_gg_ppzksnark_verification_key_variable<ppT>::generate_r1cs_constraints(const bool enforce_bitness)
{
    packer->generate_r1cs_constraints(enforce_bitness);
}

template<typename ppT>
void r1cs_gg_ppzksnark_verification_key_variable<ppT>::generate_r1cs_witness(const r1cs_gg_ppzksnark_verification_key<other_curve<ppT> > &vk)
{
    std::vector<libff::G1<other_curve<ppT> > > G1_elems;
    std::vector<libff::G2<other_curve<ppT> > > G2_elems;
    std::vector<libff::Fqk<other_curve<ppT>>> GT_elems;

    G1_elems = { };
    G2_elems = { vk.gamma_g2, vk.delta_g2 };
    GT_elems = { vk.alpha_g1_beta_g2.inverse() };

    assert(vk.gamma_ABC_g1.rest.indices.size() == input_size);
    G1_elems.emplace_back(vk.gamma_ABC_g1.first);
    for (size_t i = 0; i < input_size; ++i)
    {
        assert(vk.gamma_ABC_g1.rest.indices[i] == i);
        G1_elems.emplace_back(vk.gamma_ABC_g1.rest.values[i]);
    }

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

    packer->generate_r1cs_witness_from_packed();
}

template<typename ppT>
void r1cs_gg_ppzksnark_verification_key_variable<ppT>::generate_r1cs_witness(const libff::bit_vector &vk_bits)
{
    all_bits.fill_with_bits(this->pb, vk_bits);
    packer->generate_r1cs_witness_from_bits();
}

template<typename ppT>
libff::bit_vector r1cs_gg_ppzksnark_verification_key_variable<ppT>::get_bits() const
{
    return all_bits.get_bits(this->pb);
}

template<typename ppT>
size_t r1cs_gg_ppzksnark_verification_key_variable<ppT>::size_in_bits(const size_t input_size)
{
    const size_t num_G1 = input_size + 1;
    const size_t num_G2 = 2;
    const size_t num_GT = 1;
    const size_t result = G1_variable<ppT>::size_in_bits() * num_G1 + G2_variable<ppT>::size_in_bits() * num_G2 + Fqk_variable<ppT>::size_in_bits() * num_GT;
    printf("G1_size_in_bits = %zu, G2_size_in_bits = %zu\n", G1_variable<ppT>::size_in_bits(), G2_variable<ppT>::size_in_bits());
    printf("r1cs_gg_ppzksnark_verification_key_variable<ppT>::size_in_bits(%zu) = %zu\n", input_size, result);
    return result;
}

template<typename ppT>
libff::bit_vector r1cs_gg_ppzksnark_verification_key_variable<ppT>::get_verification_key_bits(const r1cs_gg_ppzksnark_verification_key<other_curve<ppT> > &r1cs_vk)
{
    typedef libff::Fr<ppT> FieldT;

    const size_t input_size_in_elts = r1cs_vk.gamma_ABC_g1.rest.indices.size(); // this might be approximate for bound verification keys, however they are not supported by r1cs_ppzksnark_verification_key_variable
    const size_t vk_size_in_bits = r1cs_gg_ppzksnark_verification_key_variable<ppT>::size_in_bits(input_size_in_elts);

    protoboard<FieldT> pb;
    pb_variable_array<FieldT> vk_bits;
    vk_bits.allocate(pb, vk_size_in_bits, "vk_bits");
    r1cs_gg_ppzksnark_verification_key_variable<ppT> vk(pb, vk_bits, input_size_in_elts, "translation_step_vk");
    vk.generate_r1cs_witness(r1cs_vk);

    return vk.get_bits();
}

template<typename ppT>
r1cs_gg_ppzksnark_preprocessed_r1cs_gg_ppzksnark_verification_key_variable<ppT>::r1cs_gg_ppzksnark_preprocessed_r1cs_gg_ppzksnark_verification_key_variable()
{
    // will be allocated outside
}

template<typename ppT>
r1cs_gg_ppzksnark_preprocessed_r1cs_gg_ppzksnark_verification_key_variable<ppT>::r1cs_gg_ppzksnark_preprocessed_r1cs_gg_ppzksnark_verification_key_variable(protoboard<FieldT> &pb,
                                                                                                                                                const r1cs_gg_ppzksnark_verification_key<other_curve<ppT> > &r1cs_vk,
                                                                                                                                                const std::string &annotation_prefix)
{
    vk_alpha_g1_beta_g2_inv.reset(new Fqk_variable<ppT>(pb, r1cs_vk.alpha_g1_beta_g2.inverse(), FMT(annotation_prefix, " vk_alpha_g1_beta_g2_inv")));
    encoded_IC_base.reset(new G1_variable<ppT>(pb, r1cs_vk.gamma_ABC_g1.first, FMT(annotation_prefix, " gamma_ABC_g1")));
    gamma_ABC_g1.resize(r1cs_vk.gamma_ABC_g1.rest.indices.size());
    for (size_t i = 0; i < r1cs_vk.gamma_ABC_g1.rest.indices.size(); ++i)
    {
        assert(r1cs_vk.gamma_ABC_g1.rest.indices[i] == i);
        gamma_ABC_g1[i].reset(new G1_variable<ppT>(pb, r1cs_vk.gamma_ABC_g1.rest.values[i], FMT(annotation_prefix, " gamma_ABC_g1")));
    }

    vk_gamma_g2_precomp.reset(new G2_precomputation<ppT>(pb, r1cs_vk.gamma_g2, FMT(annotation_prefix, "vk_gamma_g2_precomp")));
    vk_delta_g2_precomp.reset(new G2_precomputation<ppT>(pb, r1cs_vk.delta_g2, FMT(annotation_prefix, "vk_delta_g2_precomp")));
}

template<typename ppT>
r1cs_gg_ppzksnark_verifier_process_vk_gadget<ppT>::r1cs_gg_ppzksnark_verifier_process_vk_gadget(protoboard<FieldT> &pb,
                                                                                          const r1cs_gg_ppzksnark_verification_key_variable<ppT> &vk,
                                                                                          r1cs_gg_ppzksnark_preprocessed_r1cs_gg_ppzksnark_verification_key_variable<ppT> &pvk,
                                                                                          const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    vk(vk),
    pvk(pvk)
{
    pvk.encoded_IC_base = vk.encoded_IC_base;
    pvk.gamma_ABC_g1 = vk.gamma_ABC_g1;
    pvk.vk_alpha_g1_beta_g2_inv = vk.alpha_g1_beta_g2_inv;

    pvk.vk_gamma_g2_precomp.reset(new G2_precomputation<ppT>());
    pvk.vk_delta_g2_precomp.reset(new G2_precomputation<ppT>());

    compute_vk_gamma_g2_precomp.reset(new precompute_G2_gadget<ppT>(pb, *vk.gamma_g2, *pvk.vk_gamma_g2_precomp, FMT(annotation_prefix, " compute_vk_gamma_g2_precomp")));
    compute_vk_delta_g2_precomp.reset(new precompute_G2_gadget<ppT>(pb, *vk.delta_g2, *pvk.vk_delta_g2_precomp, FMT(annotation_prefix, " compute_vk_delta_g2_precomp")));
}

template<typename ppT>
void r1cs_gg_ppzksnark_verifier_process_vk_gadget<ppT>::generate_r1cs_constraints()
{
    compute_vk_gamma_g2_precomp->generate_r1cs_constraints();
    compute_vk_delta_g2_precomp->generate_r1cs_constraints();
}

template<typename ppT>
void r1cs_gg_ppzksnark_verifier_process_vk_gadget<ppT>::generate_r1cs_witness()
{
    compute_vk_gamma_g2_precomp->generate_r1cs_witness();
    compute_vk_delta_g2_precomp->generate_r1cs_witness();
}

template<typename ppT>
r1cs_gg_ppzksnark_online_verifier_gadget<ppT>::r1cs_gg_ppzksnark_online_verifier_gadget(protoboard<FieldT> &pb,
                                                                                  const r1cs_gg_ppzksnark_preprocessed_r1cs_gg_ppzksnark_verification_key_variable<ppT> &pvk,
                                                                                  const pb_variable_array<FieldT> &input,
                                                                                  const size_t elt_size,
                                                                                  const r1cs_gg_ppzksnark_proof_variable<ppT> &proof,
                                                                                  const pb_variable<FieldT> &result,
                                                                                  const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    pvk(pvk),
    input(input),
    elt_size(elt_size),
    proof(proof),
    result(result),
    input_len(input.size())
{
    // accumulate input and store base in acc
    acc.reset(new G1_variable<ppT>(pb, FMT(annotation_prefix, " acc")));
    std::vector<G1_variable<ppT> > IC_terms;
    for (size_t i = 0; i < pvk.gamma_ABC_g1.size(); ++i)
    {
        IC_terms.emplace_back(*(pvk.gamma_ABC_g1[i]));
    }
    accumulate_input.reset(new G1_multiscalar_mul_gadget<ppT>(pb, *(pvk.encoded_IC_base), input, elt_size, IC_terms, *acc, FMT(annotation_prefix, " accumulate_input")));

    // allocate results for precomputation
    proof_g_A_precomp.reset(new G1_precomputation<ppT>());
    proof_g_B_precomp.reset(new G2_precomputation<ppT>());
    proof_g_C_precomp.reset(new G1_precomputation<ppT>());
    acc_precomp.reset(new G1_precomputation<ppT>());

    // do the necessary precomputations
    // compute things not available in plain from proof/vk

    compute_proof_g_A_precomp.reset(new precompute_G1_gadget<ppT>(pb, *(proof.g_A), *proof_g_A_precomp, FMT(annotation_prefix, " compute_proof_g_A_precomp")));
    compute_proof_g_B_precomp.reset(new precompute_G2_gadget<ppT>(pb, *(proof.g_B), *proof_g_B_precomp, FMT(annotation_prefix, " compute_proof_g_B_precomp")));
    compute_proof_g_C_precomp.reset(new precompute_G1_gadget<ppT>(pb, *(proof.g_C), *proof_g_C_precomp, FMT(annotation_prefix, " compute_proof_g_C_precomp")));
    compute_acc_precomp.reset(new precompute_G1_gadget<ppT>(pb, *acc, *acc_precomp, FMT(annotation_prefix, " compute_acc_precomp")));

    // check QAP
    check_QAP_valid.reset(
        new check_e_times_e_over_e_equals_value_gadget<ppT>(
          pb,
          *acc_precomp, *(pvk.vk_gamma_g2_precomp),
          *proof_g_C_precomp, *(pvk.vk_delta_g2_precomp),
          *proof_g_A_precomp, *proof_g_B_precomp,
          *(pvk.vk_alpha_g1_beta_g2_inv),
          result,
          FMT(annotation_prefix, " check_QAP_valid")));
}

template<typename ppT>
void r1cs_gg_ppzksnark_online_verifier_gadget<ppT>::generate_r1cs_constraints()
{
    PROFILE_CONSTRAINTS(this->pb, "accumulate verifier input")
    {
        libff::print_indent(); printf("* Number of bits as an input to verifier gadget: %zu\n", input.size());
        accumulate_input->generate_r1cs_constraints();
    }

    PROFILE_CONSTRAINTS(this->pb, "rest of the verifier")
    {
        compute_proof_g_A_precomp->generate_r1cs_constraints();
        compute_proof_g_B_precomp->generate_r1cs_constraints();
        compute_proof_g_C_precomp->generate_r1cs_constraints();
        compute_acc_precomp->generate_r1cs_constraints();

        check_QAP_valid->generate_r1cs_constraints();
    }
}

template<typename ppT>
void r1cs_gg_ppzksnark_online_verifier_gadget<ppT>::generate_r1cs_witness()
{
    accumulate_input->generate_r1cs_witness();

    compute_proof_g_A_precomp->generate_r1cs_witness();
    compute_proof_g_B_precomp->generate_r1cs_witness();
    compute_proof_g_C_precomp->generate_r1cs_witness();
    compute_acc_precomp->generate_r1cs_witness();

    check_QAP_valid->generate_r1cs_witness();
}

template<typename ppT>
r1cs_gg_ppzksnark_verifier_gadget<ppT>::r1cs_gg_ppzksnark_verifier_gadget(protoboard<FieldT> &pb,
                                                                    const r1cs_gg_ppzksnark_verification_key_variable<ppT> &vk,
                                                                    const pb_variable_array<FieldT> &input,
                                                                    const size_t elt_size,
                                                                    const r1cs_gg_ppzksnark_proof_variable<ppT> &proof,
                                                                    const pb_variable<FieldT> &result,
                                                                    const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix)
{
    pvk.reset(new r1cs_gg_ppzksnark_preprocessed_r1cs_gg_ppzksnark_verification_key_variable<ppT>());
    compute_pvk.reset(new r1cs_gg_ppzksnark_verifier_process_vk_gadget<ppT>(pb, vk, *pvk, FMT(annotation_prefix, " compute_pvk")));
    online_verifier.reset(new r1cs_gg_ppzksnark_online_verifier_gadget<ppT>(pb, *pvk, input, elt_size, proof, result, FMT(annotation_prefix, " online_verifier")));
}

template<typename ppT>
void r1cs_gg_ppzksnark_verifier_gadget<ppT>::generate_r1cs_constraints()
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
void r1cs_gg_ppzksnark_verifier_gadget<ppT>::generate_r1cs_witness()
{
    compute_pvk->generate_r1cs_witness();
    online_verifier->generate_r1cs_witness();
}

} // libsnark

#endif // R1CS_GG_PPZKSNARK_VERIFIER_GADGET_TCC_
