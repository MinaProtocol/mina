/** @file
 *****************************************************************************

 Implementation of interfaces for a R1CS-to-SAP reduction.

 See r1cs_to_qap.hpp .

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef R1CS_TO_SAP_TCC_
#define R1CS_TO_SAP_TCC_

#include <libff/common/profiling.hpp>
#include <libff/common/utils.hpp>
#include <libfqfft/evaluation_domain/get_evaluation_domain.hpp>

namespace libsnark {

/**
 * Helper function to multiply a field element by 4 efficiently
 */
template<typename FieldT>
FieldT times_four(FieldT x)
{
    FieldT times_two = x + x;
    return times_two + times_two;
}

/**
 * Helper function to find evaluation domain that will be used by the reduction
 * for a given R1CS instance.
 */
template<typename FieldT>
std::shared_ptr<libfqfft::evaluation_domain<FieldT> > r1cs_to_sap_get_domain(const r1cs_constraint_system<FieldT> &cs)
{
    /*
     * the SAP instance will have:
     * - one constraints for every constraint in the original constraint system
     * - one additional constraint for every constraint in the original constraint system which is not square
     * - two constraints for every public input, except the 0th, which
     *   contributes just one extra constraint
     * see comments in r1cs_to_sap_instance_map for details on where these
     * constraints come from.
     */
    return libfqfft::get_evaluation_domain<FieldT>(
        2 * cs.num_constraints() - cs.num_square_constraints
        + 2 * cs.num_inputs() + 1);
}

/**
 * Instance map for the R1CS-to-SAP reduction.
 */
