/** @file
 *****************************************************************************

 Declaration of interfaces for (square-and-multiply) exponentiation.

 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef EXPONENTIATION_HPP_
#define EXPONENTIATION_HPP_

#include <cstdint>

#include <libff/algebra/fields/bigint.hpp>

namespace libff {

template<typename FieldT, mp_size_t m>
FieldT power(const FieldT &base, const bigint<m> &exponent);

template<typename FieldT>
FieldT power(const FieldT &base, const unsigned long exponent);

} // libff

#include <libff/algebra/exponentiation/exponentiation.tcc>

#endif // EXPONENTIATION_HPP_
