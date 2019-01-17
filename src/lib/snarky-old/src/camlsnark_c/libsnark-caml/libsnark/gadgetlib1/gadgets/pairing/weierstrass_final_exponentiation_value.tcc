/** @file
 *****************************************************************************
 Implementation of interfaces for final exponentiation gadgets.
 See weierstrass_final_exponentiation.hpp .
 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef WEIERSTRASS_FINAL_EXPONENTIATION_VALUE_TCC_
#define WEIERSTRASS_FINAL_EXPONENTIATION_VALUE_TCC_

#include <libsnark/gadgetlib1/gadgets/basic_gadgets.hpp>
#include <libsnark/gadgetlib1/gadgets/pairing/mnt_pairing_params.hpp>

#include <libsnark/gadgetlib1/constraint_profiling.hpp>

namespace libsnark {

template<typename ppT>
mnt4_final_exp_value_gadget<ppT>::mnt4_final_exp_value_gadget(protoboard<FieldT> &pb,
                                                  const Fqk_variable<ppT> &el,
                                                  const Fqk_variable<ppT> &result,
                                                  const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    el(el),
    result(result)
{
    one.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " one")));
    el_inv.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " el_inv")));
    el_q_3.reset(new Fqk_variable<ppT>(el.Frobenius_map(3)));
    el_q_3_minus_1.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " el_q_3_minus_1")));
    alpha.reset(new Fqk_variable<ppT>(el_q_3_minus_1->Frobenius_map(1)));
    beta.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " beta")));
    beta_q.reset(new Fqk_variable<ppT>(beta->Frobenius_map(1)));

    el_inv_q_3.reset(new Fqk_variable<ppT>(el_inv->Frobenius_map(3)));
    el_inv_q_3_minus_1.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " el_inv_q_3_minus_1")));
    inv_alpha.reset(new Fqk_variable<ppT>(el_inv_q_3_minus_1->Frobenius_map(1)));
    inv_beta.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " inv_beta")));
    w1.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " w1")));
    w0.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " w0")));

    compute_el_inv.reset(new Fqk_mul_gadget<ppT>(pb, el, *el_inv, *one, FMT(annotation_prefix, " compute_el_inv")));
    compute_el_q_3_minus_1.reset(new Fqk_mul_gadget<ppT>(pb, *el_q_3, *el_inv, *el_q_3_minus_1, FMT(annotation_prefix, " compute_el_q_3_minus_1")));
    compute_beta.reset(new Fqk_mul_gadget<ppT>(pb, *alpha, *el_q_3_minus_1, *beta, FMT(annotation_prefix, " compute_beta")));

    compute_el_inv_q_3_minus_1.reset(new Fqk_mul_gadget<ppT>(pb, *el_inv_q_3, el, *el_inv_q_3_minus_1, FMT(annotation_prefix, " compute_el_inv__q_3_minus_1")));
    compute_inv_beta.reset(new Fqk_mul_gadget<ppT>(pb, *inv_alpha, *el_inv_q_3_minus_1, *inv_beta, FMT(annotation_prefix, " compute_inv_beta")));

    compute_w1.reset(new exponentiation_gadget<FqkT<ppT>, Fp6_variable, Fp6_mul_gadget, Fp6_cyclotomic_sqr_gadget, libff::mnt6_q_limbs>(
        pb, *beta_q, libff::mnt6_final_exponent_last_chunk_w1, *w1, FMT(annotation_prefix, " compute_w1")));

    compute_w0.reset(new exponentiation_gadget<FqkT<ppT>, Fp6_variable, Fp6_mul_gadget, Fp6_cyclotomic_sqr_gadget, libff::mnt6_q_limbs>(
        pb, (libff::mnt6_final_exponent_last_chunk_is_w0_neg ? *inv_beta : *beta), libff::mnt6_final_exponent_last_chunk_abs_of_w0, *w0, FMT(annotation_prefix, " compute_w0")));

    compute_result.reset(new Fqk_mul_gadget<ppT>(pb, *w1, *w0, result, FMT(annotation_prefix, " compute_result")));
}

template<typename ppT>
void mnt4_final_exp_value_gadget<ppT>::generate_r1cs_constraints()
{
    one->generate_r1cs_equals_const_constraints(libff::Fqk<other_curve<ppT> >::one());

    compute_el_inv->generate_r1cs_constraints();
    compute_el_q_3_minus_1->generate_r1cs_constraints();
    compute_beta->generate_r1cs_constraints();

    compute_el_inv_q_3_minus_1->generate_r1cs_constraints();
    compute_inv_beta->generate_r1cs_constraints();

    compute_w0->generate_r1cs_constraints();
    compute_w1->generate_r1cs_constraints();
    compute_result->generate_r1cs_constraints();
}

template<typename ppT>
void mnt4_final_exp_value_gadget<ppT>::generate_r1cs_witness()
{
    one->generate_r1cs_witness(libff::Fqk<other_curve<ppT> >::one());
    el_inv->generate_r1cs_witness(el.get_element().inverse());

    compute_el_inv->generate_r1cs_witness();
    el_q_3->evaluate();
    compute_el_q_3_minus_1->generate_r1cs_witness();
    alpha->evaluate();
    compute_beta->generate_r1cs_witness();
    beta_q->evaluate();

    el_inv_q_3->evaluate();
    compute_el_inv_q_3_minus_1->generate_r1cs_witness();
    inv_alpha->evaluate();
    compute_inv_beta->generate_r1cs_witness();

    compute_w0->generate_r1cs_witness();
    compute_w1->generate_r1cs_witness();
    compute_result->generate_r1cs_witness();
}

template<typename ppT>
mnt6_final_exp_value_gadget<ppT>::mnt6_final_exp_value_gadget(protoboard<FieldT> &pb,
                                                  const Fqk_variable<ppT> &el,
                                                  const Fqk_variable<ppT> &result,
                                                  const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    el(el),
    result(result)
{
    one.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " one")));
    el_inv.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " el_inv")));
    el_q_2.reset(new Fqk_variable<ppT>(el.Frobenius_map(2)));
    el_q_2_minus_1.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " el_q_2_minus_1")));
    el_q_3_minus_q.reset(new Fqk_variable<ppT>(el_q_2_minus_1->Frobenius_map(1)));
    el_inv_q_2.reset(new Fqk_variable<ppT>(el_inv->Frobenius_map(2)));
    el_inv_q_2_minus_1.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " el_inv_q_2_minus_1")));
    w1.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " w1")));
    w0.reset(new Fqk_variable<ppT>(pb, FMT(annotation_prefix, " w0")));

    compute_el_inv.reset(new Fqk_mul_gadget<ppT>(pb, el, *el_inv, *one, FMT(annotation_prefix, " compute_el_inv")));
    compute_el_q_2_minus_1.reset(new Fqk_mul_gadget<ppT>(pb, *el_q_2, *el_inv, *el_q_2_minus_1, FMT(annotation_prefix, " compute_el_q_2_minus_1")));
    compute_el_inv_q_2_minus_1.reset(new Fqk_mul_gadget<ppT>(pb, *el_inv_q_2, el, *el_inv_q_2_minus_1, FMT(annotation_prefix, " compute_el_inv_q_2_minus_1")));

    compute_w1.reset(new exponentiation_gadget<FqkT<ppT>, Fp4_variable, Fp4_mul_gadget, Fp4_cyclotomic_sqr_gadget, libff::mnt4_q_limbs>(
        pb, *el_q_3_minus_q, libff::mnt4_final_exponent_last_chunk_w1, *w1, FMT(annotation_prefix, " compute_w1")));
    compute_w0.reset(new exponentiation_gadget<FqkT<ppT>, Fp4_variable, Fp4_mul_gadget, Fp4_cyclotomic_sqr_gadget, libff::mnt4_q_limbs>(
        pb, (libff::mnt4_final_exponent_last_chunk_is_w0_neg ? *el_inv_q_2_minus_1 : *el_q_2_minus_1), libff::mnt4_final_exponent_last_chunk_abs_of_w0, *w0, FMT(annotation_prefix, " compute_w0")));
    compute_result.reset(new Fqk_mul_gadget<ppT>(pb, *w1, *w0, result, FMT(annotation_prefix, " compute_result")));
}

template<typename ppT>
void mnt6_final_exp_value_gadget<ppT>::generate_r1cs_constraints()
{
    one->generate_r1cs_equals_const_constraints(libff::Fqk<other_curve<ppT> >::one());

    compute_el_inv->generate_r1cs_constraints();
    compute_el_q_2_minus_1->generate_r1cs_constraints();
    compute_el_inv_q_2_minus_1->generate_r1cs_constraints();
    compute_w1->generate_r1cs_constraints();
    compute_w0->generate_r1cs_constraints();
    compute_result->generate_r1cs_constraints();
}

template<typename ppT>
void mnt6_final_exp_value_gadget<ppT>::generate_r1cs_witness()
{
    one->generate_r1cs_witness(libff::Fqk<other_curve<ppT> >::one());
    el_inv->generate_r1cs_witness(el.get_element().inverse());

    compute_el_inv->generate_r1cs_witness();
    el_q_2->evaluate();
    compute_el_q_2_minus_1->generate_r1cs_witness();
    el_q_3_minus_q->evaluate();
    el_inv_q_2->evaluate();
    compute_el_inv_q_2_minus_1->generate_r1cs_witness();
    compute_w1->generate_r1cs_witness();
    compute_w0->generate_r1cs_witness();
    compute_result->generate_r1cs_witness();
}

template<typename ppT>
void test_mnt_final_exp_value(const std::string &annotation)
{
    protoboard<libff::Fr<ppT> > pb;
    libff::Fqk<other_curve<ppT>> x = libff::Fqk<other_curve<ppT>>::random_element();

    Fqk_variable<ppT> el(pb, "el");
    Fqk_variable<ppT> result(pb, "result");

    final_exp_value_gadget<ppT> finexp(pb, el, result, "miller");

    PROFILE_CONSTRAINTS(pb, "Final exp")
    {
        finexp.generate_r1cs_constraints();
    }
    PRINT_CONSTRAINT_PROFILING();

    el.generate_r1cs_witness(x);
    finexp.generate_r1cs_witness();
    assert(pb.is_satisfied());

    libff::Fqk<other_curve<ppT> > native_finexp_result = other_curve<ppT>::final_exponentiation(x);

    printf("Must match:\n");
    result.get_element().print();
    native_finexp_result.print();

    assert(result.get_element() == native_finexp_result);
    printf("number of constraints for final exponentiation (Fr is %s)  = %zu\n", annotation.c_str(), pb.num_constraints());
}

} // libsnark

#endif // WEIERSTRASS_FINAL_EXPONENTIATION_VALUE_TCC_
