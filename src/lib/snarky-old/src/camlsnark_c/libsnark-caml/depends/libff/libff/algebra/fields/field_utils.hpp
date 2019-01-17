/** @file
 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef FIELD_UTILS_HPP_
#define FIELD_UTILS_HPP_
#include <cstdint>

#include <libff/algebra/fields/bigint.hpp>
#include <libff/common/double.hpp>
#include <libff/common/utils.hpp>

namespace libff {

// returns root of unity of order n (for n a power of 2), if one exists
template<typename FieldT>
typename std::enable_if<std::is_same<FieldT, Double>::value, FieldT>::type
get_root_of_unity(const size_t n, bool &err);

template<typename FieldT>
typename std::enable_if<!std::is_same<FieldT, Double>::value, FieldT>::type
get_root_of_unity(const size_t n, bool &err);

template<typename FieldT>
std::vector<FieldT> pack_int_vector_into_field_element_vector(const std::vector<size_t> &v, const size_t w);

template<typename FieldT>
std::vector<FieldT> pack_bit_vector_into_field_element_vector(const bit_vector &v, const size_t chunk_bits);

template<typename FieldT>
std::vector<FieldT> pack_bit_vector_into_field_element_vector(const bit_vector &v);

template<typename FieldT>
std::vector<FieldT> convert_bit_vector_to_field_element_vector(const bit_vector &v);

template<typename FieldT>
bit_vector convert_field_element_vector_to_bit_vector(const std::vector<FieldT> &v);

template<typename FieldT>
bit_vector convert_field_element_to_bit_vector(const FieldT &el);

template<typename FieldT>
bit_vector convert_field_element_to_bit_vector(const FieldT &el, const size_t bitcount);

template<typename FieldT>
FieldT convert_bit_vector_to_field_element(const bit_vector &v);

template<typename FieldT>
void batch_invert(std::vector<FieldT> &vec);

} // libff
#include <libff/algebra/fields/field_utils.tcc>

#endif // FIELD_UTILS_HPP_
