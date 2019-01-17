/** @file
 *****************************************************************************

 Declaration of interfaces for a SEppzkSNARK for R1CS.

 This includes:
 - class for proving key
 - class for verification key
 - class for processed verification key
 - class for key pair (proving key & verification key)
 - class for proof
 - generator algorithm
 - prover algorithm
 - verifier algorithm (with strong or weak input consistency)
 - online verifier algorithm (with strong or weak input consistency)

 The implementation instantiates (a modification of) the protocol of \[GM17],
 by following extending, and optimizing the approach described in \[BCTV14].


 Acronyms:

 - R1CS = "Rank-1 Constraint Systems"
 - SEppzkSNARK = "Simulation-Extractable PreProcessing Zero-Knowledge Succinct
     Non-interactive ARgument of Knowledge"

 References:

 \[BCTV14]:
 "Succinct Non-Interactive Zero Knowledge for a von Neumann Architecture",
 Eli Ben-Sasson, Alessandro Chiesa, Eran Tromer, Madars Virza,
 USENIX Security 2014,
 <http://eprint.iacr.org/2013/879>

 \[GM17]:
 "Snarky Signatures: Minimal Signatures of Knowledge from
  Simulation-Extractable SNARKs",
 Jens Groth and Mary Maller,
 IACR-CRYPTO-2017,
 <https://eprint.iacr.org/2017/540>

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef R1CS_SE_PPZKSNARK_HPP_
#define R1CS_SE_PPZKSNARK_HPP_

#include <memory>

#include <libff/algebra/curves/public_params.hpp>

#include <libsnark/common/data_structures/accumulation_vector.hpp>
#include <libsnark/knowledge_commitment/knowledge_commitment.hpp>
#include <libsnark/relations/constraint_satisfaction_problems/r1cs/r1cs.hpp>
#include <libsnark/zk_proof_systems/ppzksnark/r1cs_se_ppzksnark/r1cs_se_ppzksnark_params.hpp>

namespace libsnark {

/******************************** Proving key ********************************/

template<typename ppT>
class r1cs_se_ppzksnark_proving_key;

template<typename ppT>
std::ostream& operator<<(std::ostream &out, const r1cs_se_ppzksnark_proving_key<ppT> &pk);

template<typename ppT>
std::istream& operator>>(std::istream &in, r1cs_se_ppzksnark_proving_key<ppT> &pk);

/**
 * A proving key for the R1CS SEppzkSNARK.
 */
template<typename ppT>
class r1cs_se_ppzksnark_proving_key {
public:
    // G^{gamma * A_i(t)} for 0 <= i <= sap.num_variables()
    libff::G1_vector<ppT> A_query;

    // H^{gamma * A_i(t)} for 0 <= i <= sap.num_variables()
    libff::G2_vector<ppT> B_query;

    // G^{gamma^2 * C_i(t) + (alpha + beta) * gamma * A_i(t)}
    // for sap.num_inputs() + 1 < i <= sap.num_variables()
    libff::G1_vector<ppT> C_query_1;

    // G^{2 * gamma^2 * Z(t) * A_i(t)} for 0 <= i <= sap.num_variables()
    libff::G1_vector<ppT> C_query_2;

    // G^{gamma * Z(t)}
    libff::G1<ppT> G_gamma_Z;

    // H^{gamma * Z(t)}
    libff::G2<ppT> H_gamma_Z;

    // G^{(alpha + beta) * gamma * Z(t)}
    libff::G1<ppT> G_ab_gamma_Z;

    // G^{gamma^2 * Z(t)^2}
    libff::G1<ppT> G_gamma2_Z2;

    // G^{gamma^2 * Z(t) * t^i} for 0 <= i < sap.degree
    libff::G1_vector<ppT> G_gamma2_Z_t;

    r1cs_se_ppzksnark_constraint_system<ppT> constraint_system;

