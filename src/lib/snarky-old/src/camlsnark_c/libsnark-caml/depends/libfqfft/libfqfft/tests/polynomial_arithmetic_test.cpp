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
#include <libfqfft/polynomial_arithmetic/xgcd.hpp>

namespace libfqfft {

  template <typename T>
  class PolynomialArithmeticTest : public ::testing::Test {};
  typedef ::testing::Types<libff::Double> FieldT; /* List Extend Here */
  TYPED_TEST_CASE(PolynomialArithmeticTest, FieldT);

  TYPED_TEST(PolynomialArithmeticTest, PolynomialAdditionSame) {

    std::vector<TypeParam> a = { 1, 3, 4, 25, 6, 7, 7, 2 };
    std::vector<TypeParam> b = { 9, 3, 11, 14, 7, 1, 5, 8 };
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_addition(c, a, b);

    std::vector<TypeParam> c_ans = { 10, 6, 15, 39, 13, 8, 12, 10 };

    for (size_t i = 0; i < c.size(); i++)
    {
      EXPECT_TRUE(c_ans[i] == c[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, PolynomialAdditionBiggerA) {

    std::vector<TypeParam> a = { 1, 3, 4, 25, 6, 7, 7, 2 };
    std::vector<TypeParam> b = { 9, 3, 11, 14, 7 };
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_addition(c, a, b);

    std::vector<TypeParam> c_ans = { 10, 6, 15, 39, 13, 7, 7, 2 };

    for (size_t i = 0; i < c.size(); i++)
    {
      EXPECT_TRUE(c_ans[i] == c[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, PolynomialAdditionBiggerB) {

    std::vector<TypeParam> a = { 1, 3, 4, 25, 6 };
    std::vector<TypeParam> b = { 9, 3, 11, 14, 7, 1, 5, 8 };
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_addition(c, a, b);

    std::vector<TypeParam> c_ans = { 10, 6, 15, 39, 13, 1, 5, 8 };

    for (size_t i = 0; i < c.size(); i++)
    {
      EXPECT_TRUE(c_ans[i] == c[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, PolynomialAdditionZeroA) {

    std::vector<TypeParam> a = { 0, 0, 0 };
    std::vector<TypeParam> b = { 1, 3, 4, 25, 6, 7, 7, 2 };
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_addition(c, a, b);

    std::vector<TypeParam> c_ans = { 1, 3, 4, 25, 6, 7, 7, 2 };

    for (size_t i = 0; i < c.size(); i++)
    {
      EXPECT_TRUE(c_ans[i] == c[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, PolynomialAdditionZeroB) {

    std::vector<TypeParam> a = { 1, 3, 4, 25, 6, 7, 7, 2 };
    std::vector<TypeParam> b = { 0, 0, 0 };
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_addition(c, a, b);

    std::vector<TypeParam> c_ans = { 1, 3, 4, 25, 6, 7, 7, 2 };

    for (size_t i = 0; i < c.size(); i++)
    {
      EXPECT_TRUE(c_ans[i] == c[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, PolynomialSubtractionSame) {

    std::vector<TypeParam> a = { 1, 3, 4, 25, 6, 7, 7, 2 };
    std::vector<TypeParam> b = { 9, 3, 11, 14, 7, 1, 5, 8 };
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_subtraction(c, a, b);

    std::vector<TypeParam> c_ans = { -8, 0, -7, 11, -1, 6, 2, -6 };

    for (size_t i = 0; i < c.size(); i++)
    {
      EXPECT_TRUE(c_ans[i] == c[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, PolynomialSubtractionBiggerA) {

    std::vector<TypeParam> a = { 1, 3, 4, 25, 6, 7, 7, 2 };
    std::vector<TypeParam> b = { 9, 3, 11, 14, 7 };
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_subtraction(c, a, b);

    std::vector<TypeParam> c_ans = { -8, 0, -7, 11, -1, 7, 7, 2 };

    for (size_t i = 0; i < c.size(); i++)
    {
      EXPECT_TRUE(c_ans[i] == c[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, PolynomialSubtractionBiggerB) {

    std::vector<TypeParam> a = { 1, 3, 4, 25, 6 };
    std::vector<TypeParam> b = { 9, 3, 11, 14, 7, 1, 5, 8 };
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_subtraction(c, a, b);

    std::vector<TypeParam> c_ans = { -8, 0, -7, 11, -1, -1, -5, -8 };

    for (size_t i = 0; i < c.size(); i++)
    {
      EXPECT_TRUE(c_ans[i] == c[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, PolynomialSubtractionZeroA) {

    std::vector<TypeParam> a = { 0, 0, 0 };
    std::vector<TypeParam> b = { 1, 3, 4, 25, 6, 7, 7, 2 };
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_subtraction(c, a, b);

    std::vector<TypeParam> c_ans = { -1, -3, -4, -25, -6, -7, -7, -2 };

    for (size_t i = 0; i < c.size(); i++)
    {
      EXPECT_TRUE(c_ans[i] == c[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, PolynomialSubtractionZeroB) {

    std::vector<TypeParam> a = { 1, 3, 4, 25, 6, 7, 7, 2 };
    std::vector<TypeParam> b = { 0, 0, 0 };
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_subtraction(c, a, b);

    std::vector<TypeParam> c_ans = { 1, 3, 4, 25, 6, 7, 7, 2 };

    for (size_t i = 0; i < c.size(); i++)
    {
      EXPECT_TRUE(c_ans[i] == c[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, PolynomialMultiplicationBasic) {

    std::vector<TypeParam> a = { 5, 0, 0, 13, 0, 1 };
    std::vector<TypeParam> b = { 13, 0, 1 };
    std::vector<TypeParam> c(1, TypeParam::zero());
    
    _polynomial_multiplication(c, a, b);

    std::vector<TypeParam> c_ans = { 65, 0, 5, 169, 0, 26, 0, 1 };

    for (size_t i = 0; i < c.size(); i++)
    {
      EXPECT_TRUE(c_ans[i] == c[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, PolynomialMultiplicationZero) {

    std::vector<TypeParam> a = { 5, 0, 0, 13, 0, 1 };
    std::vector<TypeParam> b = { 0 };
    std::vector<TypeParam> c(1, TypeParam::zero());

    _polynomial_multiplication(c, a, b);

    std::vector<TypeParam> c_ans = { 0 };

    for (size_t i = 0; i < c.size(); i++)
    {
      EXPECT_TRUE(c_ans[i] == c[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, PolynomialDivision) {

    std::vector<TypeParam> a = { 5, 0, 0, 13, 0, 1 };
    std::vector<TypeParam> b = { 13, 0, 1 };

    std::vector<TypeParam> Q(1, TypeParam::zero());
    std::vector<TypeParam> R(1, TypeParam::zero());

    _polynomial_division(Q, R, a, b);

    std::vector<TypeParam> Q_ans = { 0, 0, 0, 1 };
    std::vector<TypeParam> R_ans = { 5 };

    for (size_t i = 0; i < Q.size(); i++)
    {
      EXPECT_TRUE(Q_ans[i] == Q[i]);
    }
    for (size_t i = 0; i < R.size(); i++)
    {
      EXPECT_TRUE(R_ans[i] == R[i]);
    }
  }

  TYPED_TEST(PolynomialArithmeticTest, ExtendedGCD) {

    std::vector<TypeParam> a = { 0, 0, 0, 0, 1 };
    std::vector<TypeParam> b = { 1, -6, 11, -6 };

    std::vector<TypeParam> pg(1, TypeParam::zero());
    std::vector<TypeParam> pu(1, TypeParam::zero());
    std::vector<TypeParam> pv(1, TypeParam::zero());

    _polynomial_xgcd(a, b, pg, pu, pv);

    std::vector<TypeParam> pv_ans = { 1, 6, 25, 90 };

    for (size_t i = 0; i < pv.size(); i++)
    {
      EXPECT_TRUE(pv_ans[i] == pv[i]);
    }
  }

} // libfqfft
