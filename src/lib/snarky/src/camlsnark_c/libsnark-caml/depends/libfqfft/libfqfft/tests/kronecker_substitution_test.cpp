/**
 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/
 
#include <vector>

#include <gtest/gtest.h>
#include <stdint.h>

#include <libfqfft/polynomial_arithmetic/basic_operations.hpp>

namespace libfqfft {

  template <typename T>
  class KroneckerSubstitutionTest : public ::testing::Test {};
  typedef ::testing::Types<libff::Double> FieldT; /* List Extend Here */
  TYPED_TEST_CASE(KroneckerSubstitutionTest, FieldT);

  TYPED_TEST(KroneckerSubstitutionTest, StandardPolynomialMultiplication) {

    std::vector<TypeParam> a = { 1, 2, 3, 1 };
    std::vector<TypeParam> b = { 1, 2, 1, 1 };
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_multiplication_on_kronecker(c, a, b);

    std::vector<TypeParam> c_answer(1, TypeParam::zero());
    _polynomial_multiplication(c_answer, a, b);

    for (size_t i = 0; i < c_answer.size(); i++)
    {
      EXPECT_TRUE(c_answer[i] == c[i]);
    }
  }

  TYPED_TEST(KroneckerSubstitutionTest, SquaredPolynomialMultiplication) {
    
    std::vector<TypeParam> a = { 1, 2, 3, 1 };
    std::vector<TypeParam> b = a;
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_multiplication_on_kronecker(c, a, b);
    
    std::vector<TypeParam> c_answer(1, TypeParam::zero());
    _polynomial_multiplication(c_answer, a, b);

    for (size_t i = 0; i < c_answer.size(); i++)
    {
      EXPECT_TRUE(c_answer[i] == c[i]);
    }
  }

} // libfqfft