template<typename FieldT>
sap_instance<FieldT> r1cs_to_sap_instance_map(const r1cs_constraint_system<FieldT> &cs)
{
    libff::enter_block("Call to r1cs_to_sap_instance_map");

    const std::shared_ptr<libfqfft::evaluation_domain<FieldT> > domain =
        r1cs_to_sap_get_domain(cs);

    size_t sap_num_variables = cs.num_variables() + (cs.num_constraints() - cs.num_square_constraints) + cs.num_inputs();

    std::vector<std::map<size_t, FieldT> > A_in_Lagrange_basis(sap_num_variables + 1);
    std::vector<std::map<size_t, FieldT> > C_in_Lagrange_basis(sap_num_variables + 1);

    libff::enter_block("Compute polynomials A, C in Lagrange basis");
    /**
     * process R1CS constraints, converting a constraint of the form
     *   \sum a_i x_i * \sum b_i x_i = \sum c_i x_i
     * into two constraints
     *   (\sum (a_i + b_i) x_i)^2 = 4 \sum c_i x_i + x'_i
     *   (\sum (a_i - b_i) x_i)^2 = x'_i
     * where x'_i is an extra variable (a separate one for each original
     * constraint)
     *
     * this adds 2 * cs.num_constraints() constraints
     *   (numbered 0 .. 2 * cs.num_constraints() - 1)
     * and cs.num_constraints() extra variables
     *   (numbered cs.num_variables() + 1 .. cs.num_variables() + cs.num_constraints())
     */
    size_t extra_var_offset = cs.num_variables() + 1;
    size_t next_square_constraint_index = 0;
    size_t non_square_constraint_count = 0;
    for (size_t i = 0; i < cs.num_constraints(); ++i)
    {
        if (cs.constraints[i].is_square) {
          for (size_t j = 0; j < cs.constraints[i].a.terms.size(); ++j)
          {
            A_in_Lagrange_basis[cs.constraints[i].a.terms[j].index][next_square_constraint_index] +=
              cs.constraints[i].a.terms[j].coeff;
          }

          for (size_t j = 0; j < cs.constraints[i].c.terms.size(); ++j)
          {
            C_in_Lagrange_basis[cs.constraints[i].c.terms[j].index][next_square_constraint_index] +=
              cs.constraints[i].c.terms[j].coeff;
          }

          next_square_constraint_index += 1;
        }
        else {
          for (size_t j = 0; j < cs.constraints[i].a.terms.size(); ++j)
          {
              A_in_Lagrange_basis[cs.constraints[i].a.terms[j].index][next_square_constraint_index] +=
                  cs.constraints[i].a.terms[j].coeff;
              A_in_Lagrange_basis[cs.constraints[i].a.terms[j].index][next_square_constraint_index + 1] +=
                  cs.constraints[i].a.terms[j].coeff;
          }

          for (size_t j = 0; j < cs.constraints[i].b.terms.size(); ++j)
          {
              A_in_Lagrange_basis[cs.constraints[i].b.terms[j].index][next_square_constraint_index] +=
                  cs.constraints[i].b.terms[j].coeff;
              A_in_Lagrange_basis[cs.constraints[i].b.terms[j].index][next_square_constraint_index + 1] -=
                  cs.constraints[i].b.terms[j].coeff;
          }

          for (size_t j = 0; j < cs.constraints[i].c.terms.size(); ++j)
          {
              C_in_Lagrange_basis[cs.constraints[i].c.terms[j].index][next_square_constraint_index] +=
                    times_four(cs.constraints[i].c.terms[j].coeff);
          }

          C_in_Lagrange_basis[extra_var_offset + non_square_constraint_count][next_square_constraint_index] += FieldT::one();
          C_in_Lagrange_basis[extra_var_offset + non_square_constraint_count][next_square_constraint_index + 1] += FieldT::one();

          non_square_constraint_count += 1;
          next_square_constraint_index += 2;
        }
    }

    /**
     * add and convert the extra constraints
     *     x_i * 1 = x_i
     * to ensure that the polynomials 0 .. cs.num_inputs() are linearly
     * independent from each other and the rest, which is required for security
     * proofs (see [GM17, p. 29])
     *
     * note that i = 0 is a special case, where this constraint is expressible
     * as x_0^2 = x_0,
     * whereas for every other i we introduce an extra variable x''_i and do
     *   (x_i + x_0)^2 = 4 x_i + x''_i
     *   (x_i - x_0)^2 = x''_i
     *
     * this adds 2 * cs.num_inputs() + 1 extra constraints
     *   (numbered 2 * cs.num_constraints() ..
     *             2 * cs.num_constraints() + 2 * cs.num_inputs())
     * and cs.num_inputs() extra variables
     *   (numbered cs.num_variables() + cs.num_constraints() + 1 ..
     *             cs.num_variables() + cs.num_constraints() + cs.num_inputs())
     */

    size_t extra_constr_offset = next_square_constraint_index;
    size_t extra_var_offset2 = cs.num_variables() + non_square_constraint_count;
    /**
     * NB: extra variables start at (extra_var_offset2 + 1), because i starts at
     *     1 below
     */

    A_in_Lagrange_basis[0][extra_constr_offset] = FieldT::one();
    C_in_Lagrange_basis[0][extra_constr_offset] = FieldT::one();

    for (size_t i = 1; i <= cs.num_inputs(); ++i)
    {
        A_in_Lagrange_basis[i][extra_constr_offset + 2 * i - 1] += FieldT::one();
        A_in_Lagrange_basis[0][extra_constr_offset + 2 * i - 1] += FieldT::one();
        C_in_Lagrange_basis[i][extra_constr_offset + 2 * i - 1] +=
            times_four(FieldT::one());
        C_in_Lagrange_basis[extra_var_offset2 + i][extra_constr_offset + 2 * i - 1] += FieldT::one();

        A_in_Lagrange_basis[i][extra_constr_offset + 2 * i] += FieldT::one();
        A_in_Lagrange_basis[0][extra_constr_offset + 2 * i] -= FieldT::one();
        C_in_Lagrange_basis[extra_var_offset2 + i][extra_constr_offset + 2 * i] += FieldT::one();
    }

    libff::leave_block("Compute polynomials A, C in Lagrange basis");

    libff::leave_block("Call to r1cs_to_sap_instance_map");

    return sap_instance<FieldT>(domain,
                                sap_num_variables,
                                domain->m,
                                cs.num_inputs(),
                                std::move(A_in_Lagrange_basis),
                                std::move(C_in_Lagrange_basis));
}

/**
 * Instance map for the R1CS-to-SAP reduction followed by evaluation
 * of the resulting QAP instance.
 */
