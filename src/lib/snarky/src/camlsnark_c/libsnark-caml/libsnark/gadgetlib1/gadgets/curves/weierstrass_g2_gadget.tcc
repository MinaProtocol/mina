/** @file
 *****************************************************************************

 Implementation of interfaces for G2 gadgets.

 See weierstrass_g2_gadgets.hpp .

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef WEIERSTRASS_G2_GADGET_TCC_
#define WEIERSTRASS_G2_GADGET_TCC_

#include <libff/algebra/scalar_multiplication/wnaf.hpp>

namespace libsnark {

template<typename ppT>
G2_variable<ppT>::G2_variable(protoboard<FieldT> &pb,
                              const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix)
{
    X.reset(new Fqe_variable<ppT>(pb, FMT(annotation_prefix, " X")));
    Y.reset(new Fqe_variable<ppT>(pb, FMT(annotation_prefix, " Y")));

    all_vars.insert(all_vars.end(), X->all_vars.begin(), X->all_vars.end());
    all_vars.insert(all_vars.end(), Y->all_vars.begin(), Y->all_vars.end());
}

template<typename ppT>
G2_variable<ppT>::G2_variable(protoboard<FieldT> &pb,
                              const libff::G2<other_curve<ppT> > &Q,
                              const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix)
{
    libff::G2<other_curve<ppT> > Q_copy = Q;
    Q_copy.to_affine_coordinates();

    X.reset(new Fqe_variable<ppT>(pb, Q_copy.X(), FMT(annotation_prefix, " X")));
    Y.reset(new Fqe_variable<ppT>(pb, Q_copy.Y(), FMT(annotation_prefix, " Y")));

    all_vars.insert(all_vars.end(), X->all_vars.begin(), X->all_vars.end());
    all_vars.insert(all_vars.end(), Y->all_vars.begin(), Y->all_vars.end());
}

template<typename ppT>
void G2_variable<ppT>::generate_r1cs_witness(const libff::G2<other_curve<ppT> > &Q)
{
    libff::G2<other_curve<ppT> > Qcopy = Q;
    Qcopy.to_affine_coordinates();

    X->generate_r1cs_witness(Qcopy.X());
    Y->generate_r1cs_witness(Qcopy.Y());
}

template<typename ppT>
size_t G2_variable<ppT>::size_in_bits()
{
    return 2 * Fqe_variable<ppT>::size_in_bits();
}

template<typename ppT>
size_t G2_variable<ppT>::num_variables()
{
    return 2 * Fqe_variable<ppT>::num_variables();
}

template<typename ppT>
G2_checker_gadget<ppT>::G2_checker_gadget(protoboard<FieldT> &pb,
                                          const G2_variable<ppT> &Q,
                                          const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    Q(Q)
{
    Xsquared.reset(new Fqe_variable<ppT>(pb, FMT(annotation_prefix, " Xsquared")));
    Ysquared.reset(new Fqe_variable<ppT>(pb, FMT(annotation_prefix, " Ysquared")));

    compute_Xsquared.reset(new Fqe_sqr_gadget<ppT>(pb, *(Q.X), *Xsquared, FMT(annotation_prefix, " compute_Xsquared")));
    compute_Ysquared.reset(new Fqe_sqr_gadget<ppT>(pb, *(Q.Y), *Ysquared, FMT(annotation_prefix, " compute_Ysquared")));

    Xsquared_plus_a.reset(new Fqe_variable<ppT>((*Xsquared) + libff::G2<other_curve<ppT> >::coeff_a));
    Ysquared_minus_b.reset(new Fqe_variable<ppT>((*Ysquared) + (-libff::G2<other_curve<ppT> >::coeff_b)));

    curve_equation.reset(new Fqe_mul_gadget<ppT>(pb, *(Q.X), *Xsquared_plus_a, *Ysquared_minus_b, FMT(annotation_prefix, " curve_equation")));
}

template<typename ppT>
void G2_checker_gadget<ppT>::generate_r1cs_constraints()
{
    compute_Xsquared->generate_r1cs_constraints();
    compute_Ysquared->generate_r1cs_constraints();
    curve_equation->generate_r1cs_constraints();
}

template<typename ppT>
void G2_checker_gadget<ppT>::generate_r1cs_witness()
{
    compute_Xsquared->generate_r1cs_witness();
    compute_Ysquared->generate_r1cs_witness();
    Xsquared_plus_a->evaluate();
    curve_equation->generate_r1cs_witness();
}

template<typename ppT>
void test_G2_checker_gadget(const std::string &annotation)
{
    protoboard<libff::Fr<ppT> > pb;
    G2_variable<ppT> g(pb, "g");
    G2_checker_gadget<ppT> g_check(pb, g, "g_check");
    g_check.generate_r1cs_constraints();

    printf("positive test\n");
    g.generate_r1cs_witness(libff::G2<other_curve<ppT> >::one());
    g_check.generate_r1cs_witness();
    assert(pb.is_satisfied());

    printf("negative test\n");
    g.generate_r1cs_witness(libff::G2<other_curve<ppT> >::zero());
    g_check.generate_r1cs_witness();
    assert(!pb.is_satisfied());

    printf("number of constraints for G2 checker (Fr is %s)  = %zu\n", annotation.c_str(), pb.num_constraints());
}

template<typename ppT>
G2_add_gadget<ppT>::G2_add_gadget(protoboard<FieldT> &pb,
                                  const G2_variable<ppT> &A,
                                  const G2_variable<ppT> &B,
                                  const G2_variable<ppT> &C,
                                  const std::string &annotation_prefix) :
    gadget<FieldT>(pb, annotation_prefix),
    A(A),
    B(B),
    C(C)
{
    /*
      lambda = (B.y - A.y)/(B.x - A.x)
      C.x = lambda^2 - A.x - B.x
      C.y = lambda(A.x - C.x) - A.y

      Special cases:

      doubling: if B.y = A.y and B.x = A.x then lambda is unbound and
      C = (lambda^2, lambda^3)

      addition of negative point: if B.y = -A.y and B.x = A.x then no
      lambda can satisfy the first equation unless B.y - A.y = 0. But
      then this reduces to doubling.

      So we need to check that A.x - B.x != 0, which can be done by
      enforcing I * (B.x - A.x) = 1
    */

    lambda.reset(
      new Fqe_variable<ppT>(pb, FMT(annotation_prefix, " lambda")));
    inv.reset(
      new Fqe_variable<ppT>(pb, FMT(annotation_prefix, " lambda")));
    B_x_sub_A_x.reset(
      new Fqe_variable<ppT>(*(B.X) - *(A.X)));
    B_y_sub_A_y.reset(
      new Fqe_variable<ppT>(*(B.Y) - *(A.Y)));
    C_x_add_A_x_add_B_x.reset(
      new Fqe_variable<ppT>(*(C.X) + *(A.X) + *(B.X)));
    A_x_sub_C_x.reset(
      new Fqe_variable<ppT>(*(A.X) - *(C.X)));
    C_y_add_A_y.reset(
      new Fqe_variable<ppT>(*(C.Y) + *(A.Y)));
    Fqe_one.reset(
      new Fqe_variable<ppT>(pb, FqeT::one(), FMT(annotation_prefix, "Fqe_one")));

    calc_lambda.reset(new Fqe_mul_gadget<ppT>(pb,
          *lambda, *B_x_sub_A_x, *B_y_sub_A_y,
          FMT(annotation_prefix, " calc_lambda")));
    calc_X.reset(new Fqe_mul_gadget<ppT>(pb,
          *lambda, *lambda, *C_x_add_A_x_add_B_x,
          FMT(annotation_prefix, " calc_X")));
    calc_Y.reset(new Fqe_mul_gadget<ppT>(pb,
          *lambda, *A_x_sub_C_x, *C_y_add_A_y,
          FMT(annotation_prefix, " calc_Y")));
    no_special_cases.reset(new Fqe_mul_gadget<ppT>(pb,
          *inv, *B_x_sub_A_x, *Fqe_one,
          FMT(annotation_prefix, " no_special_cases")));
}

