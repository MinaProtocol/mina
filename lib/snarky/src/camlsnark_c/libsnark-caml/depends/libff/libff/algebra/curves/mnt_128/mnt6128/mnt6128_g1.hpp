/** @file
 *****************************************************************************

 Declaration of interfaces for the MNT6 G1 group.

 *****************************************************************************
 * @author     This file is part of libff, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef MNT6128_G1_HPP_
#define MNT6128_G1_HPP_

#include <vector>

#include <libff/algebra/curves/curve_utils.hpp>
#include <libff/algebra/curves/mnt_128/mnt6128/mnt6128_init.hpp>

namespace libff {

class mnt6128_G1;
std::ostream& operator<<(std::ostream &, const mnt6128_G1&);
std::istream& operator>>(std::istream &, mnt6128_G1&);

class mnt6128_G1 {
private:
    mnt6128_Fq X_, Y_, Z_;
public:
#ifdef PROFILE_OP_COUNTS
    static long long add_cnt;
    static long long dbl_cnt;
#endif
    static std::vector<size_t> wnaf_window_table;
    static std::vector<size_t> fixed_base_exp_window_table;
    static mnt6128_G1 G1_zero;
    static mnt6128_G1 G1_one;
    static mnt6128_Fq coeff_a;
    static mnt6128_Fq coeff_b;

    typedef mnt6128_Fq base_field;
    typedef mnt6128_Fr scalar_field;

    // using projective coordinates
    mnt6128_G1();
    mnt6128_G1(const mnt6128_Fq& X, const mnt6128_Fq& Y) : X_(X), Y_(Y), Z_(base_field::one()) {}
    mnt6128_G1(const mnt6128_Fq& X, const mnt6128_Fq& Y, const mnt6128_Fq& Z) : X_(X), Y_(Y), Z_(Z) {}

    mnt6128_Fq X() const { return X_; }
    mnt6128_Fq Y() const { return Y_; }
    mnt6128_Fq Z() const { return Z_; }

    void print() const;
    void print_coordinates() const;

    void to_affine_coordinates();
    void to_special();
    bool is_special() const;

    bool is_zero() const;

    bool operator==(const mnt6128_G1 &other) const;
    bool operator!=(const mnt6128_G1 &other) const;

    mnt6128_G1 operator+(const mnt6128_G1 &other) const;
    mnt6128_G1 operator-() const;
    mnt6128_G1 operator-(const mnt6128_G1 &other) const;

    mnt6128_G1 add(const mnt6128_G1 &other) const;
    mnt6128_G1 mixed_add(const mnt6128_G1 &other) const;
    mnt6128_G1 dbl() const;

    bool is_well_formed() const;

    static mnt6128_G1 zero();
    static mnt6128_G1 one();
    static mnt6128_G1 random_element();

    static size_t size_in_bits() { return base_field::size_in_bits() + 1; }
    static bigint<base_field::num_limbs> base_field_char() { return base_field::field_char(); }
    static bigint<scalar_field::num_limbs> order() { return scalar_field::field_char(); }

    friend std::ostream& operator<<(std::ostream &out, const mnt6128_G1 &g);
    friend std::istream& operator>>(std::istream &in, mnt6128_G1 &g);

    static void batch_to_special_all_non_zeros(std::vector<mnt6128_G1> &vec);
};

template<mp_size_t m>
mnt6128_G1 operator*(const bigint<m> &lhs, const mnt6128_G1 &rhs)
{
    return scalar_mul<mnt6128_G1, m>(rhs, lhs);
}

template<mp_size_t m, const bigint<m>& modulus_p>
mnt6128_G1 operator*(const Fp_model<m,modulus_p> &lhs, const mnt6128_G1 &rhs)
{
    return scalar_mul<mnt6128_G1, m>(rhs, lhs.as_bigint());
}

std::ostream& operator<<(std::ostream& out, const std::vector<mnt6128_G1> &v);
std::istream& operator>>(std::istream& in, std::vector<mnt6128_G1> &v);

} // libff

#endif // MNT6128_G1_HPP_