template<typename FieldT>
sap_instance_evaluation<FieldT> r1cs_to_sap_instance_map_with_evaluation(const r1cs_constraint_system<FieldT> &cs,
                                                                         const FieldT &t)
{
    libff::enter_block("Call to r1cs_to_sap_instance_map_with_evaluation");

    const std::shared_ptr<libfqfft::evaluation_domain<FieldT> > domain =
        r1cs_to_sap_get_domain(cs);

    size_t sap_num_variables = cs.num_variables() + (cs.num_constraints() - cs.num_square_constraints) + cs.num_inputs();

    std::vector<FieldT> At, Ct, Ht;

    At.resize(sap_num_variables + 1, FieldT::zero());
    Ct.resize(sap_num_variables + 1, FieldT::zero());
    Ht.reserve(domain->m+1);

    const FieldT Zt = domain->compute_vanishing_polynomial(t);

    libff::enter_block("Compute evaluations of A, C, H at t");
    const std::vector<FieldT> u = domain->evaluate_all_lagrange_polynomials(t);
    /**
     * add and process all constraints as in r1cs_to_sap_instance_map
     */
    size_t extra_var_offset = cs.num_variables() + 1;
    size_t next_square_constraint_index = 0;
    size_t non_square_constraint_count = 0;
    for (size_t i = 0; i < cs.num_constraints(); ++i)
    {
        if (cs.constraints[i].is_square) {
          for (size_t j = 0; j < cs.constraints[i].a.terms.size(); ++j)
          {
              At[cs.constraints[i].a.terms[j].index] +=
                  u[next_square_constraint_index] * cs.constraints[i].a.terms[j].coeff;
          }

          for (size_t j = 0; j < cs.constraints[i].c.terms.size(); ++j)
          {
              Ct[cs.constraints[i].c.terms[j].index] +=
                  u[next_square_constraint_index] * cs.constraints[i].c.terms[j].coeff;
          }

          next_square_constraint_index += 1;
        } else {
          for (size_t j = 0; j < cs.constraints[i].a.terms.size(); ++j)
          {
              At[cs.constraints[i].a.terms[j].index] +=
                  u[next_square_constraint_index] * cs.constraints[i].a.terms[j].coeff;
              At[cs.constraints[i].a.terms[j].index] +=
                  u[next_square_constraint_index + 1] * cs.constraints[i].a.terms[j].coeff;
          }

          for (size_t j = 0; j < cs.constraints[i].b.terms.size(); ++j)
          {
              At[cs.constraints[i].b.terms[j].index] +=
                  u[next_square_constraint_index] * cs.constraints[i].b.terms[j].coeff;
              At[cs.constraints[i].b.terms[j].index] -=
                  u[next_square_constraint_index + 1] * cs.constraints[i].b.terms[j].coeff;
          }

          for (size_t j = 0; j < cs.constraints[i].c.terms.size(); ++j)
          {
              Ct[cs.constraints[i].c.terms[j].index] +=
                  times_four(u[next_square_constraint_index] * cs.constraints[i].c.terms[j].coeff);
          }

          Ct[extra_var_offset + non_square_constraint_count] += u[next_square_constraint_index];
          Ct[extra_var_offset + non_square_constraint_count] += u[next_square_constraint_index + 1];

          non_square_constraint_count += 1;
          next_square_constraint_index += 2;
        }
    }

    size_t extra_constr_offset = next_square_constraint_index;
    size_t extra_var_offset2 = cs.num_variables() + non_square_constraint_count;

    At[0] += u[extra_constr_offset];
    Ct[0] += u[extra_constr_offset];

    for (size_t i = 1; i <= cs.num_inputs(); ++i)
    {
        At[i] += u[extra_constr_offset + 2 * i - 1];
        At[0] += u[extra_constr_offset + 2 * i - 1];
        Ct[i] += times_four(u[extra_constr_offset + 2 * i - 1]);
        Ct[extra_var_offset2 + i] += u[extra_constr_offset + 2 * i - 1];

        At[i] += u[extra_constr_offset + 2 * i];
        At[0] -= u[extra_constr_offset + 2 * i];
        Ct[extra_var_offset2 + i] += u[extra_constr_offset + 2 * i];
    }

    FieldT ti = FieldT::one();
    for (size_t i = 0; i < domain->m+1; ++i)
    {
        Ht.emplace_back(ti);
        ti *= t;
    }
    libff::leave_block("Compute evaluations of A, C, H at t");

    libff::leave_block("Call to r1cs_to_sap_instance_map_with_evaluation");

    return sap_instance_evaluation<FieldT>(domain,
                                           sap_num_variables,
                                           domain->m,
                                           cs.num_inputs(),
                                           t,
                                           std::move(At),
                                           std::move(Ct),
                                           std::move(Ht),
                                           Zt);
}

/**
 * Witness map for the R1CS-to-SAP reduction.
 *
 * The witness map takes zero knowledge into account when d1, d2 are random.
 *
 * More precisely, compute the coefficients
 *     h_0,h_1,...,h_n
 * of the polynomial
 *     H(z) := (A(z)*A(z)-C(z))/Z(z)
 * where
 *   A(z) := A_0(z) + \sum_{k=1}^{m} w_k A_k(z) + d1 * Z(z)
 *   C(z) := C_0(z) + \sum_{k=1}^{m} w_k C_k(z) + d2 * Z(z)
 *   Z(z) := "vanishing polynomial of set S"
 * and
 *   m = number of variables of the SAP
 *   n = degree of the SAP
 *
 * This is done as follows:
 *  (1) compute evaluations of A,C on S = {sigma_1,...,sigma_n}
 *  (2) compute coefficients of A,C
 *  (3) compute evaluations of A,C on T = "coset of S"
 *  (4) compute evaluation of H on T
 *  (5) compute coefficients of H
 *  (6) patch H to account for d1,d2
        (i.e., add coefficients of the polynomial (2*d1*A - d2 + d1^2 * Z))
 *
 * The code below is not as simple as the above high-level description due to
 * some reshuffling to save space.
 */