    r1cs_se_ppzksnark_proving_key() {};
    r1cs_se_ppzksnark_proving_key<ppT>& operator=(const r1cs_se_ppzksnark_proving_key<ppT> &other) = default;
    r1cs_se_ppzksnark_proving_key(const r1cs_se_ppzksnark_proving_key<ppT> &other) = default;
    r1cs_se_ppzksnark_proving_key(r1cs_se_ppzksnark_proving_key<ppT> &&other) = default;
    r1cs_se_ppzksnark_proving_key(libff::G1_vector<ppT> &&A_query,
        libff::G2_vector<ppT> &&B_query,
        libff::G1_vector<ppT> &&C_query_1,
        libff::G1_vector<ppT> &&C_query_2,
        libff::G1<ppT> &G_gamma_Z,
        libff::G2<ppT> &H_gamma_Z,
        libff::G1<ppT> &G_ab_gamma_Z,
        libff::G1<ppT> &G_gamma2_Z2,
        libff::G1_vector<ppT> &&G_gamma2_Z_t,
        r1cs_se_ppzksnark_constraint_system<ppT> &&constraint_system) :
        A_query(std::move(A_query)),
        B_query(std::move(B_query)),
        C_query_1(std::move(C_query_1)),
        C_query_2(std::move(C_query_2)),
        G_gamma_Z(G_gamma_Z),
        H_gamma_Z(H_gamma_Z),
        G_ab_gamma_Z(G_ab_gamma_Z),
        G_gamma2_Z2(G_gamma2_Z2),
        G_gamma2_Z_t(std::move(G_gamma2_Z_t)),
        constraint_system(std::move(constraint_system))
    {};

    size_t G1_size() const
    {
        return A_query.size() + C_query_1.size() + C_query_2.size() + 3
               + G_gamma2_Z_t.size();
    }

    size_t G2_size() const
    {
        return B_query.size() + 1;
    }

    size_t size_in_bits() const
    {
        return G1_size() * libff::G1<ppT>::size_in_bits() +
               G2_size() * libff::G2<ppT>::size_in_bits();
    }

    void print_size() const
    {
        libff::print_indent(); printf("* G1 elements in PK: %zu\n", this->G1_size());
        libff::print_indent(); printf("* G2 elements in PK: %zu\n", this->G2_size());
        libff::print_indent(); printf("* PK size in bits: %zu\n", this->size_in_bits());
    }

    bool operator==(const r1cs_se_ppzksnark_proving_key<ppT> &other) const;
    friend std::ostream& operator<< <ppT>(std::ostream &out, const r1cs_se_ppzksnark_proving_key<ppT> &pk);
    friend std::istream& operator>> <ppT>(std::istream &in, r1cs_se_ppzksnark_proving_key<ppT> &pk);
};


/******************************* Verification key ****************************/

template<typename ppT>
class r1cs_se_ppzksnark_verification_key;

template<typename ppT>
std::ostream& operator<<(std::ostream &out, const r1cs_se_ppzksnark_verification_key<ppT> &vk);

template<typename ppT>
std::istream& operator>>(std::istream &in, r1cs_se_ppzksnark_verification_key<ppT> &vk);

/**
 * A verification key for the R1CS SEppzkSNARK.
 */
template<typename ppT>
class r1cs_se_ppzksnark_verification_key {
public:
    // H
    libff::G2<ppT> H;

    // G^{alpha}
    libff::G1<ppT> G_alpha;

    // H^{beta}
    libff::G2<ppT> H_beta;

    // G^{gamma}
    libff::G1<ppT> G_gamma;

    // H^{gamma}
    libff::G2<ppT> H_gamma;

    // e (G^{alpha}, H^{beta})
    libff::Fqk<ppT> G_alpha_H_beta;

    // G^{gamma * A_i(t) + (alpha + beta) * A_i(t)}
    // for 0 <= i <= sap.num_inputs()
    libff::G1_vector<ppT> query;

    r1cs_se_ppzksnark_verification_key() = default;
    r1cs_se_ppzksnark_verification_key(const libff::G2<ppT> &H,
        const libff::G1<ppT> &G_alpha,
        const libff::G2<ppT> &H_beta,
        const libff::G1<ppT> &G_gamma,
        const libff::G2<ppT> &H_gamma,
        libff::G1_vector<ppT> &&query) :
        H(H),
        G_alpha(G_alpha),
        H_beta(H_beta),
        G_gamma(G_gamma),
        H_gamma(H_gamma),
        query(std::move(query)),
        G_alpha_H_beta(ppT::reduced_pairing(G_alpha, H_beta))
    {};

    size_t G1_size() const
    {
        return 2 + query.size();
    }

    size_t G2_size() const
    {
        return 3;
    }

    // TODO: The GT size also
    size_t size_in_bits() const
    {
        return (G1_size() * libff::G1<ppT>::size_in_bits() +
                G2_size() * libff::G2<ppT>::size_in_bits());
    }

    void print_size() const
    {
        libff::print_indent(); printf("* G1 elements in VK: %zu\n",
            this->G1_size());
        libff::print_indent(); printf("* G2 elements in VK: %zu\n",
            this->G2_size());
        libff::print_indent(); printf("* VK size in bits: %zu\n",
            this->size_in_bits());
    }

