/** @file
 *****************************************************************************

 Implementation of complex domain data type.

 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#include <cmath>
#include <complex>

#include <math.h>

#include <libff/algebra/fields/bigint.hpp>
#include <libff/common/double.hpp>

namespace libff {

  const double PI = 3.141592653589793238460264338328L;

  Double::Double()
  {
    val = std::complex<double>(0, 0);
  }

  Double::Double(double real)
  {
    val = std::complex<double>(real, 0);
  }

  Double::Double(double real, double imag)
  {
    val = std::complex<double>(real, imag);
  }

  Double::Double(std::complex<double> num)
  {
    val = num;
  }

  unsigned Double::add_cnt = 0;
  unsigned Double::sub_cnt = 0;
  unsigned Double::mul_cnt = 0;
  unsigned Double::inv_cnt = 0;

  Double Double::operator+(const Double &other) const
  {
#ifdef PROFILE_OP_COUNTS
    ++add_cnt;
#endif

    return Double(val + other.val);
  }

  Double Double::operator-(const Double &other) const
  {
#ifdef PROFILE_OP_COUNTS
    ++sub_cnt;
#endif

    return Double(val - other.val);
  }

  Double Double::operator*(const Double &other) const
  {
#ifdef PROFILE_OP_COUNTS
    ++mul_cnt;
#endif

    return Double(val * other.val);
  }

  Double Double::operator-() const
  {
    if (val.imag() == 0) return Double(-val.real());

    return Double(-val.real(), -val.imag());
  }

  Double& Double::operator+=(const Double &other)
  {
#ifdef PROFILE_OP_COUNTS
    ++add_cnt;
#endif

    this->val = std::complex<double>(val + other.val);
    return *this;
  }

  Double& Double::operator-=(const Double &other)
  {
#ifdef PROFILE_OP_COUNTS
    ++sub_cnt;
#endif

    this->val = std::complex<double>(val - other.val);
    return *this;
  }

  Double& Double::operator*=(const Double &other)
  {
#ifdef PROFILE_OP_COUNTS
    ++mul_cnt;
#endif

    this->val *= std::complex<double>(other.val);
    return *this;
  }

  bool Double::operator==(const Double &other) const
  {
    return (std::abs(val.real() - other.val.real()) < 0.000001)
        && (std::abs(val.imag() - other.val.imag()) < 0.000001);
  }

  bool Double::operator!=(const Double &other) const
  {
    return Double(val) == other ? 0 : 1;
  }

  bool Double::operator<(const Double &other) const
  {
    return (val.real() < other.val.real());
  }

  bool Double::operator>(const Double &other) const
  {
    return (val.real() > other.val.real());
  }

  Double Double::operator^(const libff::bigint<1> power) const
  {
    return Double(pow(val, power.as_ulong()));
  }

  Double Double::operator^(const size_t power) const
  {
    return Double(pow(val, power));
  }

  Double Double::inverse() const
  {
#ifdef PROFILE_OP_COUNTS
    ++inv_cnt;
#endif

    return Double(std::complex<double>(1) / val);
  }

  libff::bigint<1> Double::as_bigint() const
  {
    return libff::bigint<1>(val.real());
  }

  unsigned long Double::as_ulong() const
  {
    return round(val.real());
  }

  Double Double::squared() const
  {
    return Double(val * val);
  }

  Double Double::one()
  {
    return Double(1);
  }

  Double Double::zero()
  {
    return Double(0);
  }

  Double Double::random_element()
  {
    return Double(std::rand() % 1001);
  }

  Double Double::geometric_generator()
  {
    return Double(2);
  }

  Double Double::arithmetic_generator()
  {
    return Double(1);
  }

  Double Double::multiplicative_generator = Double(2);

} // libff