template<typename FieldT>
sap_witness<FieldT> r1cs_to_sap_witness_map(const r1cs_constraint_system<FieldT> &cs,
                                            const r1cs_primary_input<FieldT> &primary_input,
                                            const r1cs_auxiliary_input<FieldT> &auxiliary_input,
                                            const FieldT &d1,
                                            const FieldT &d2)
{
    libff::enter_block("Call to r1cs_to_sap_witness_map");

    /* sanity check */
    assert(cs.is_satisfied(primary_input, auxiliary_input));

    const std::shared_ptr<libfqfft::evaluation_domain<FieldT> > domain =
        r1cs_to_sap_get_domain(cs);

    size_t sap_num_variables = cs.num_variables() + (cs.num_constraints() - cs.num_square_constraints) + cs.num_inputs();

    r1cs_variable_assignment<FieldT> full_variable_assignment = primary_input;
    full_variable_assignment.insert(full_variable_assignment.end(), auxiliary_input.begin(), auxiliary_input.end());
    /**
     * we need to generate values of all the extra variables that we added
     * during the reduction
     *
     * note: below, we pass full_variable_assignment into the .evaluate()
     * method of the R1CS constraints. however, these extra variables shouldn't
     * be a problem, because .evaluate() only accessess the variables that are
     * actually used in the constraint.
     */
    for (size_t i = 0; i < cs.num_constraints(); ++i)
    {
        /**
         * this is variable (extra_var_offset + i), an extra variable
         * we introduced that is not present in the input.
         * its value is (a - b)^2
         */
        if (! cs.constraints[i].is_square) {
          FieldT extra_var = cs.constraints[i].a.evaluate(full_variable_assignment) -
              cs.constraints[i].b.evaluate(full_variable_assignment);
          extra_var = extra_var * extra_var;
          full_variable_assignment.push_back(extra_var);
        }
    }
    for (size_t i = 1; i <= cs.num_inputs(); ++i)
    {
        /**
         * this is variable (extra_var_offset2 + i), an extra variable
         * we introduced that is not present in the input.
         * its value is (x_i - 1)^2
         */
        FieldT extra_var = full_variable_assignment[i - 1] - FieldT::one();
        extra_var = extra_var * extra_var;
        full_variable_assignment.push_back(extra_var);
    }

    libff::enter_block("Compute evaluation of polynomial A on set S");
    std::vector<FieldT> aA(domain->m, FieldT::zero());

    /* account for all constraints, as in r1cs_to_sap_instance_map */
    size_t next_square_constraint_index = 0;
    for (size_t i = 0; i < cs.num_constraints(); ++i)
    {
        if (cs.constraints[i].is_square) {
          aA[next_square_constraint_index] += cs.constraints[i].a.evaluate(full_variable_assignment);

          next_square_constraint_index += 1;
        } else {
          aA[next_square_constraint_index] += cs.constraints[i].a.evaluate(full_variable_assignment);
          aA[next_square_constraint_index] += cs.constraints[i].b.evaluate(full_variable_assignment);

          aA[next_square_constraint_index + 1] += cs.constraints[i].a.evaluate(full_variable_assignment);
          aA[next_square_constraint_index + 1] -= cs.constraints[i].b.evaluate(full_variable_assignment);

          next_square_constraint_index += 2;
        }
    }

    size_t extra_constr_offset = next_square_constraint_index;

    aA[extra_constr_offset] += FieldT::one();

    for (size_t i = 1; i <= cs.num_inputs(); ++i)
    {
        aA[extra_constr_offset + 2 * i - 1] += full_variable_assignment[i - 1];
        aA[extra_constr_offset + 2 * i - 1] += FieldT::one();

        aA[extra_constr_offset + 2 * i] += full_variable_assignment[i - 1];
        aA[extra_constr_offset + 2 * i] -= FieldT::one();
    }

    libff::leave_block("Compute evaluation of polynomial A on set S");

    libff::enter_block("Compute coefficients of polynomial A");
    domain->iFFT(aA);
    libff::leave_block("Compute coefficients of polynomial A");

    libff::enter_block("Compute ZK-patch");
    std::vector<FieldT> coefficients_for_H(domain->m+1, FieldT::zero());
#ifdef MULTICORE
#pragma omp parallel for
#endif
    /* add coefficients of the polynomial (2*d1*A - d2) + d1*d1*Z */
    for (size_t i = 0; i < domain->m; ++i)
    {
        coefficients_for_H[i] = (d1 * aA[i]) + (d1 * aA[i]);
    }
    coefficients_for_H[0] -= d2;
    domain->add_poly_Z(d1 * d1, coefficients_for_H);
    libff::leave_block("Compute ZK-patch");

    libff::enter_block("Compute evaluation of polynomial A on set T");
    domain->cosetFFT(aA, FieldT::multiplicative_generator);
    libff::leave_block("Compute evaluation of polynomial A on set T");

    libff::enter_block("Compute evaluation of polynomial H on set T");
    std::vector<FieldT> &H_tmp = aA; // can overwrite aA because it is not used later
#ifdef MULTICORE
#pragma omp parallel for
#endif
    for (size_t i = 0; i < domain->m; ++i)
    {
        H_tmp[i] = aA[i]*aA[i];
    }

    libff::enter_block("Compute evaluation of polynomial C on set S");
    std::vector<FieldT> aC(domain->m, FieldT::zero());
    /* again, accounting for all constraints */
    size_t extra_var_offset = cs.num_variables() + 1;
    next_square_constraint_index = 0;
    size_t non_square_constraint_count = 0;
    for (size_t i = 0; i < cs.num_constraints(); ++i)
    {
        if (cs.constraints[i].is_square) {
            aC[next_square_constraint_index] +=
              cs.constraints[i].c.evaluate(full_variable_assignment);

            next_square_constraint_index += 1;
        } else {
            aC[next_square_constraint_index] +=
                times_four(cs.constraints[i].c.evaluate(full_variable_assignment));

            aC[next_square_constraint_index] += full_variable_assignment[extra_var_offset + non_square_constraint_count - 1];
            aC[next_square_constraint_index + 1] += full_variable_assignment[extra_var_offset + non_square_constraint_count - 1];

            next_square_constraint_index += 2;
            non_square_constraint_count += 1;
        }
    }

    size_t extra_var_offset2 = cs.num_variables() + non_square_constraint_count;
    aC[extra_constr_offset] += FieldT::one();

    for (size_t i = 1; i <= cs.num_inputs(); ++i)
    {
        aC[extra_constr_offset + 2 * i - 1] +=
            times_four(full_variable_assignment[i - 1]);

        aC[extra_constr_offset + 2 * i - 1] +=
            full_variable_assignment[extra_var_offset2 + i - 1];
        aC[extra_constr_offset + 2 * i] +=
            full_variable_assignment[extra_var_offset2 + i - 1];
    }

    libff::leave_block("Compute evaluation of polynomial C on set S");

    libff::enter_block("Compute coefficients of polynomial C");
    domain->iFFT(aC);
    libff::leave_block("Compute coefficients of polynomial C");

    libff::enter_block("Compute evaluation of polynomial C on set T");
    domain->cosetFFT(aC, FieldT::multiplicative_generator);
    libff::leave_block("Compute evaluation of polynomial C on set T");

#ifdef MULTICORE
#pragma omp parallel for
#endif
    for (size_t i = 0; i < domain->m; ++i)
    {
        H_tmp[i] = (H_tmp[i]-aC[i]);
    }

    libff::enter_block("Divide by Z on set T");
    domain->divide_by_Z_on_coset(H_tmp);
    libff::leave_block("Divide by Z on set T");

    libff::leave_block("Compute evaluation of polynomial H on set T");

    libff::enter_block("Compute coefficients of polynomial H");
    domain->icosetFFT(H_tmp, FieldT::multiplicative_generator);
    libff::leave_block("Compute coefficients of polynomial H");

    libff::enter_block("Compute sum of H and ZK-patch");
#ifdef MULTICORE
#pragma omp parallel for
#endif
    for (size_t i = 0; i < domain->m; ++i)
    {
        coefficients_for_H[i] += H_tmp[i];
    }
    libff::leave_block("Compute sum of H and ZK-patch");

    libff::leave_block("Call to r1cs_to_sap_witness_map");

    return sap_witness<FieldT>(sap_num_variables,
                               domain->m,
                               cs.num_inputs(),
                               d1,
                               d2,
                               full_variable_assignment,
                               std::move(coefficients_for_H));
}

} // libsnark

#endif // R1CS_TO_SAP_TCC_
