/** @file
*****************************************************************************

Implementation of interfaces for a SAP ("Square Arithmetic Program").

See sap.hpp .

*****************************************************************************
* @author     This file is part of libsnark, developed by SCIPR Lab
*             and contributors (see AUTHORS).
* @copyright  MIT license (see LICENSE file)
*****************************************************************************/

#ifndef SAP_TCC_
#define SAP_TCC_

#include <libff/algebra/scalar_multiplication/multiexp.hpp>
#include <libff/common/profiling.hpp>
#include <libff/common/utils.hpp>
#include <libfqfft/evaluation_domain/evaluation_domain.hpp>

namespace libsnark {

template<typename FieldT>
sap_instance<FieldT>::sap_instance(const std::shared_ptr<libfqfft::evaluation_domain<FieldT> > &domain,
                                   const size_t num_variables,
                                   const size_t degree,
                                   const size_t num_inputs,
                                   const std::vector<std::map<size_t, FieldT> > &A_in_Lagrange_basis,
                                   const std::vector<std::map<size_t, FieldT> > &C_in_Lagrange_basis) :
    num_variables_(num_variables),
    degree_(degree),
    num_inputs_(num_inputs),
    domain(domain),
    A_in_Lagrange_basis(A_in_Lagrange_basis),
    C_in_Lagrange_basis(C_in_Lagrange_basis)
{
}

template<typename FieldT>
sap_instance<FieldT>::sap_instance(const std::shared_ptr<libfqfft::evaluation_domain<FieldT> > &domain,
                                   const size_t num_variables,
                                   const size_t degree,
                                   const size_t num_inputs,
                                   std::vector<std::map<size_t, FieldT> > &&A_in_Lagrange_basis,
                                   std::vector<std::map<size_t, FieldT> > &&C_in_Lagrange_basis) :
    num_variables_(num_variables),
    degree_(degree),
    num_inputs_(num_inputs),
    domain(domain),
    A_in_Lagrange_basis(std::move(A_in_Lagrange_basis)),
    C_in_Lagrange_basis(std::move(C_in_Lagrange_basis))
{
}

template<typename FieldT>
size_t sap_instance<FieldT>::num_variables() const
{
    return num_variables_;
}

template<typename FieldT>
size_t sap_instance<FieldT>::degree() const
{
    return degree_;
}

template<typename FieldT>
size_t sap_instance<FieldT>::num_inputs() const
{
    return num_inputs_;
}

template<typename FieldT>
bool sap_instance<FieldT>::is_satisfied(const sap_witness<FieldT> &witness) const
{
    const FieldT t = FieldT::random_element();

    std::vector<FieldT> At(this->num_variables()+1, FieldT::zero());
    std::vector<FieldT> Ct(this->num_variables()+1, FieldT::zero());
    std::vector<FieldT> Ht(this->degree()+1);

    const FieldT Zt = this->domain->compute_vanishing_polynomial(t);

    const std::vector<FieldT> u = this->domain->evaluate_all_lagrange_polynomials(t);

    for (size_t i = 0; i < this->num_variables()+1; ++i)
    {
        for (auto &el : A_in_Lagrange_basis[i])
        {
            At[i] += u[el.first] * el.second;
        }

        for (auto &el : C_in_Lagrange_basis[i])
        {
            Ct[i] += u[el.first] * el.second;
        }
    }

    FieldT ti = FieldT::one();
    for (size_t i = 0; i < this->degree()+1; ++i)
    {
        Ht[i] = ti;
        ti *= t;
    }

    const sap_instance_evaluation<FieldT> eval_sap_inst(this->domain,
                                                        this->num_variables(),
                                                        this->degree(),
                                                        this->num_inputs(),
                                                        t,
                                                        std::move(At),
                                                        std::move(Ct),
                                                        std::move(Ht),
                                                        Zt);
    return eval_sap_inst.is_satisfied(witness);
}

template<typename FieldT>
sap_instance_evaluation<FieldT>::sap_instance_evaluation(const std::shared_ptr<libfqfft::evaluation_domain<FieldT> > &domain,
                                                         const size_t num_variables,
                                                         const size_t degree,
                                                         const size_t num_inputs,
                                                         const FieldT &t,
                                                         const std::vector<FieldT> &At,
                                                         const std::vector<FieldT> &Ct,
                                                         const std::vector<FieldT> &Ht,
                                                         const FieldT &Zt) :
    num_variables_(num_variables),
    degree_(degree),
    num_inputs_(num_inputs),
    domain(domain),
    t(t),
    At(At),
    Ct(Ct),
    Ht(Ht),
    Zt(Zt)
{
}

template<typename FieldT>
sap_instance_evaluation<FieldT>::sap_instance_evaluation(const std::shared_ptr<libfqfft::evaluation_domain<FieldT> > &domain,
                                                         const size_t num_variables,
                                                         const size_t degree,
                                                         const size_t num_inputs,
                                                         const FieldT &t,
                                                         std::vector<FieldT> &&At,
                                                         std::vector<FieldT> &&Ct,
                                                         std::vector<FieldT> &&Ht,
                                                         const FieldT &Zt) :
    num_variables_(num_variables),
    degree_(degree),
    num_inputs_(num_inputs),
    domain(domain),
    t(t),
    At(std::move(At)),
    Ct(std::move(Ct)),
    Ht(std::move(Ht)),
    Zt(Zt)
{
}

template<typename FieldT>
size_t sap_instance_evaluation<FieldT>::num_variables() const
{
    return num_variables_;
}

template<typename FieldT>
size_t sap_instance_evaluation<FieldT>::degree() const
{
    return degree_;
}

template<typename FieldT>
size_t sap_instance_evaluation<FieldT>::num_inputs() const
{
    return num_inputs_;
}

template<typename FieldT>
bool sap_instance_evaluation<FieldT>::is_satisfied(const sap_witness<FieldT> &witness) const
{
    if (this->num_variables() != witness.num_variables())
    {
        return false;
    }

    if (this->degree() != witness.degree())
    {
        return false;
    }

    if (this->num_inputs() != witness.num_inputs())
    {
        return false;
    }

    if (this->num_variables() != witness.coefficients_for_ACs.size())
    {
        return false;
    }

    if (this->degree()+1 != witness.coefficients_for_H.size())
    {
        return false;
    }

    if (this->At.size() != this->num_variables()+1 || this->Ct.size() != this->num_variables()+1)
    {
        return false;
    }

    if (this->Ht.size() != this->degree()+1)
    {
        return false;
    }

    if (this->Zt != this->domain->compute_vanishing_polynomial(this->t))
    {
        return false;
    }

    FieldT ans_A = this->At[0] + witness.d1*this->Zt;
    FieldT ans_C = this->Ct[0] + witness.d2*this->Zt;
    FieldT ans_H = FieldT::zero();

    ans_A = ans_A + libff::inner_product<FieldT>(this->At.begin()+1,
                                                 this->At.begin()+1+this->num_variables(),
                                                 witness.coefficients_for_ACs.begin(),
                                                 witness.coefficients_for_ACs.begin()+this->num_variables());
    ans_C = ans_C + libff::inner_product<FieldT>(this->Ct.begin()+1,
                                                 this->Ct.begin()+1+this->num_variables(),
                                                 witness.coefficients_for_ACs.begin(),
                                                 witness.coefficients_for_ACs.begin()+this->num_variables());
    ans_H = ans_H + libff::inner_product<FieldT>(this->Ht.begin(),
                                                 this->Ht.begin()+this->degree()+1,
                                                 witness.coefficients_for_H.begin(),
                                                 witness.coefficients_for_H.begin()+this->degree()+1);

    if (ans_A * ans_A - ans_C != ans_H * this->Zt)
    {
        return false;
    }

    return true;
}

template<typename FieldT>
sap_witness<FieldT>::sap_witness(const size_t num_variables,
                                 const size_t degree,
                                 const size_t num_inputs,
                                 const FieldT &d1,
                                 const FieldT &d2,
                                 const std::vector<FieldT> &coefficients_for_ACs,
                                 const std::vector<FieldT> &coefficients_for_H) :
    num_variables_(num_variables),
    degree_(degree),
    num_inputs_(num_inputs),
    d1(d1),
    d2(d2),
    coefficients_for_ACs(coefficients_for_ACs),
    coefficients_for_H(coefficients_for_H)
{
}

template<typename FieldT>
sap_witness<FieldT>::sap_witness(const size_t num_variables,
                                 const size_t degree,
                                 const size_t num_inputs,
                                 const FieldT &d1,
                                 const FieldT &d2,
                                 const std::vector<FieldT> &coefficients_for_ACs,
                                 std::vector<FieldT> &&coefficients_for_H) :
    num_variables_(num_variables),
    degree_(degree),
    num_inputs_(num_inputs),
    d1(d1),
    d2(d2),
    coefficients_for_ACs(coefficients_for_ACs),
    coefficients_for_H(std::move(coefficients_for_H))
{
}


template<typename FieldT>
size_t sap_witness<FieldT>::num_variables() const
{
    return num_variables_;
}

template<typename FieldT>
size_t sap_witness<FieldT>::degree() const
{
    return degree_;
}

template<typename FieldT>
size_t sap_witness<FieldT>::num_inputs() const
{
    return num_inputs_;
}


} // libsnark

#endif // SAP_TCC_
