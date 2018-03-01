/**
 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#include <memory>
#include <vector>

#include <gtest/gtest.h>
#include <libff/algebra/curves/mnt/mnt4/mnt4_pp.hpp>
#include <stdint.h>

#include <libfqfft/evaluation_domain/domains/arithmetic_sequence_domain.hpp>
#include <libfqfft/evaluation_domain/domains/basic_radix2_domain.hpp>
#include <libfqfft/evaluation_domain/domains/extended_radix2_domain.hpp>
#include <libfqfft/evaluation_domain/domains/geometric_sequence_domain.hpp>
#include <libfqfft/evaluation_domain/domains/step_radix2_domain.hpp>
#include <libfqfft/polynomial_arithmetic/naive_evaluate.hpp>
#include <libfqfft/tools/exceptions.hpp>

namespace libfqfft {

  /**
   * Note: Templatized type referenced with TypeParam (instead of canonical FieldT)
   * https://github.com/google/googletest/blob/master/googletest/docs/AdvancedGuide.md#typed-tests
   */
  template <typename T>
  class EvaluationDomainTest : public ::testing::Test {
    protected:
      virtual void SetUp() {
        libff::mnt4_pp::init_public_params();
      }
  };

  typedef ::testing::Types<libff::Fr<libff::mnt4_pp>, libff::Double> FieldT; /* List Extend Here */
  TYPED_TEST_CASE(EvaluationDomainTest, FieldT);

  TYPED_TEST(EvaluationDomainTest, FFT) {

    const size_t m = 4;
    std::vector<TypeParam> f = { 2, 5, 3, 8 };

    std::shared_ptr<evaluation_domain<TypeParam> > domain;
    for (int key = 0; key < 5; key++)
    {
      try
      {
        if (key == 0) domain.reset(new basic_radix2_domain<TypeParam>(m));
        else if (key == 1) domain.reset(new extended_radix2_domain<TypeParam>(m));
        else if (key == 2) domain.reset(new step_radix2_domain<TypeParam>(m));
        else if (key == 3) domain.reset(new geometric_sequence_domain<TypeParam>(m));
        else if (key == 4) domain.reset(new arithmetic_sequence_domain<TypeParam>(m));

        std::vector<TypeParam> a(f);
        domain->FFT(a);

        std::vector<TypeParam> idx(m);
        for (size_t i = 0; i < m; i++)
        {
          idx[i] = domain->get_domain_element(i);
        }

        for (size_t i = 0; i < m; i++)
        {
          TypeParam e = evaluate_polynomial(m, f, idx[i]);
          EXPECT_TRUE(e == a[i]);
        }
      }
      catch(DomainSizeException &e)
      {
        printf("%s - skipping\n", e.what());
      }
      catch(InvalidSizeException &e)
      {
        printf("%s - skipping\n", e.what());
      }
    }
  }

  TYPED_TEST(EvaluationDomainTest, InverseFFTofFFT) {

    const size_t m = 4;
    std::vector<TypeParam> f = { 2, 5, 3, 8 };

    std::shared_ptr<evaluation_domain<TypeParam> > domain;
    for (int key = 0; key < 5; key++)
    {
      try
      {
        if (key == 0) domain.reset(new basic_radix2_domain<TypeParam>(m));
        else if (key == 1) domain.reset(new extended_radix2_domain<TypeParam>(m));
        else if (key == 2) domain.reset(new step_radix2_domain<TypeParam>(m));
        else if (key == 3) domain.reset(new geometric_sequence_domain<TypeParam>(m));
        else if (key == 4) domain.reset(new arithmetic_sequence_domain<TypeParam>(m));

        std::vector<TypeParam> a(f);
        domain->FFT(a);
        domain->iFFT(a);

        for (size_t i = 0; i < m; i++)
        {
          EXPECT_TRUE(f[i] == a[i]);
        }
      }
      catch(const DomainSizeException &e)
      {
        printf("%s - skipping\n", e.what());
      }
      catch(const InvalidSizeException &e)
      {
        printf("%s - skipping\n", e.what());
      }
    }
  }

  TYPED_TEST(EvaluationDomainTest, InverseCosetFFTofCosetFFT) {

    const size_t m = 4;
    std::vector<TypeParam> f = { 2, 5, 3, 8 };

    TypeParam coset = TypeParam::multiplicative_generator;

    std::shared_ptr<evaluation_domain<TypeParam> > domain;
    for (int key = 0; key < 3; key++)
    {
      try
      {
        if (key == 0) domain.reset(new basic_radix2_domain<TypeParam>(m));
        else if (key == 1) domain.reset(new extended_radix2_domain<TypeParam>(m));
        else if (key == 2) domain.reset(new step_radix2_domain<TypeParam>(m));
        else if (key == 3) domain.reset(new geometric_sequence_domain<TypeParam>(m));
        else if (key == 4) domain.reset(new arithmetic_sequence_domain<TypeParam>(m));

        std::vector<TypeParam> a(f);
        domain->cosetFFT(a, coset);
        domain->icosetFFT(a, coset);

        for (size_t i = 0; i < m; i++)
        {
          EXPECT_TRUE(f[i] == a[i]);
        }
      }
      catch(const DomainSizeException &e)
      {
        printf("%s - skipping\n", e.what());
      }
      catch(const InvalidSizeException &e)
      {
        printf("%s - skipping\n", e.what());
      }
    }
  }

  TYPED_TEST(EvaluationDomainTest, LagrangeCoefficients) {

    const size_t m = 8;
    TypeParam t = TypeParam(10);

    std::shared_ptr<evaluation_domain<TypeParam> > domain;
    for (int key = 0; key < 5; key++)
    {

      try
      {
        if (key == 0) domain.reset(new basic_radix2_domain<TypeParam>(m));
        else if (key == 1) domain.reset(new extended_radix2_domain<TypeParam>(m));
        else if (key == 2) domain.reset(new step_radix2_domain<TypeParam>(m));
        else if (key == 3) domain.reset(new geometric_sequence_domain<TypeParam>(m));
        else if (key == 4) domain.reset(new arithmetic_sequence_domain<TypeParam>(m));

        std::vector<TypeParam> a;
        a = domain->evaluate_all_lagrange_polynomials(t);

        std::vector<TypeParam> d(m);
        for (size_t i = 0; i < m; i++)
        {
          d[i] = domain->get_domain_element(i);
        }

        for (size_t i = 0; i < m; i++)
        {
          TypeParam e = evaluate_lagrange_polynomial(m, d, t, i);
          printf("%ld == %ld\n", e.as_ulong(), a[i].as_ulong());
          EXPECT_TRUE(e == a[i]);
        }
      }
      catch(const DomainSizeException &e)
      {
        printf("%s - skipping\n", e.what());
      }
      catch(const InvalidSizeException &e)
      {
        printf("%s - skipping\n", e.what());
      }
    }
  }

  TYPED_TEST(EvaluationDomainTest, ComputeZ) {

    const size_t m = 8;
    TypeParam t = TypeParam(10);

    std::shared_ptr<evaluation_domain<TypeParam> > domain;
    for (int key = 0; key < 5; key++)
    {
      try
      {
        if (key == 0) domain.reset(new basic_radix2_domain<TypeParam>(m));
        else if (key == 1) domain.reset(new extended_radix2_domain<TypeParam>(m));
        else if (key == 2) domain.reset(new step_radix2_domain<TypeParam>(m));
        else if (key == 3) domain.reset(new geometric_sequence_domain<TypeParam>(m));
        else if (key == 4) domain.reset(new arithmetic_sequence_domain<TypeParam>(m));

        TypeParam a;
        a = domain->compute_vanishing_polynomial(t);

        TypeParam Z = TypeParam::one();
        for (size_t i = 0; i < m; i++)
        {
          Z *= (t - domain->get_domain_element(i));
        }

        EXPECT_TRUE(Z == a);
      }
      catch(const DomainSizeException &e)
      {
        printf("%s - skipping\n", e.what());
      }
      catch(const InvalidSizeException &e)
      {
        printf("%s - skipping\n", e.what());
      }
    }
  }

} // libfqfft
