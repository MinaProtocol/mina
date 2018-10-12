/** @file
 *****************************************************************************

 Declaration of interfaces for a SAP ("Square Arithmetic Program").

 SAPs are defined in \[GM17].

 References:

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

#ifndef SAP_HPP_
#define SAP_HPP_

#include <map>
#include <memory>

#include <libfqfft/evaluation_domain/evaluation_domain.hpp>

namespace libsnark {

/* forward declaration */
template<typename FieldT>
class sap_witness;

/**
 * A SAP instance.
 *
 * Specifically, the datastructure stores:
 * - a choice of domain (corresponding to a certain subset of the field);
 * - the number of variables, the degree, and the number of inputs; and
 * - coefficients of the A,C polynomials in the Lagrange basis.
 *
 * There is no need to store the Z polynomial because it is uniquely
 * determined by the domain (as Z is its vanishing polynomial).
 */
template<typename FieldT>
class sap_instance {
private:
    size_t num_variables_;
    size_t degree_;
    size_t num_inputs_;

public:
    std::shared_ptr<libfqfft::evaluation_domain<FieldT> > domain;

    std::vector<std::map<size_t, FieldT> > A_in_Lagrange_basis;
    std::vector<std::map<size_t, FieldT> > C_in_Lagrange_basis;

    sap_instance(const std::shared_ptr<libfqfft::evaluation_domain<FieldT> > &domain,
                 const size_t num_variables,
                 const size_t degree,
                 const size_t num_inputs,
                 const std::vector<std::map<size_t, FieldT> > &A_in_Lagrange_basis,
                 const std::vector<std::map<size_t, FieldT> > &C_in_Lagrange_basis);

    sap_instance(const std::shared_ptr<libfqfft::evaluation_domain<FieldT> > &domain,
                 const size_t num_variables,
                 const size_t degree,
                 const size_t num_inputs,
                 std::vector<std::map<size_t, FieldT> > &&A_in_Lagrange_basis,
                 std::vector<std::map<size_t, FieldT> > &&C_in_Lagrange_basis);

    sap_instance(const sap_instance<FieldT> &other) = default;
    sap_instance(sap_instance<FieldT> &&other) = default;
    sap_instance& operator=(const sap_instance<FieldT> &other) = default;
    sap_instance& operator=(sap_instance<FieldT> &&other) = default;

    size_t num_variables() const;
    size_t degree() const;
    size_t num_inputs() const;

    bool is_satisfied(const sap_witness<FieldT> &witness) const;
};

/**
 * A SAP instance evaluation is a SAP instance that is evaluated at a field element t.
 *
 * Specifically, the datastructure stores:
 * - a choice of domain (corresponding to a certain subset of the field);
 * - the number of variables, the degree, and the number of inputs;
 * - a field element t;
 * - evaluations of the A,C (and Z) polynomials at t;
 * - evaluations of all monomials of t;
 * - counts about how many of the above evaluations are in fact non-zero.
 */
template<typename FieldT>
class sap_instance_evaluation {
private:
    size_t num_variables_;
    size_t degree_;
    size_t num_inputs_;
public:
    std::shared_ptr<libfqfft::evaluation_domain<FieldT> > domain;

    FieldT t;

    std::vector<FieldT> At, Ct, Ht;

    FieldT Zt;

    sap_instance_evaluation(const std::shared_ptr<libfqfft::evaluation_domain<FieldT> > &domain,
                            const size_t num_variables,
                            const size_t degree,
                            const size_t num_inputs,
                            const FieldT &t,
                            const std::vector<FieldT> &At,
                            const std::vector<FieldT> &Ct,
                            const std::vector<FieldT> &Ht,
                            const FieldT &Zt);
    sap_instance_evaluation(const std::shared_ptr<libfqfft::evaluation_domain<FieldT> > &domain,
                            const size_t num_variables,
                            const size_t degree,
                            const size_t num_inputs,
                            const FieldT &t,
                            std::vector<FieldT> &&At,
                            std::vector<FieldT> &&Ct,
                            std::vector<FieldT> &&Ht,
                            const FieldT &Zt);

    sap_instance_evaluation(const sap_instance_evaluation<FieldT> &other) = default;
    sap_instance_evaluation(sap_instance_evaluation<FieldT> &&other) = default;
    sap_instance_evaluation& operator=(const sap_instance_evaluation<FieldT> &other) = default;
    sap_instance_evaluation& operator=(sap_instance_evaluation<FieldT> &&other) = default;

    size_t num_variables() const;
    size_t degree() const;
    size_t num_inputs() const;

    bool is_satisfied(const sap_witness<FieldT> &witness) const;
};

/**
 * A SAP witness.
 */
template<typename FieldT>
class sap_witness {
private:
    size_t num_variables_;
    size_t degree_;
    size_t num_inputs_;

public:
    FieldT d1, d2;

    std::vector<FieldT> coefficients_for_ACs;
    std::vector<FieldT> coefficients_for_H;

    sap_witness(const size_t num_variables,
                const size_t degree,
                const size_t num_inputs,
                const FieldT &d1,
                const FieldT &d2,
                const std::vector<FieldT> &coefficients_for_ACs,
                const std::vector<FieldT> &coefficients_for_H);

    sap_witness(const size_t num_variables,
                const size_t degree,
                const size_t num_inputs,
                const FieldT &d1,
                const FieldT &d2,
                const std::vector<FieldT> &coefficients_for_ACs,
                std::vector<FieldT> &&coefficients_for_H);

    sap_witness(const sap_witness<FieldT> &other) = default;
    sap_witness(sap_witness<FieldT> &&other) = default;
    sap_witness& operator=(const sap_witness<FieldT> &other) = default;
    sap_witness& operator=(sap_witness<FieldT> &&other) = default;

    size_t num_variables() const;
    size_t degree() const;
    size_t num_inputs() const;
};

} // libsnark

#include <libsnark/relations/arithmetic_programs/sap/sap.tcc>

#endif // SAP_HPP_
