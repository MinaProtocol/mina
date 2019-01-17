/** @file
 *****************************************************************************

 Declaration of interfaces for a R1CS-to-SAP reduction, that is, constructing
 a SAP ("Square Arithmetic Program") from a R1CS ("Rank-1 Constraint System").

 SAPs are defined and constructed from R1CS in \[GM17].

 The implementation of the reduction follows, extends, and optimizes
 the efficient approach described in Appendix E of \[BCGTV13].

 References:

 \[BCGTV13]
 "SNARKs for C: Verifying Program Executions Succinctly and in Zero Knowledge",
 Eli Ben-Sasson, Alessandro Chiesa, Daniel Genkin, Eran Tromer, Madars Virza,
 CRYPTO 2013,
 <http://eprint.iacr.org/2013/507>

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

#ifndef R1CS_TO_SAP_HPP_
#define R1CS_TO_SAP_HPP_

#include <libsnark/relations/arithmetic_programs/sap/sap.hpp>
#include <libsnark/relations/constraint_satisfaction_problems/r1cs/r1cs.hpp>

namespace libsnark {

/**
 * Helper function to find evaluation domain that will be used by the reduction
 * for a given R1CS instance.
 */
template<typename FieldT>
std::shared_ptr<libfqfft::evaluation_domain<FieldT> > r1cs_to_sap_get_domain(const r1cs_constraint_system<FieldT> &cs);

/**
 * Instance map for the R1CS-to-QAP reduction.
 */
template<typename FieldT>
sap_instance<FieldT> r1cs_to_sap_instance_map(const r1cs_constraint_system<FieldT> &cs);

/**
 * Instance map for the R1CS-to-QAP reduction followed by evaluation of the resulting QAP instance.
 */
template<typename FieldT>
sap_instance_evaluation<FieldT> r1cs_to_sap_instance_map_with_evaluation(const r1cs_constraint_system<FieldT> &cs,
                                                                         const FieldT &t);

/**
 * Witness map for the R1CS-to-QAP reduction.
 *
 * The witness map takes zero knowledge into account when d1,d2 are random.
 */
template<typename FieldT>
sap_witness<FieldT> r1cs_to_sap_witness_map(const r1cs_constraint_system<FieldT> &cs,
                                            const r1cs_primary_input<FieldT> &primary_input,
                                            const r1cs_auxiliary_input<FieldT> &auxiliary_input,
                                            const FieldT &d1,
                                            const FieldT &d2);

} // libsnark

#include <libsnark/reductions/r1cs_to_sap/r1cs_to_sap.tcc>

#endif // R1CS_TO_SAP_HPP_
