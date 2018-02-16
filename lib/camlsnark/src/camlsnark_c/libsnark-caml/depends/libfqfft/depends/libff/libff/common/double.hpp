/** @file
 *****************************************************************************

 Declaration of complex domain data type.

 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef DOUBLE_HPP_
#define DOUBLE_HPP_

#include <complex>

#include <libff/algebra/fields/bigint.hpp>

namespace libff {

  class Double 
  {
    public:
      std::complex<double> val;

      Double();

      Double(double real);

      Double(double real, double imag);

      Double(std::complex<double> num);

      static unsigned add_cnt;
      static unsigned sub_cnt;
      static unsigned mul_cnt;
      static unsigned inv_cnt;

      Double operator+(const Double &other) const;
      Double operator-(const Double &other) const;
      Double operator*(const Double &other) const;
      Double operator-() const;

      Double& operator+=(const Double &other);
      Double& operator-=(const Double &other);
      Double& operator*=(const Double &other);

      bool operator==(const Double &other) const;
      bool operator!=(const Double &other) const;

      bool operator<(const Double &other) const;
      bool operator>(const Double &other) const;

      Double operator^(const libff::bigint<1> power) const;
      Double operator^(const size_t power) const;

      libff::bigint<1> as_bigint() const;
      unsigned long as_ulong() const;
      Double inverse() const;
      Double squared() const;

      static Double one();
      static Double zero();
      static Double random_element();
      static Double geometric_generator();
      static Double arithmetic_generator();

      static Double multiplicative_generator;
      static Double root_of_unity; // See get_root_of_unity() in field_utils
      static size_t s;
  };
} // libff

#endif // DOUBLE_HPP_
