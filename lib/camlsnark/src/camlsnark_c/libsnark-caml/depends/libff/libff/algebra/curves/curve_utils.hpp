/** @file
 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef CURVE_UTILS_HPP_
#define CURVE_UTILS_HPP_
#include <cstdint>

#include <libff/algebra/fields/bigint.hpp>

namespace libff {

template<typename GroupT, mp_size_t m>
GroupT scalar_mul(const GroupT &base, const bigint<m> &scalar);

} // libff
#include <libff/algebra/curves/curve_utils.tcc>

#endif // CURVE_UTILS_HPP_