    bool operator==(const r1cs_se_ppzksnark_verification_key<ppT> &other) const;
    friend std::ostream& operator<< <ppT>(std::ostream &out, const r1cs_se_ppzksnark_verification_key<ppT> &vk);
    friend std::istream& operator>> <ppT>(std::istream &in, r1cs_se_ppzksnark_verification_key<ppT> &vk);

    static r1cs_se_ppzksnark_verification_key<ppT> dummy_verification_key(const size_t input_size);
};

/************************ Processed verification key *************************/

template<typename ppT>
class r1cs_se_ppzksnark_processed_verification_key;

template<typename ppT>
std::ostream& operator<<(std::ostream &out, const r1cs_se_ppzksnark_processed_verification_key<ppT> &pvk);

template<typename ppT>
std::istream& operator>>(std::istream &in, r1cs_se_ppzksnark_processed_verification_key<ppT> &pvk);

/**
 * A processed verification key for the R1CS SEppzkSNARK.
 *
 * Compared to a (non-processed) verification key, a processed verification key
 * contains a small constant amount of additional pre-computed information that
 * enables a faster verification time.
 */
template<typename ppT>
class r1cs_se_ppzksnark_processed_verification_key {
public:
    libff::G1<ppT> G_alpha;
    libff::G2<ppT> H_beta;
    libff::Fqk<ppT> G_alpha_H_beta;
    libff::G1_precomp<ppT> G_gamma_pc;
    libff::G2_precomp<ppT> H_gamma_pc;
    libff::G2_precomp<ppT> H_pc;

    libff::G1_vector<ppT> query;

    bool operator==(const r1cs_se_ppzksnark_processed_verification_key &other) const;
    friend std::ostream& operator<< <ppT>(std::ostream &out, const r1cs_se_ppzksnark_processed_verification_key<ppT> &pvk);
    friend std::istream& operator>> <ppT>(std::istream &in, r1cs_se_ppzksnark_processed_verification_key<ppT> &pvk);
};

/********************************** Key pair *********************************/

/**
 * A key pair for the R1CS SEppzkSNARK, which consists of a proving key and a verification key.
 */
template<typename ppT>
class r1cs_se_ppzksnark_keypair {
public:
    r1cs_se_ppzksnark_proving_key<ppT> pk;
    r1cs_se_ppzksnark_verification_key<ppT> vk;

    r1cs_se_ppzksnark_keypair() = default;
    r1cs_se_ppzksnark_keypair(const r1cs_se_ppzksnark_keypair<ppT> &other) = default;
    r1cs_se_ppzksnark_keypair(r1cs_se_ppzksnark_proving_key<ppT> &&pk,
                              r1cs_se_ppzksnark_verification_key<ppT> &&vk) :
        pk(std::move(pk)),
        vk(std::move(vk))
    {}

    r1cs_se_ppzksnark_keypair(r1cs_se_ppzksnark_keypair<ppT> &&other) = default;
};


/*********************************** Proof ***********************************/

template<typename ppT>
class r1cs_se_ppzksnark_proof;

template<typename ppT>
std::ostream& operator<<(std::ostream &out, const r1cs_se_ppzksnark_proof<ppT> &proof);

template<typename ppT>
std::istream& operator>>(std::istream &in, r1cs_se_ppzksnark_proof<ppT> &proof);

/**
 * A proof for the R1CS SEppzkSNARK.
 *
 * While the proof has a structure, externally one merely opaquely produces,
 * seralizes/deserializes, and verifies proofs. We only expose some information
 * about the structure for statistics purposes.
 */
template<typename ppT>
class r1cs_se_ppzksnark_proof {
public:
    libff::G1<ppT> A;
    libff::G2<ppT> B;
    libff::G1<ppT> C;

    r1cs_se_ppzksnark_proof()
    {}
    r1cs_se_ppzksnark_proof(libff::G1<ppT> &&A,
        libff::G2<ppT> &&B,
        libff::G1<ppT> &&C) :
        A(std::move(A)),
        B(std::move(B)),
        C(std::move(C))
    {};

    size_t G1_size() const
    {
        return 2;
    }

    size_t G2_size() const
    {
        return 1;
    }

    size_t size_in_bits() const
    {
        return G1_size() * libff::G1<ppT>::size_in_bits() +
               G2_size() * libff::G2<ppT>::size_in_bits();
    }

    void print_size() const
    {
        libff::print_indent(); printf("* G1 elements in proof: %zu\n",
            this->G1_size());
        libff::print_indent(); printf("* G2 elements in proof: %zu\n",
            this->G2_size());
        libff::print_indent(); printf("* Proof size in bits: %zu\n",
            this->size_in_bits());
    }

    bool is_well_formed() const
    {
        return (A.is_well_formed() && B.is_well_formed() &&
                C.is_well_formed());
    }

