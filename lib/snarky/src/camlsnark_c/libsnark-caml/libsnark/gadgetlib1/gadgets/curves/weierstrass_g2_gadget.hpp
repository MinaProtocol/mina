/** @file
 *****************************************************************************

 Declaration of interfaces for G2 gadgets.

 The gadgets verify curve arithmetic in G2 = E'(F) where E'/F^e: y^2 = x^3 + A' * X + B'
 is an elliptic curve over F^e in short Weierstrass form.

 *****************************************************************************
 * @author     This file is part of libsnark, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef WEIERSTRASS_G2_GADGET_HPP_
#define WEIERSTRASS_G2_GADGET_HPP_

#include <memory>

#include <libff/algebra/curves/public_params.hpp>

#include <libsnark/gadgetlib1/gadget.hpp>
#include <libsnark/gadgetlib1/gadgets/pairing/pairing_params.hpp>

namespace libsnark {

/**
 * Gadget that represents a G2 variable.
 */
template<typename ppT>
class G2_variable : public gadget<libff::Fr<ppT> > {
public:
    typedef libff::Fr<ppT> FieldT;
    typedef libff::Fqe<other_curve<ppT> > FqeT;
    typedef libff::Fqk<other_curve<ppT> > FqkT;

    std::shared_ptr<Fqe_variable<ppT> > X;
    std::shared_ptr<Fqe_variable<ppT> > Y;

    pb_linear_combination_array<FieldT> all_vars;

    G2_variable(protoboard<FieldT> &pb,
                const std::string &annotation_prefix);
    G2_variable(protoboard<FieldT> &pb,
                const libff::G2<other_curve<ppT> > &Q,
                const std::string &annotation_prefix);

    void generate_r1cs_witness(const libff::G2<other_curve<ppT> > &Q);

    // (See a comment in r1cs_ppzksnark_verifier_gadget.hpp about why
    // we mark this function noinline.) TODO: remove later
    static size_t __attribute__((noinline)) size_in_bits();
    static size_t num_variables();
};

/**
 * Gadget that creates constraints for the validity of a G2 variable.
 */
template<typename ppT>
class G2_checker_gadget : public gadget<libff::Fr<ppT> > {
public:
    typedef libff::Fr<ppT> FieldT;
    typedef libff::Fqe<other_curve<ppT> > FqeT;
    typedef libff::Fqk<other_curve<ppT> > FqkT;

    G2_variable<ppT> Q;

    std::shared_ptr<Fqe_variable<ppT> > Xsquared;
    std::shared_ptr<Fqe_variable<ppT> > Ysquared;
    std::shared_ptr<Fqe_variable<ppT> > Xsquared_plus_a;
    std::shared_ptr<Fqe_variable<ppT> > Ysquared_minus_b;

    std::shared_ptr<Fqe_sqr_gadget<ppT> > compute_Xsquared;
    std::shared_ptr<Fqe_sqr_gadget<ppT> > compute_Ysquared;
    std::shared_ptr<Fqe_mul_gadget<ppT> > curve_equation;

    G2_checker_gadget(protoboard<FieldT> &pb,
                      const G2_variable<ppT> &Q,
                      const std::string &annotation_prefix);
    void generate_r1cs_constraints();
    void generate_r1cs_witness();
};

/**
 * Gadget that creates constraints for G2 addition.
 */
template<typename ppT>
class G2_add_gadget : public gadget<libff::Fr<ppT> > {
public:
    typedef libff::Fr<ppT> FieldT;
    typedef libff::Fqe<other_curve<ppT> > FqeT;

    std::shared_ptr<Fqe_variable<ppT>> lambda;
    std::shared_ptr<Fqe_variable<ppT>> inv;

    G2_variable<ppT> A;
    G2_variable<ppT> B;
    G2_variable<ppT> C;

    std::shared_ptr<Fqe_variable<ppT> > B_x_sub_A_x;
    std::shared_ptr<Fqe_variable<ppT> > B_y_sub_A_y;
    std::shared_ptr<Fqe_variable<ppT> > C_x_add_A_x_add_B_x;
    std::shared_ptr<Fqe_variable<ppT> > A_x_sub_C_x;
    std::shared_ptr<Fqe_variable<ppT> > C_y_add_A_y;
    std::shared_ptr<Fqe_variable<ppT> > Fqe_one;

    std::shared_ptr<Fqe_mul_gadget<ppT> > calc_lambda;
    std::shared_ptr<Fqe_mul_gadget<ppT> > calc_X;
    std::shared_ptr<Fqe_mul_gadget<ppT> > calc_Y;
    std::shared_ptr<Fqe_mul_gadget<ppT> > no_special_cases;

    G2_add_gadget(protoboard<FieldT> &pb,
                  const G2_variable<ppT> &A,
                  const G2_variable<ppT> &B,
                  const G2_variable<ppT> &C,
                  const std::string &annotation_prefix);
    void generate_r1cs_constraints();
    void generate_r1cs_witness();
};

} // libsnark

#include <libsnark/gadgetlib1/gadgets/curves/weierstrass_g2_gadget.tcc>

#endif // WEIERSTRASS_G2_GADGET_HPP_
