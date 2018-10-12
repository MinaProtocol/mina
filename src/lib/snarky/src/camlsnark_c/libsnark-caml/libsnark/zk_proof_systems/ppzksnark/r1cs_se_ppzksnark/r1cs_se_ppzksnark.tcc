/** @file
*****************************************************************************

Implementation of interfaces for a SEppzkSNARK for R1CS.

See r1cs_se_ppzksnark.hpp .

*****************************************************************************
* @author     This file is part of libsnark, developed by SCIPR Lab
*             and contributors (see AUTHORS).
* @copyright  MIT license (see LICENSE file)
*****************************************************************************/

#ifndef R1CS_SE_PPZKSNARK_TCC_
#define R1CS_SE_PPZKSNARK_TCC_

#include <algorithm>
#include <cassert>
#include <functional>
#include <iostream>
#include <sstream>

#include <libff/algebra/scalar_multiplication/multiexp.hpp>
#include <libff/common/profiling.hpp>
#include <libff/common/utils.hpp>

#ifdef MULTICORE
#include <omp.h>
#endif

#include <libsnark/knowledge_commitment/kc_multiexp.hpp>
#include <libsnark/reductions/r1cs_to_sap/r1cs_to_sap.hpp>

namespace libsnark {

template<typename ppT>
bool r1cs_se_ppzksnark_proving_key<ppT>::operator==(const r1cs_se_ppzksnark_proving_key<ppT> &other) const
{
    return (this->A_query == other.A_query &&
            this->B_query == other.B_query &&
            this->C_query_1 == other.C_query_1 &&
            this->C_query_2 == other.C_query_2 &&
            this->G_gamma_Z == other.G_gamma_Z &&
            this->H_gamma_Z == other.H_gamma_Z &&
            this->G_ab_gamma_Z == other.G_ab_gamma_Z &&
            this->G_gamma2_Z2 == other.G_gamma2_Z2 &&
            this->G_gamma2_Z_t == other.G_gamma2_Z_t &&
            this->constraint_system == other.constraint_system);
}

template<typename ppT>
std::ostream& operator<<(std::ostream &out, const r1cs_se_ppzksnark_proving_key<ppT> &pk)
{
    out << pk.A_query;
    out << pk.B_query;
    out << pk.C_query_1;
    out << pk.C_query_2;
    out << pk.G_gamma_Z;
    out << pk.H_gamma_Z;
    out << pk.G_ab_gamma_Z;
    out << pk.G_gamma2_Z2;
    out << pk.G_gamma2_Z_t;
    out << pk.constraint_system;

    return out;
}

template<typename ppT>
std::istream& operator>>(std::istream &in, r1cs_se_ppzksnark_proving_key<ppT> &pk)
{
    in >> pk.A_query;
    in >> pk.B_query;
    in >> pk.C_query_1;
    in >> pk.C_query_2;
    in >> pk.G_gamma_Z;
    in >> pk.H_gamma_Z;
    in >> pk.G_ab_gamma_Z;
    in >> pk.G_gamma2_Z2;
    in >> pk.G_gamma2_Z_t;
    in >> pk.constraint_system;

    return in;
}

template<typename ppT>
bool r1cs_se_ppzksnark_verification_key<ppT>::operator==(const r1cs_se_ppzksnark_verification_key<ppT> &other) const
{
    return (this->H == other.H &&
            this->G_alpha == other.G_alpha &&
            this->H_beta == other.H_beta &&
            this->G_gamma == other.G_gamma &&
            this->H_gamma == other.H_gamma &&
            this->query == other.query);
}

template<typename ppT>
std::ostream& operator<<(std::ostream &out, const r1cs_se_ppzksnark_verification_key<ppT> &vk)
{
    out << vk.H << OUTPUT_NEWLINE;
    out << vk.G_alpha << OUTPUT_NEWLINE;
    out << vk.H_beta << OUTPUT_NEWLINE;
    out << vk.G_gamma << OUTPUT_NEWLINE;
    out << vk.H_gamma << OUTPUT_NEWLINE;
    out << vk.G_alpha_H_beta << OUTPUT_NEWLINE;
    out << vk.query << OUTPUT_NEWLINE;

    return out;
}

template<typename ppT>
std::istream& operator>>(std::istream &in, r1cs_se_ppzksnark_verification_key<ppT> &vk)
{
    in >> vk.H;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> vk.G_alpha;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> vk.H_beta;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> vk.G_gamma;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> vk.H_gamma;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> vk.G_alpha_H_beta;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> vk.query;
    libff::consume_OUTPUT_NEWLINE(in);

    return in;
}

template<typename ppT>
bool r1cs_se_ppzksnark_processed_verification_key<ppT>::operator==(const r1cs_se_ppzksnark_processed_verification_key<ppT> &other) const
{
    return (this->G_alpha == other.G_alpha &&
            this->H_beta == other.H_beta &&
            this->G_alpha_H_beta == other.G_alpha_H_beta &&
            this->G_gamma_pc == other.G_gamma_pc &&
            this->H_gamma_pc == other.H_gamma_pc &&
            this->H_pc == other.H_pc &&
            this->query == other.query);
}

template<typename ppT>
std::ostream& operator<<(std::ostream &out, const r1cs_se_ppzksnark_processed_verification_key<ppT> &pvk)
{
    out << pvk.G_alpha << OUTPUT_NEWLINE;
    out << pvk.H_beta << OUTPUT_NEWLINE;
    out << pvk.G_alpha_H_beta << OUTPUT_NEWLINE;
    out << pvk.G_gamma_pc << OUTPUT_NEWLINE;
    out << pvk.H_gamma_pc << OUTPUT_NEWLINE;
    out << pvk.H_pc << OUTPUT_NEWLINE;
    out << pvk.query << OUTPUT_NEWLINE;

    return out;
}

template<typename ppT>
std::istream& operator>>(std::istream &in, r1cs_se_ppzksnark_processed_verification_key<ppT> &pvk)
{
    in >> pvk.G_alpha;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> pvk.H_beta;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> pvk.G_alpha_H_beta;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> pvk.G_gamma_pc;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> pvk.H_gamma_pc;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> pvk.H_pc;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> pvk.query;
    libff::consume_OUTPUT_NEWLINE(in);

    return in;
}

template<typename ppT>
bool r1cs_se_ppzksnark_proof<ppT>::operator==(const r1cs_se_ppzksnark_proof<ppT> &other) const
{
    return (this->A == other.A &&
            this->B == other.B &&
            this->C == other.C);
}

template<typename ppT>
std::ostream& operator<<(std::ostream &out, const r1cs_se_ppzksnark_proof<ppT> &proof)
{
    out << proof.A << OUTPUT_NEWLINE;
    out << proof.B << OUTPUT_NEWLINE;
    out << proof.C << OUTPUT_NEWLINE;

    return out;
}

template<typename ppT>
std::istream& operator>>(std::istream &in, r1cs_se_ppzksnark_proof<ppT> &proof)
{
    in >> proof.A;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> proof.B;
    libff::consume_OUTPUT_NEWLINE(in);
    in >> proof.C;
    libff::consume_OUTPUT_NEWLINE(in);

    return in;
}

template<typename ppT>
r1cs_se_ppzksnark_verification_key<ppT> r1cs_se_ppzksnark_verification_key<ppT>::dummy_verification_key(const size_t input_size)
{
    r1cs_se_ppzksnark_verification_key<ppT> result;
    result.H = libff::Fr<ppT>::random_element() * libff::G2<ppT>::one();
    result.G_alpha = libff::Fr<ppT>::random_element() * libff::G1<ppT>::one();
    result.H_beta = libff::Fr<ppT>::random_element() * libff::G2<ppT>::one();
    result.G_gamma = libff::Fr<ppT>::random_element() * libff::G1<ppT>::one();
    result.H_gamma = libff::Fr<ppT>::random_element() * libff::G2<ppT>::one();
    result.G_alpha_H_beta = ppT::reduced_pairing(result.G_alpha, result.H_beta);

    libff::G1_vector<ppT> v;
    for (size_t i = 0; i < input_size + 1; ++i)
    {
        v.emplace_back(libff::Fr<ppT>::random_element() * libff::G1<ppT>::one());
    }
    result.query = std::move(v);

    return result;
}

template <typename ppT>
r1cs_se_ppzksnark_keypair<ppT> r1cs_se_ppzksnark_generator(const r1cs_se_ppzksnark_constraint_system<ppT> &cs)
{
    libff::enter_block("Call to r1cs_se_ppzksnark_generator");

    /**
     * draw random element t at which the SAP is evaluated.
     * it should be the case that Z(t) != 0
     */
    const std::shared_ptr<libfqfft::evaluation_domain<libff::Fr<ppT> > > domain =
        r1cs_to_sap_get_domain(cs);
    libff::Fr<ppT> t;
    do {
        t = libff::Fr<ppT>::random_element();
    } while (domain->compute_vanishing_polynomial(t).is_zero());

    sap_instance_evaluation<libff::Fr<ppT> > sap_inst = r1cs_to_sap_instance_map_with_evaluation(cs, t);

    libff::print_indent(); printf("* SAP number of variables: %zu\n", sap_inst.num_variables());
    libff::print_indent(); printf("* SAP pre degree: %zu\n", cs.constraints.size());
    libff::print_indent(); printf("* SAP degree: %zu\n", sap_inst.degree());
    libff::print_indent(); printf("* SAP number of input variables: %zu\n", sap_inst.num_inputs());

    libff::enter_block("Compute query densities");
    size_t non_zero_At = 0;
    for (size_t i = 0; i < sap_inst.num_variables()+1; ++i)
    {
        if (!sap_inst.At[i].is_zero())
        {
            ++non_zero_At;
        }
    }
    libff::leave_block("Compute query densities");

    libff::Fr_vector<ppT> At = std::move(sap_inst.At);
    libff::Fr_vector<ppT> Ct = std::move(sap_inst.Ct);
    libff::Fr_vector<ppT> Ht = std::move(sap_inst.Ht);
    /**
     * sap_inst.{A,C,H}t are now in an unspecified state,
     * but we do not use them below
     */

    const  libff::Fr<ppT> alpha = libff::Fr<ppT>::random_element(),
        beta = libff::Fr<ppT>::random_element(),
        gamma = libff::Fr<ppT>::random_element();
    const libff::G1<ppT> G = libff::G1<ppT>::random_element();
    const libff::G2<ppT> H = libff::G2<ppT>::random_element();

    libff::enter_block("Generating G multiexp table");
    size_t G_exp_count = sap_inst.num_inputs() + 1 // verifier_query
                         + non_zero_At // A_query
                         + sap_inst.degree() + 1 // G_gamma2_Z_t
                         // C_query_1
                         + sap_inst.num_variables() - sap_inst.num_inputs()
                         + sap_inst.num_variables() + 1, // C_query_2
           G_window = libff::get_exp_window_size<libff::G1<ppT> >(G_exp_count);
    libff::print_indent(); printf("* G window: %zu\n", G_window);
    libff::window_table<libff::G1<ppT> > G_table = get_window_table(
        libff::Fr<ppT>::size_in_bits(), G_window, G);
    libff::leave_block("Generating G multiexp table");

    libff::enter_block("Generating H_gamma multiexp table");
    libff::G2<ppT> H_gamma = gamma * H;
    size_t H_gamma_exp_count = non_zero_At, // B_query
           H_gamma_window = libff::get_exp_window_size<libff::G2<ppT> >(H_gamma_exp_count);
    libff::print_indent(); printf("* H_gamma window: %zu\n", H_gamma_window);
    libff::window_table<libff::G2<ppT> > H_gamma_table = get_window_table(
        libff::Fr<ppT>::size_in_bits(), H_gamma_window, H_gamma);
    libff::leave_block("Generating H_gamma multiexp table");

    libff::enter_block("Generate R1CS verification key");
    libff::G1<ppT> G_alpha = alpha * G;
    libff::G2<ppT> H_beta = beta * H;

    libff::Fr_vector<ppT> tmp_exponents;
    tmp_exponents.reserve(sap_inst.num_inputs() + 1);
    for (size_t i = 0; i <= sap_inst.num_inputs(); ++i)
    {
        tmp_exponents.emplace_back(gamma * Ct[i] + (alpha + beta) * At[i]);
    }
    libff::G1_vector<ppT> verifier_query = libff::batch_exp<libff::G1<ppT>,
                                                            libff::Fr<ppT> >(
        libff::Fr<ppT>::size_in_bits(),
        G_window,
        G_table,
        tmp_exponents);
    tmp_exponents.clear();

    libff::leave_block("Generate R1CS verification key");

    libff::enter_block("Generate R1CS proving key");

    libff::enter_block("Compute the A-query", false);
    tmp_exponents.reserve(sap_inst.num_variables() + 1);
    for (size_t i = 0; i < At.size(); i++)
    {
        tmp_exponents.emplace_back(gamma * At[i]);
    }

    libff::G1_vector<ppT> A_query = libff::batch_exp<libff::G1<ppT>,
                                                     libff::Fr<ppT> >(
        libff::Fr<ppT>::size_in_bits(),
        G_window,
        G_table,
        tmp_exponents);
    tmp_exponents.clear();
#ifdef USE_MIXED_ADDITION
    libff::batch_to_special<libff::G1<ppT> >(A_query);
#endif
    libff::leave_block("Compute the A-query", false);

    libff::enter_block("Compute the B-query", false);
    libff::G2_vector<ppT> B_query = libff::batch_exp<libff::G2<ppT>,
                                                     libff::Fr<ppT> >(
        libff::Fr<ppT>::size_in_bits(),
        H_gamma_window,
        H_gamma_table,
        At);
#ifdef USE_MIXED_ADDITION
    libff::batch_to_special<libff::G2<ppT> >(B_query);
#endif
    libff::leave_block("Compute the B-query", false);

    libff::enter_block("Compute the G_gamma-query", false);
    libff::G1<ppT> G_gamma = gamma * G;
    libff::G1<ppT> G_gamma_Z = sap_inst.Zt * G_gamma;
    libff::G2<ppT> H_gamma_Z = sap_inst.Zt * H_gamma;
    libff::G1<ppT> G_ab_gamma_Z = (alpha + beta) * G_gamma_Z;
    libff::G1<ppT> G_gamma2_Z2 = (sap_inst.Zt * gamma) * G_gamma_Z;

    tmp_exponents.reserve(sap_inst.degree() + 1);

    /* Compute the vector G_gamma2_Z_t := Z(t) * t^i * gamma^2 * G */
    libff::Fr<ppT> gamma2_Z_t = sap_inst.Zt * gamma.squared();
    for (size_t i = 0; i < sap_inst.degree() + 1; ++i)
    {
        tmp_exponents.emplace_back(gamma2_Z_t);
        gamma2_Z_t *= t;
    }
    libff::G1_vector<ppT> G_gamma2_Z_t = libff::batch_exp<libff::G1<ppT>,
                                                          libff::Fr<ppT> >(
        libff::Fr<ppT>::size_in_bits(),
        G_window,
        G_table,
        tmp_exponents);
    tmp_exponents.clear();
#ifdef USE_MIXED_ADDITION
    libff::batch_to_special<libff::G1<ppT> >(G_gamma2_Z_t);
#endif
    libff::leave_block("Compute the G_gamma-query", false);

    libff::enter_block("Compute the C_1-query", false);
    tmp_exponents.reserve(sap_inst.num_variables() - sap_inst.num_inputs());
    for (size_t i = sap_inst.num_inputs() + 1;
         i <= sap_inst.num_variables();
         ++i)
    {
        tmp_exponents.emplace_back(gamma *
            (gamma * Ct[i] + (alpha + beta) * At[i]));
    }
    libff::G1_vector<ppT> C_query_1 = libff::batch_exp<libff::G1<ppT>,
                                                       libff::Fr<ppT> >(
        libff::Fr<ppT>::size_in_bits(),
        G_window,
        G_table,
        tmp_exponents);
    tmp_exponents.clear();
#ifdef USE_MIXED_ADDITION
    libff::batch_to_special<libff::G1<ppT> >(C_query_1);
#endif
    libff::leave_block("Compute the C_1-query", false);

    libff::enter_block("Compute the C_2-query", false);
    tmp_exponents.reserve(sap_inst.num_variables() + 1);
    libff::Fr<ppT> double_gamma2_Z = gamma * gamma * sap_inst.Zt;
    double_gamma2_Z = double_gamma2_Z + double_gamma2_Z;
    for (size_t i = 0; i <= sap_inst.num_variables(); ++i)
    {
        tmp_exponents.emplace_back(double_gamma2_Z * At[i]);
    }
    libff::G1_vector<ppT> C_query_2 = libff::batch_exp<libff::G1<ppT>,
                                                       libff::Fr<ppT> >(
        libff::Fr<ppT>::size_in_bits(),
        G_window,
        G_table,
        tmp_exponents);
    tmp_exponents.clear();
#ifdef USE_MIXED_ADDITION
    libff::batch_to_special<libff::G1<ppT> >(C_query_2);
#endif
    libff::leave_block("Compute the C_2-query", false);

    libff::leave_block("Generate R1CS proving key");

    libff::leave_block("Call to r1cs_se_ppzksnark_generator");

    r1cs_se_ppzksnark_verification_key<ppT> vk =
        r1cs_se_ppzksnark_verification_key<ppT>(H, G_alpha, H_beta, G_gamma,
            H_gamma, std::move(verifier_query));

    r1cs_se_ppzksnark_constraint_system<ppT> cs_copy(cs);

    r1cs_se_ppzksnark_proving_key<ppT> pk = r1cs_se_ppzksnark_proving_key<ppT>(
        std::move(A_query), std::move(B_query), std::move(C_query_1),
        std::move(C_query_2), G_gamma_Z, H_gamma_Z, G_ab_gamma_Z, G_gamma2_Z2,
        std::move(G_gamma2_Z_t), std::move(cs_copy));

    pk.print_size();
    vk.print_size();

    return r1cs_se_ppzksnark_keypair<ppT>(std::move(pk), std::move(vk));
}

template <typename ppT>
r1cs_se_ppzksnark_proof<ppT> r1cs_se_ppzksnark_prover(const r1cs_se_ppzksnark_proving_key<ppT> &pk,
                                                const r1cs_se_ppzksnark_primary_input<ppT> &primary_input,
                                                const r1cs_se_ppzksnark_auxiliary_input<ppT> &auxiliary_input)
{
    libff::enter_block("Call to r1cs_se_ppzksnark_prover");

#ifdef DEBUG
    assert(pk.constraint_system.is_satisfied(primary_input, auxiliary_input));
#endif

    const libff::Fr<ppT> d1 = libff::Fr<ppT>::random_element(),
        d2 = libff::Fr<ppT>::random_element();

    libff::enter_block("Compute the polynomial H");
    const sap_witness<libff::Fr<ppT> > sap_wit = r1cs_to_sap_witness_map(
        pk.constraint_system, primary_input, auxiliary_input, d1, d2);
    libff::leave_block("Compute the polynomial H");

#ifdef DEBUG
    const libff::Fr<ppT> t = libff::Fr<ppT>::random_element();
    sap_instance_evaluation<libff::Fr<ppT> > sap_inst = r1cs_to_sap_instance_map_with_evaluation(pk.constraint_system, t);
    assert(sap_inst.is_satisfied(sap_wit));
#endif

#ifdef DEBUG
    assert(pk.A_query.size() == sap_wit.num_variables() + 1);
    assert(pk.B_query.size() == sap_wit.num_variables() + 1);
    assert(pk.C_query_1.size() == sap_wit.num_variables() - sap_wit.num_inputs());
    assert(pk.C_query_2.size() == sap_wit.num_variables() + 1);
    assert(pk.G_gamma2_Z_t.size() >= sap_wit.degree() - 1);
#endif

#ifdef MULTICORE
    const size_t chunks = omp_get_max_threads(); // to override, set OMP_NUM_THREADS env var or call omp_set_num_threads()
#else
    const size_t chunks = 1;
#endif

    const libff::Fr<ppT> r = libff::Fr<ppT>::random_element();

    libff::enter_block("Compute the proof");

    libff::enter_block("Compute answer to A-query", false);
    /**
     * compute A = G^{gamma * (\sum_{i=0}^m input_i * A_i(t) + r * Z(t))}
     *           = \prod_{i=0}^m (G^{gamma * A_i(t)})^{input_i)
     *             * (G^{gamma * Z(t)})^r
     *           = \prod_{i=0}^m A_query[i]^{input_i} * G_gamma_Z^r
     */
    libff::G1<ppT> A = r * pk.G_gamma_Z +
        pk.A_query[0] + // i = 0 is a special case because input_i = 1
        sap_wit.d1 * pk.G_gamma_Z + // ZK-patch
        libff::multi_exp<libff::G1<ppT>,
                         libff::Fr<ppT>,
                         libff::multi_exp_method_BDLO12>(
            pk.A_query.begin() + 1,
            pk.A_query.end(),
            sap_wit.coefficients_for_ACs.begin(),
            sap_wit.coefficients_for_ACs.end(),
            chunks);

    libff::leave_block("Compute answer to A-query", false);

    libff::enter_block("Compute answer to B-query", false);
    /**
     * compute B exactly as A, except with H as the base
     */
    libff::G2<ppT> B = r * pk.H_gamma_Z +
        pk.B_query[0] + // i = 0 is a special case because input_i = 1
        sap_wit.d1 * pk.H_gamma_Z + // ZK-patch
        libff::multi_exp<libff::G2<ppT>,
                         libff::Fr<ppT>,
                         libff::multi_exp_method_BDLO12>(
            pk.B_query.begin() + 1,
            pk.B_query.end(),
            sap_wit.coefficients_for_ACs.begin(),
            sap_wit.coefficients_for_ACs.end(),
            chunks);
    libff::leave_block("Compute answer to B-query", false);

    libff::enter_block("Compute answer to C-query", false);
    /**
     * compute C = G^{f(input) +
     *                r^2 * gamma^2 * Z(t)^2 +
     *                r * (alpha + beta) * gamma * Z(t) +
     *                2 * r * gamma^2 * Z(t) * \sum_{i=0}^m input_i A_i(t) +
     *                gamma^2 * Z(t) * H(t)}
     * where G^{f(input)} = \prod_{i=l+1}^m C_query_1 * input_i
     * and G^{2 * r * gamma^2 * Z(t) * \sum_{i=0}^m input_i A_i(t)} =
     *              = \prod_{i=0}^m C_query_2 * input_i
     */
    libff::G1<ppT> C = libff::multi_exp<libff::G1<ppT>,
                                        libff::Fr<ppT>,
                                        libff::multi_exp_method_BDLO12>(
            pk.C_query_1.begin(),
            pk.C_query_1.end(),
            sap_wit.coefficients_for_ACs.begin() + sap_wit.num_inputs(),
            sap_wit.coefficients_for_ACs.end(),
            chunks) +
        (r * r) * pk.G_gamma2_Z2 +
        r * pk.G_ab_gamma_Z +
        sap_wit.d1 * pk.G_ab_gamma_Z + // ZK-patch
        r * pk.C_query_2[0] + // i = 0 is a special case for C_query_2
        (r + r) * sap_wit.d1 * pk.G_gamma2_Z2 + // ZK-patch for C_query_2
        r * libff::multi_exp<libff::G1<ppT>,
                             libff::Fr<ppT>,
                             libff::multi_exp_method_BDLO12>(
            pk.C_query_2.begin() + 1,
            pk.C_query_2.end(),
            sap_wit.coefficients_for_ACs.begin(),
            sap_wit.coefficients_for_ACs.end(),
            chunks) +
        sap_wit.d2 * pk.G_gamma2_Z_t[0] + // ZK-patch
        libff::multi_exp<libff::G1<ppT>,
                          libff::Fr<ppT>,
                          libff::multi_exp_method_BDLO12>(
            pk.G_gamma2_Z_t.begin(),
            pk.G_gamma2_Z_t.end(),
            sap_wit.coefficients_for_H.begin(),
            sap_wit.coefficients_for_H.end(),
            chunks);
    libff::leave_block("Compute answer to C-query", false);

    libff::leave_block("Compute the proof");

    libff::leave_block("Call to r1cs_se_ppzksnark_prover");

    r1cs_se_ppzksnark_proof<ppT> proof = r1cs_se_ppzksnark_proof<ppT>(
        std::move(A), std::move(B), std::move(C));
    proof.print_size();

    return proof;
}

template <typename ppT>
r1cs_se_ppzksnark_processed_verification_key<ppT> r1cs_se_ppzksnark_verifier_process_vk(const r1cs_se_ppzksnark_verification_key<ppT> &vk)
{
    libff::enter_block("Call to r1cs_se_ppzksnark_verifier_process_vk");

    libff::G1_precomp<ppT> G_alpha_pc = ppT::precompute_G1(vk.G_alpha);
    libff::G2_precomp<ppT> H_beta_pc = ppT::precompute_G2(vk.H_beta);

    r1cs_se_ppzksnark_processed_verification_key<ppT> pvk;
    pvk.G_alpha = vk.G_alpha;
    pvk.H_beta = vk.H_beta;
    pvk.G_alpha_H_beta = ppT::final_exponentiation(ppT::miller_loop(G_alpha_pc, H_beta_pc));
    pvk.G_gamma_pc = ppT::precompute_G1(vk.G_gamma);
    pvk.H_gamma_pc = ppT::precompute_G2(vk.H_gamma);
    pvk.H_pc = ppT::precompute_G2(vk.H);

    pvk.query = vk.query;

    libff::leave_block("Call to r1cs_se_ppzksnark_verifier_process_vk");

    return pvk;
}

template <typename ppT>
bool r1cs_se_ppzksnark_online_verifier_weak_IC(const r1cs_se_ppzksnark_processed_verification_key<ppT> &pvk,
                                               const r1cs_se_ppzksnark_primary_input<ppT> &primary_input,
                                               const r1cs_se_ppzksnark_proof<ppT> &proof)
{
    libff::enter_block("Call to r1cs_se_ppzksnark_online_verifier_weak_IC");

    bool result = true;

    libff::enter_block("Check if the proof is well-formed");
    if (!proof.is_well_formed())
    {
        if (!libff::inhibit_profiling_info)
        {
            libff::print_indent(); printf("At least one of the proof elements does not lie on the curve.\n");
        }
        result = false;
    }
    libff::leave_block("Check if the proof is well-formed");

    libff::enter_block("Pairing computations");

#ifdef MULTICORE
    const size_t chunks = omp_get_max_threads(); // to override, set OMP_NUM_THREADS env var or call omp_set_num_threads()
#else
    const size_t chunks = 1;
#endif

    libff::enter_block("Check first test");
    /**
     * e(A*G^{alpha}, B*H^{beta}) = e(G^{alpha}, H^{beta}) * e(G^{psi}, H^{gamma})
     *                              * e(C, H)
     * where psi = \sum_{i=0}^l input_i pvk.query[i]
     */
    libff::G1<ppT> G_psi = pvk.query[0] +
        libff::multi_exp<libff::G1<ppT>,
                         libff::Fr<ppT>,
                         libff::multi_exp_method_bos_coster>(
            pvk.query.begin() + 1, pvk.query.end(),
            primary_input.begin(), primary_input.end(),
            chunks);

    libff::Fqk<ppT> test1_l = ppT::miller_loop(ppT::precompute_G1(proof.A + pvk.G_alpha),
                                               ppT::precompute_G2(proof.B + pvk.H_beta)),
                    test1_r1 = pvk.G_alpha_H_beta,
                    test1_r2 = ppT::miller_loop(ppT::precompute_G1(G_psi),
                                                pvk.H_gamma_pc),
                    test1_r3 = ppT::miller_loop(ppT::precompute_G1(proof.C),
                                                pvk.H_pc);
    libff::GT<ppT> test1 = ppT::final_exponentiation(
        test1_l.unitary_inverse() * test1_r2 * test1_r3) * test1_r1;

    if (test1 != libff::GT<ppT>::one())
    {
        if (!libff::inhibit_profiling_info)
        {
            libff::print_indent(); printf("First test failed.\n");
        }
        result = false;
    }
    libff::leave_block("Check first test");

    libff::enter_block("Check second test");
    /**
     * e(A, H^{gamma}) = e(G^{gamma}, B)
     */
    libff::Fqk<ppT> test2_l = ppT::miller_loop(ppT::precompute_G1(proof.A),
                                               pvk.H_gamma_pc),
                    test2_r = ppT::miller_loop(pvk.G_gamma_pc,
                                               ppT::precompute_G2(proof.B));
    libff::GT<ppT> test2 = ppT::final_exponentiation(
        test2_l * test2_r.unitary_inverse());

    if (test2 != libff::GT<ppT>::one())
    {
        if (!libff::inhibit_profiling_info)
        {
            libff::print_indent(); printf("Second test failed.\n");
        }
        result = false;
    }
    libff::leave_block("Check second test");
    libff::leave_block("Pairing computations");
    libff::leave_block("Call to r1cs_se_ppzksnark_online_verifier_weak_IC");

    return result;
}

template<typename ppT>
bool r1cs_se_ppzksnark_verifier_weak_IC(const r1cs_se_ppzksnark_verification_key<ppT> &vk,
                                        const r1cs_se_ppzksnark_primary_input<ppT> &primary_input,
                                        const r1cs_se_ppzksnark_proof<ppT> &proof)
{
    libff::enter_block("Call to r1cs_se_ppzksnark_verifier_weak_IC");
    r1cs_se_ppzksnark_processed_verification_key<ppT> pvk = r1cs_se_ppzksnark_verifier_process_vk<ppT>(vk);
    bool result = r1cs_se_ppzksnark_online_verifier_weak_IC<ppT>(pvk, primary_input, proof);
    libff::leave_block("Call to r1cs_se_ppzksnark_verifier_weak_IC");
    return result;
}

template<typename ppT>
bool r1cs_se_ppzksnark_online_verifier_strong_IC(const r1cs_se_ppzksnark_processed_verification_key<ppT> &pvk,
                                                 const r1cs_se_ppzksnark_primary_input<ppT> &primary_input,
                                                 const r1cs_se_ppzksnark_proof<ppT> &proof)
{
    libff::enter_block("Call to r1cs_se_ppzksnark_online_verifier_strong_IC");
    bool result = true;

    if (pvk.query.size() != primary_input.size() + 1)
    {
        libff::print_indent();
        printf("Input length differs from expected (got %zu, expected %zu).\n",
            primary_input.size(), pvk.query.size());
        result = false;
    }
    else
    {
        result = r1cs_se_ppzksnark_online_verifier_weak_IC(pvk, primary_input, proof);
    }

    libff::leave_block("Call to r1cs_se_ppzksnark_online_verifier_strong_IC");
    return result;
}

template<typename ppT>
bool r1cs_se_ppzksnark_verifier_strong_IC(const r1cs_se_ppzksnark_verification_key<ppT> &vk,
                                          const r1cs_se_ppzksnark_primary_input<ppT> &primary_input,
                                          const r1cs_se_ppzksnark_proof<ppT> &proof)
{
    libff::enter_block("Call to r1cs_se_ppzksnark_verifier_strong_IC");
    r1cs_se_ppzksnark_processed_verification_key<ppT> pvk = r1cs_se_ppzksnark_verifier_process_vk<ppT>(vk);
    bool result = r1cs_se_ppzksnark_online_verifier_strong_IC<ppT>(pvk, primary_input, proof);
    libff::leave_block("Call to r1cs_se_ppzksnark_verifier_strong_IC");
    return result;
}

} // libsnark
#endif // R1CS_SE_PPZKSNARK_TCC_