    bool operator==(const r1cs_se_ppzksnark_proof<ppT> &other) const;
    friend std::ostream& operator<< <ppT>(std::ostream &out, const r1cs_se_ppzksnark_proof<ppT> &proof);
    friend std::istream& operator>> <ppT>(std::istream &in, r1cs_se_ppzksnark_proof<ppT> &proof);
};


/***************************** Main algorithms *******************************/

/**
 * A generator algorithm for the R1CS SEppzkSNARK.
 *
 * Given a R1CS constraint system CS, this algorithm produces proving and verification keys for CS.
 */
template<typename ppT>
r1cs_se_ppzksnark_keypair<ppT> r1cs_se_ppzksnark_generator(const r1cs_se_ppzksnark_constraint_system<ppT> &cs);

/**
 * A prover algorithm for the R1CS SEppzkSNARK.
 *
 * Given a R1CS primary input X and a R1CS auxiliary input Y, this algorithm
 * produces a proof (of knowledge) that attests to the following statement:
 *               ``there exists Y such that CS(X,Y)=0''.
 * Above, CS is the R1CS constraint system that was given as input to the generator algorithm.
 */
template<typename ppT>
r1cs_se_ppzksnark_proof<ppT> r1cs_se_ppzksnark_prover(const r1cs_se_ppzksnark_proving_key<ppT> &pk,
                                                      const r1cs_se_ppzksnark_primary_input<ppT> &primary_input,
                                                      const r1cs_se_ppzksnark_auxiliary_input<ppT> &auxiliary_input);

/*
 Below are four variants of verifier algorithm for the R1CS SEppzkSNARK.

 These are the four cases that arise from the following two choices:

 (1) The verifier accepts a (non-processed) verification key or, instead, a processed verification key.
     In the latter case, we call the algorithm an "online verifier".

 (2) The verifier checks for "weak" input consistency or, instead, "strong" input consistency.
     Strong input consistency requires that |primary_input| = CS.num_inputs, whereas
     weak input consistency requires that |primary_input| <= CS.num_inputs (and
     the primary input is implicitly padded with zeros up to length CS.num_inputs).
 */

/**
 * A verifier algorithm for the R1CS SEppzkSNARK that:
 * (1) accepts a non-processed verification key, and
 * (2) has weak input consistency.
 */
template<typename ppT>
bool r1cs_se_ppzksnark_verifier_weak_IC(const r1cs_se_ppzksnark_verification_key<ppT> &vk,
                                        const r1cs_se_ppzksnark_primary_input<ppT> &primary_input,
                                        const r1cs_se_ppzksnark_proof<ppT> &proof);

/**
 * A verifier algorithm for the R1CS SEppzkSNARK that:
 * (1) accepts a non-processed verification key, and
 * (2) has strong input consistency.
 */
template<typename ppT>
bool r1cs_se_ppzksnark_verifier_strong_IC(const r1cs_se_ppzksnark_verification_key<ppT> &vk,
                                          const r1cs_se_ppzksnark_primary_input<ppT> &primary_input,
                                          const r1cs_se_ppzksnark_proof<ppT> &proof);

/**
 * Convert a (non-processed) verification key into a processed verification key.
 */
template<typename ppT>
r1cs_se_ppzksnark_processed_verification_key<ppT> r1cs_se_ppzksnark_verifier_process_vk(const r1cs_se_ppzksnark_verification_key<ppT> &vk);

/**
 * A verifier algorithm for the R1CS ppzkSNARK that:
 * (1) accepts a processed verification key, and
 * (2) has weak input consistency.
 */
template<typename ppT>
bool r1cs_se_ppzksnark_online_verifier_weak_IC(const r1cs_se_ppzksnark_processed_verification_key<ppT> &pvk,
                                               const r1cs_se_ppzksnark_primary_input<ppT> &input,
                                               const r1cs_se_ppzksnark_proof<ppT> &proof);

/**
 * A verifier algorithm for the R1CS ppzkSNARK that:
 * (1) accepts a processed verification key, and
 * (2) has strong input consistency.
 */
template<typename ppT>
bool r1cs_se_ppzksnark_online_verifier_strong_IC(const r1cs_se_ppzksnark_processed_verification_key<ppT> &pvk,
                                                 const r1cs_se_ppzksnark_primary_input<ppT> &primary_input,
                                                 const r1cs_se_ppzksnark_proof<ppT> &proof);

} // libsnark

#include <libsnark/zk_proof_systems/ppzksnark/r1cs_se_ppzksnark/r1cs_se_ppzksnark.tcc>

#endif // R1CS_SE_PPZKSNARK_HPP_