template<typename ppT>
void G2_add_gadget<ppT>::generate_r1cs_constraints()
{
    calc_lambda->generate_r1cs_constraints();
    calc_X->generate_r1cs_constraints();
    calc_Y->generate_r1cs_constraints();
    no_special_cases->generate_r1cs_constraints();
}

template<typename ppT>
void G2_add_gadget<ppT>::generate_r1cs_witness()
{
    inv->generate_r1cs_witness(
      ( B.X->get_element() - A.X->get_element() ).inverse());
    lambda->generate_r1cs_witness(
      (B.Y->get_element() - A.Y->get_element())
      * inv->get_element() );

    C.X->generate_r1cs_witness(
      lambda->get_element().squared() - A.X->get_element() - B.X->get_element());
    C.Y->generate_r1cs_witness(
      lambda->get_element() * ( A.X->get_element() - C.X->get_element()) - A.Y->get_element());

    B_x_sub_A_x->evaluate();
    B_y_sub_A_y->evaluate();
    C_x_add_A_x_add_B_x->evaluate();
    A_x_sub_C_x->evaluate();
    C_y_add_A_y->evaluate();
    Fqe_one->evaluate();

    calc_lambda->generate_r1cs_witness_internal();
    calc_X->generate_r1cs_witness_internal();
    calc_Y->generate_r1cs_witness_internal();
    no_special_cases->generate_r1cs_witness_internal();
}

} // libsnark

#endif // WEIERSTRASS_G2_GADGET_TCC_
