#pragma once
/**
	@file
	@brief BN parameter
	@author herumi and t_teruya
	@note modified new BSD license
	http://opensource.org/licenses/BSD-3-Clause
*/
#include <stdexcept>
#include <vector>

#include "zm2.h"

//#define BN_SUPPORT_SNARK

#ifdef MIE_ATE_USE_GMP
#include <gmpxx.h>

namespace mie {

inline size_t M_bitLen(const mpz_class& x)
{
	return mpz_sizeinbase(x.get_mpz_t(), 2);
}
inline size_t M_blockSize(const mpz_class& x)
{
	return x.get_mpz_t()->_mp_size;
}
inline mp_limb_t M_block(const mpz_class& x, size_t i)
{
	return x.get_mpz_t()->_mp_d[i];
}
inline uint32_t M_low32bit(const mpz_class& x)
{
	return (uint32_t)M_block(x, 0);
}

namespace util {
template<>
struct IntTag<mpz_class> {
	typedef mp_limb_t value_type;
	static inline value_type getBlock(const mpz_class& x, size_t i)
	{
		return M_block(x, i);
	}
	static inline size_t getBlockSize(const mpz_class& x)
	{
		return M_blockSize(x);
	}
};
} } // mie::util
#endif

extern uint64_t debug_buf[128]; // for debug

namespace bn {

struct CurveParam {
	/*
		y^2 = x^3 + b
		u^2 = -1
		xi = xi_a + xi_b u
		v^3 = xi
		w^2 = v
	*/
	int64_t z;
	int b; // Y^2 + X^3 + b
	int xi_a;
	int xi_b; // xi = xi_a + xi_b u
	bool operator==(const CurveParam& rhs) const { return z == rhs.z && b == rhs.b && xi_a == rhs.xi_a && xi_b == rhs.xi_b; }
	bool operator!=(const CurveParam& rhs) const { return !operator==(rhs); }
};

/*
	the current version supports only the following parameters
*/
#ifdef BN_SUPPORT_SNARK
const CurveParam CurveSNARK1 = { 4965661367192848881, 3, 9, 1 };

// b/xi = 82 / (9 + u) = 9 - u
const CurveParam CurveSNARK2 = { 4965661367192848881, 82, 9, 1 };
#else
// b/xi = 2 / (1 - u) = 1 + u
const CurveParam CurveFp254BNb = { -((1LL << 62) + (1LL << 55) + (1LL << 0)), 2, 1, 1 };
#endif

namespace util {

template<class T>
void put(const T& x, size_t len)
{
	for (size_t i = 0; i < len; i++) {
		printf("% 2d,", x[i]);
	}
	printf("\n");
}
template<class T>
void put(const T& x)
{
	put(x, x.size());
}
template<class Vec>
void convertToBinary(Vec& v, const mie::Vuint& x)
{
	const size_t len = x.bitLen();
	v.clear();
	for (size_t i = 0; i < len; i++) {
		v.push_back(x.testBit(len - 1 - i) ? 1 : 0);
	}
}
template<class Vec>
size_t getContinuousVal(const Vec& v, size_t pos, int val)
{
	while (pos >= 2) {
		if (v[pos] != val) break;
		pos--;
	}
	return pos;
}
template<class Vec>
void convertToNAF(Vec& v, const Vec& in)
{
	v = in;
	size_t pos = v.size() - 1;
	for (;;) {
		size_t p = getContinuousVal(v, pos, 0);
		if (p == 1) return;
		assert(v[p] == 1);
		size_t q = getContinuousVal(v, p, 1);
		if (q == 1) return;
		assert(v[q] == 0);
		if (p - q <= 1) {
			pos = p - 1;
			continue;
		}
		v[q] = 1;
		for (size_t i = q + 1; i < p; i++) {
			v[i] = 0;
		}
		v[p] = -1;
		pos = q;
	}
}
template<class Vec>
size_t getNumOfNonZeroElement(const Vec& v)
{
	size_t w = 0;
	for (size_t i = 0; i < v.size(); i++) {
		if (v[i]) w++;
	}
	return w;
}

/*
	compute a repl of x which has smaller Hamming weights.
	return true if naf is selected
*/
template<class Vec>
bool getGoodRepl(Vec& v, const mie::Vuint& x)
{
	Vec bin;
	util::convertToBinary(bin, x);
	Vec naf;
	util::convertToNAF(naf, bin);
	const size_t binW = util::getNumOfNonZeroElement(bin);
	const size_t nafW = util::getNumOfNonZeroElement(naf);
	if (nafW < binW) {
		v.swap(naf);
		return true;
	} else {
		v.swap(bin);
		return false;
	}
}

} // bn::util

template<class Fp2>
struct ParamT {
	typedef typename Fp2::Fp Fp;
	static mie::Vsint z;
	static mie::Vuint p;
	static mie::Vuint r;
	static mie::Vuint t; /* trace of Frobenius */
	static mie::Vsint largest_c; /* 6z + 2, the largest coefficient of short vector */
	static Fp Z;
	static Fp2 W2p;
	static Fp2 W3p;
	static Fp2 gammar[5];
	static Fp2 gammar2[5];
	static Fp2 gammar3[5];
	static Fp i0; // 0
	static Fp i1; // 1
	static int b;
	static Fp2 b_invxi; // b/xi of twist E' : Y^2 = X^3 + b/xi
	static Fp half;

	// Loop parameter for the Miller loop part of opt. ate pairing.
	typedef std::vector<signed char> SignVec;
	static SignVec siTbl;
	static bool useNAF;
#ifdef BN_SUPPORT_SNARK
	static SignVec zReplTbl;
#endif

	static inline void init(const CurveParam& cp, int mode = -1, bool useMulx = true)
	{
#ifdef BN_SUPPORT_SNARK
		bool supported = cp == CurveSNARK1 || cp == CurveSNARK2;
#else
		bool supported = cp == CurveFp254BNb;
#endif
		if (!supported) {
			fprintf(stderr, "not supported parameter\n");
			exit(1);
		}
		mie::zmInit();
		const int64_t org_z = cp.z; // NOTE: hard-coded Fp12::pow_neg_t too.
		const int pCoff[] = { 1, 6, 24, 36, 36 };
		const int rCoff[] = { 1, 6, 18, 36, 36 };
		const int tCoff[] = { 1, 0,  6,  0,  0 };
		z.set(org_z);
		eval(p, z, pCoff);
		eval(r, z, rCoff);
		eval(t, z, tCoff);
		largest_c = 6 * z + 2;
		b = cp.b; // set b before calling Fp::setModulo
		Fp::setModulo(p, mode, useMulx);
		half = Fp(1) / Fp(2);
		/*
			b_invxi = b / xi
		*/
		Fp2 xi(cp.xi_a, cp.xi_b);
		b_invxi = xi;
		b_invxi.inverse();
		b_invxi *= Fp2(b, 0);
		gammar[0] = mie::power(xi, (p - 1) / 6);

		for (size_t i = 1; i < sizeof(gammar) / sizeof(*gammar); ++i) {
			gammar[i] = gammar[i - 1] * gammar[0];
		}

		for (size_t i = 0; i < sizeof(gammar2) / sizeof(*gammar2); ++i) {
			gammar2[i] = Fp2(gammar[i].a_, -gammar[i].b_) * gammar[i];
		}

		for (size_t i = 0; i < sizeof(gammar2) / sizeof(*gammar2); ++i) {
			gammar3[i] = gammar[i] * gammar2[i];
		}

		W2p = mie::power(xi, (p - 1) / 3);
		W3p = mie::power(xi, (p - 1) / 2);
		Fp2 temp = mie::power(xi, (p * p - 1) / 6);
		assert(temp.b_.isZero());
		Fp::square(Z, -temp.a_);
		i0 = 0;
		i1 = 1;

		useNAF = util::getGoodRepl(siTbl, largest_c.abs());
#ifdef BN_SUPPORT_SNARK
		util::getGoodRepl(zReplTbl, z.abs());
#endif
	}
	static inline void init(int mode = -1, bool useMulx = true)
	{
#ifdef BN_SUPPORT_SNARK
		init(CurveSNARK1, mode, useMulx);
#else
		init(CurveFp254BNb, mode, useMulx);
#endif
	}

	// y = sum_{i=0}^4 c_i x^i
	// @todo Support signed integer substitution.
	template<class T, class U>
	static void eval(T& y, const U& x, const int* c) {
		U tmp = (((c[4] * x + c[3]) * x + c[2]) * x + c[1]) * x + c[0];
		y = tmp.get();
	}
};

template<class Fp2>
mie::Vsint ParamT<Fp2>::z;
template<class Fp2>
mie::Vuint ParamT<Fp2>::p;
template<class Fp2>
mie::Vuint ParamT<Fp2>::r;
template<class Fp2>
mie::Vuint ParamT<Fp2>::t;
template<class Fp2>
mie::Vsint ParamT<Fp2>::largest_c;

template<class Fp2>
typename Fp2::Fp ParamT<Fp2>::Z;
template<class Fp2>
typename Fp2::Fp ParamT<Fp2>::i0;
template<class Fp2>
typename Fp2::Fp ParamT<Fp2>::i1;
template<class Fp2>
int ParamT<Fp2>::b;
template<class Fp2>
Fp2 ParamT<Fp2>::b_invxi;

template<class Fp2>
typename Fp2::Fp ParamT<Fp2>::half;

template<class Fp2>
Fp2 ParamT<Fp2>::W2p;
template<class Fp2>
Fp2 ParamT<Fp2>::W3p;

template<class Fp2>
Fp2 ParamT<Fp2>::gammar[5];
template<class Fp2>
Fp2 ParamT<Fp2>::gammar2[5];
template<class Fp2>
Fp2 ParamT<Fp2>::gammar3[5];

template<class Fp2>
typename ParamT<Fp2>::SignVec ParamT<Fp2>::siTbl;
template<class Fp2>
bool ParamT<Fp2>::useNAF;

#ifdef BN_SUPPORT_SNARK
template<class Fp2>
typename ParamT<Fp2>::SignVec ParamT<Fp2>::zReplTbl;
#endif

/*
	mul_gamma(z, x) + z += y;
*/
template<class F, class G>
void mul_gamma_add(F& z, const F& x, const F& y)
{
	G::mul_xi(z.a_, x.c_);
	z.a_ += y.a_;
	G::add(z.b_, x.a_, y.b_);
	G::add(z.c_, x.b_, y.c_);
}

/*
	beta = -1
	Fp2 = F[u] / (u^2 + 1)
	x = a_ + b_ u
*/
template<class T>
struct Fp2T : public mie::local::addsubmul<Fp2T<T>
		, mie::local::hasNegative<Fp2T<T> > > {
	typedef T Fp;
	Fp a_, b_;
	Fp2T() { }
	Fp2T(int x)
		: a_(x)
		, b_(0)
	{
	}
	Fp2T(const Fp& a, const Fp& b)
		: a_(a)
		, b_(b)
	{
	}
	Fp* get() { return &a_; }
	const Fp* get() const { return &a_; }
	bool isZero() const
	{
		return a_.isZero() && b_.isZero();
	}
	static void (*add)(Fp2T& z, const Fp2T& x, const Fp2T& y);
	static void (*addNC)(Fp2T& z, const Fp2T& x, const Fp2T& y);
	static void (*sub)(Fp2T& z, const Fp2T& x, const Fp2T& y);
	static void (*subNC)(Fp2T& z, const Fp2T& x, const Fp2T& y);
	static void (*mul)(Fp2T& z, const Fp2T& x, const Fp2T& y);
	static void (*square)(Fp2T& z, const Fp2T& x);
	static void (*mul_xi)(Fp2T& z, const Fp2T& x);
	static void (*mul_Fp_0)(Fp2T& z, const Fp2T& x, const Fp& b);
	static void (*divBy2)(Fp2T& z, const Fp2T& x);

	static inline void addC(Fp2T& z, const Fp2T& x, const Fp2T& y)
	{
		Fp::add(z.a_, x.a_, y.a_);
		Fp::add(z.b_, x.b_, y.b_);
	}
	static inline void addNC_C(Fp2T& z, const Fp2T& x, const Fp2T& y)
	{
		Fp::addNC(z.a_, x.a_, y.a_);
		Fp::addNC(z.b_, x.b_, y.b_);
	}

	static inline void subNC_C(Fp2T& z, const Fp2T& x, const Fp2T& y)
	{
		Fp::subNC(z.a_, x.a_, y.a_);
		Fp::subNC(z.b_, x.b_, y.b_);
	}

	static inline void subC(Fp2T& z, const Fp2T& x, const Fp2T& y)
	{
		Fp::sub(z.a_, x.a_, y.a_);
		Fp::sub(z.b_, x.b_, y.b_);
	}
	static inline void neg(Fp2T& z, const Fp2T& x)
	{
		Fp::neg(z.a_, x.a_);
		Fp::neg(z.b_, x.b_);
	}

	/*
		(a + b u)(c + d u) = (a c - b d) + (a d + b c)u
		 = (a c - b d) + ((a + b)(c + d) - a c - b d)u
		N = 1 << 256
		7p < N then 7(p-1)(p-1) < pN
	*/
	static inline void mulC(Fp2T& z, const Fp2T& x, const Fp2T& y)
	{
		typename Fp::Dbl d[3];
		Fp s, t;
		Fp::addNC(s, x.a_, x.b_); // a + b
		Fp::addNC(t, y.a_, y.b_); // c + d
		Fp::Dbl::mul(d[0], s, t); // (a + b)(c + d)
		Fp::Dbl::mul(d[1], x.a_, y.a_); // ac
		Fp::Dbl::mul(d[2], x.b_, y.b_); // bd
		Fp::Dbl::subNC(d[0], d[0], d[1]); // (a + b)(c + d) - ac
		Fp::Dbl::subNC(d[0], d[0], d[2]); // (a + b)(c + d) - ac - bd
		Fp::Dbl::mod(z.b_, d[0]); // set z[1]
		Fp::Dbl::sub(d[1], d[1], d[2]); // ac - bd
		Fp::Dbl::mod(z.a_, d[1]); // set z[0]
	}

	static inline void divBy2C(Fp2T& z, const Fp2T& x)
	{
		Fp::divBy2(z.a_, x.a_);
		Fp::divBy2(z.b_, x.b_);
	}

	static inline void divBy4(Fp2T& z, const Fp2T& x)
	{
		Fp::divBy4(z.a_, x.a_);
		Fp::divBy4(z.b_, x.b_);
	}

#ifdef BN_SUPPORT_SNARK
	/*
		XITAG
		u^2 = -1
		xi = 9 + u
		(a + bu)(9 + u) = (9a - b) + (a + 9b)u
	*/
	static inline void mul_xiC(Fp2T& z, const Fp2T& x)
	{
		assert(&z != &x);
		Fp::add(z.a_, x.a_, x.a_); // 2
		Fp::add(z.a_, z.a_, z.a_); // 4
		Fp::add(z.a_, z.a_, z.a_); // 8
		Fp::add(z.a_, z.a_, x.a_); // 9
		Fp::sub(z.a_, z.a_, x.b_);

		Fp::add(z.b_, x.b_, x.b_); // 2
		Fp::add(z.b_, z.b_, z.b_); // 4
		Fp::add(z.b_, z.b_, z.b_); // 8
		Fp::add(z.b_, z.b_, x.b_); // 9
		Fp::add(z.b_, z.b_, x.a_);
	}
#else
	/*
		u^2 = -1
		xi = 1 + u
		(a + bu)(1 + u) = (a - b) + (a + b)u

		2 * Fp add/sub
	*/
	static inline void mul_xiC(Fp2T& z, const Fp2T& x)
	{
		assert(&z != &x);
		Fp::sub(z.a_, x.a_, x.b_);
		Fp::add(z.b_, x.a_, x.b_);
	}
#endif

	/*
		(a + bu)^2 = (a - b)(a + b) + 2abu
	*/
	static inline void squareC(Fp2T& z, const Fp2T& x)
	{
#ifdef BN_SUPPORT_SNARK
		Fp t, tt;
		Fp::add(t, x.b_, x.b_); // 2b
		t *= x.a_; // 2ab
		Fp::sub(tt, x.a_, x.b_); // a - b
		Fp::add(z.a_, x.a_, x.b_); // a + b
		z.a_ *= tt; // (a - b)(a + b)
		z.b_ = t;
#else
		Fp t, tt;
		Fp::addNC(t, x.b_, x.b_); // 2b
		t *= x.a_; // 2ab
		Fp::sub(tt, x.a_, x.b_); // a - b
		Fp::addNC(z.a_, x.a_, x.a_); // a + b
		z.a_ *= tt; // (a - b)(a + b)
		z.b_ = t;
#endif
	}

	/*
		1 / (a + b u) = (a - b u) / (a^2 + b^2)
	*/
	void inverse()
	{
		Fp t; Fp::mul(t, b_, b_);
		Fp aa; Fp::mul(aa, a_, a_);
		t += aa;
		Fp::inv(t, t); // 7.5K@i7, 10Kclk@Opteron
		a_ *= t;
		Fp::neg(b_, b_);
		b_ *= t;
	}
	void clear()
	{
		a_.clear();
		b_.clear();
	}

	std::string toString(int base = 10) const
	{
		return ("[" + a_.toString(base) + "," + b_.toString(base) + "]");
	}
	friend std::ostream& operator<<(std::ostream& os, const Fp2T& x)
	{
		return os << x.toString();
	}
	friend std::istream& operator>>(std::istream& is, Fp2T& x)
	{
		char cl, cm, cr;
		is >> cl >> x.a_ >> cm >> x.b_ >> cr;
		if (cl == '[' && cm == ',' && cr == ']') return is;
		throw std::ios_base::failure("bad Fp2");
	}
	bool operator==(const Fp2T& rhs) const
	{
		return a_ == rhs.a_ && b_ == rhs.b_;
	}
	bool operator!=(const Fp2T& rhs) const { return !operator==(rhs); }

	void set(const std::string& str)
	{
		std::istringstream iss(str);
		iss >> *this;
	}

	// z = x * b
	static inline void mul_Fp_0C(Fp2T& z, const Fp2T& x, const Fp& b)
	{
		Fp::mul(z.a_, x.a_, b);
		Fp::mul(z.b_, x.b_, b);
	}

	/*
		u^2 = -1
		(a + b)u = -b + au

		1 * Fp neg
	*/
	void mul_x()
	{
		Fp t = b_;
		b_ = a_;
		Fp::neg(a_, t);
	}

	/*
		(a + bu)cu = -bc + acu,
		where u is u^2 = -1.

		2 * Fp mul
		1 * Fp neg
	*/
	static inline void mul_Fp_1(Fp2T& z, const Fp& y_b)
	{
		Fp t;
		Fp::mul(t, z.b_, y_b);
		Fp::mul(z.b_, z.a_, y_b);
		Fp::neg(z.a_, t);
	}

	struct Dbl : public mie::local::addsubmul<Dbl, mie::local::hasNegative<Dbl> > {
		typedef typename Fp::Dbl FpDbl;
		enum { SIZE = FpDbl::SIZE * 2 };

		FpDbl a_, b_;

		std::string toString(int base = 10) const
		{
			return ("[" + a_.toString(base) + "," + b_.toString(base) + "]");
		}
		friend inline std::ostream& operator<<(std::ostream& os, const Dbl& x)
		{
			return os << x.toString();
		}

		Dbl() { }
		Dbl(const Fp2T& x)
			: a_(x.a_)
			, b_(x.b_)
		{
		}
		Dbl(const Fp& a, const Fp& b)
			: a_(a)
			, b_(b)
		{
		}
		Dbl(const FpDbl& a, const FpDbl& b)
			: a_(a)
			, b_(b)
		{
		}
		Dbl(const std::string& a, const std::string& b)
			: a_(a)
			, b_(b)
		{
		}

		void setDirect(const mie::Vuint& a, const mie::Vuint& b)
		{
			FpDbl::setDirect(a_, a);
			FpDbl::setDirect(b_, b);
		}
		void setDirect(const FpDbl& a, const FpDbl& b)
		{
			a_ = a;
			b_ = b;
		}
		FpDbl* get() { return &a_; }
		const FpDbl* get() const { return &a_; }
		void clear()
		{
			a_.clear();
			b_.clear();
		}
		bool isZero() const
		{
			return a_.isZero() && b_.isZero();
		}

		friend inline bool operator==(const Dbl& x, const Dbl& y)
		{
			return x.a_ == y.a_ && x.b_ == y.b_;
		}
		friend inline bool operator!=(const Dbl& x, const Dbl& y) { return !(x == y); }

		typedef void (uni_op)(Dbl&, const Dbl&);
		typedef void (bin_op)(Dbl&, const Dbl&, const Dbl&);

		static bin_op* add;
		static bin_op* addNC;
		static uni_op* neg;
		static bin_op* sub;
		static bin_op* subNC;

		static void (*mulOpt1)(Dbl& z, const Fp2T& x, const Fp2T& y);
		static void (*mulOpt2)(Dbl& z, const Fp2T& x, const Fp2T& y);
		static void (*square)(Dbl& z, const Fp2T& x);
		static void (*mod)(Fp2T& z, const Dbl& x);

		static uni_op* mul_xi;

		static void addC(Dbl& z, const Dbl& x, const Dbl& y)
		{
			FpDbl::add(z.a_, x.a_, y.a_);
			FpDbl::add(z.b_, x.b_, y.b_);
		}

		static void addNC_C(Dbl& z, const Dbl& x, const Dbl& y)
		{
			FpDbl::addNC(z.a_, x.a_, y.a_);
			FpDbl::addNC(z.b_, x.b_, y.b_);
		}

		static void negC(Dbl& z, const Dbl& x)
		{
			FpDbl::neg(z.a_, x.a_);
			FpDbl::neg(z.b_, x.b_);
		}

		static void subC(Dbl& z, const Dbl& x, const Dbl& y)
		{
			FpDbl::sub(z.a_, x.a_, y.a_);
			FpDbl::sub(z.b_, x.b_, y.b_);
		}

		static void subNC_C(Dbl& z, const Dbl& x, const Dbl& y)
		{
			FpDbl::subNC(z.a_, x.a_, y.a_);
			FpDbl::subNC(z.b_, x.b_, y.b_);
		}

#ifdef BN_SUPPORT_SNARK
		/*
			XITAG
			u^2 = -1
			xi = 9 + u
			(a + bu)(9 + u) = (9a - b) + (a + 9b)u
		*/
		static void mul_xiC(Dbl& z, const Dbl& x)
		{
			assert(&z != &x);
			FpDbl::add(z.a_, x.a_, x.a_); // 2
			FpDbl::add(z.a_, z.a_, z.a_); // 4
			FpDbl::add(z.a_, z.a_, z.a_); // 8
			FpDbl::add(z.a_, z.a_, x.a_); // 9
			FpDbl::sub(z.a_, z.a_, x.b_);

			FpDbl::add(z.b_, x.b_, x.b_); // 2
			FpDbl::add(z.b_, z.b_, z.b_); // 4
			FpDbl::add(z.b_, z.b_, z.b_); // 8
			FpDbl::add(z.b_, z.b_, x.b_); // 9
			FpDbl::add(z.b_, z.b_, x.a_);
		}
#else
		static void mul_xiC(Dbl& z, const Dbl& x)
		{
			assert(&z != &x);
			FpDbl::sub(z.a_, x.a_, x.b_);
			FpDbl::add(z.b_, x.b_, x.a_);
		}
#endif

		static void mulOptC(Dbl& z, const Fp2T& x, const Fp2T& y, int mode)
		{
			FpDbl d0;
			Fp s, t;
			Fp::addNC(s, x.a_, x.b_);
			Fp::addNC(t, y.a_, y.b_);
			FpDbl::mul(d0, x.b_, y.b_);
			FpDbl::mul(z.a_, x.a_, y.a_);
			FpDbl::mul(z.b_, s, t);
			FpDbl::subNC(z.b_, z.b_, z.a_);
			FpDbl::subNC(z.b_, z.b_, d0);

			if (mode == 1) {
				FpDbl::subOpt1(z.a_, z.a_, d0);

			} else {
				FpDbl::sub(z.a_, z.a_, d0);
			}
		}

		static void mulOpt1C(Dbl& z, const Fp2T& x, const Fp2T& y)
		{
			mulOptC(z, x, y, 1);
		}

		static void mulOpt2C(Dbl& z, const Fp2T& x, const Fp2T& y)
		{
			mulOptC(z, x, y, 2);
		}

		static void squareC(Dbl& z, const Fp2T& x)
		{
			Fp t0, t1;
			Fp::addNC(t0, x.b_, x.b_);
			FpDbl::mul(z.b_, t0, x.a_);
			Fp::addNC(t1, x.a_, Fp::getDirectP(1)); // RRR
			Fp::subNC(t1, t1, x.b_);
			Fp::addNC(t0, x.a_, x.b_);
			FpDbl::mul(z.a_, t0, t1);
		}

		static void modC(Fp2T& z, const Dbl& x)
		{
			FpDbl::mod(z.a_, x.a_);
			FpDbl::mod(z.b_, x.b_);
		}
	};
};

template<class Fp>
void (*Fp2T<Fp>::add)(Fp2T<Fp>& out, const Fp2T<Fp>& x, const Fp2T<Fp>& y) = &(Fp2T<Fp>::addC);

template<class Fp>
void (*Fp2T<Fp>::addNC)(Fp2T<Fp>& out, const Fp2T<Fp>& x, const Fp2T<Fp>& y) = &(Fp2T<Fp>::addNC_C);

template<class Fp>
void (*Fp2T<Fp>::sub)(Fp2T<Fp>& out, const Fp2T<Fp>& x, const Fp2T<Fp>& y) = &(Fp2T<Fp>::subC);

template<class Fp>
void (*Fp2T<Fp>::subNC)(Fp2T<Fp>& out, const Fp2T<Fp>& x, const Fp2T<Fp>& y) = &(Fp2T<Fp>::subNC_C);

template<class Fp>
void (*Fp2T<Fp>::mul)(Fp2T<Fp>& out, const Fp2T<Fp>& x, const Fp2T<Fp>& y) = &(Fp2T<Fp>::mulC);

template<class Fp>
void (*Fp2T<Fp>::mul_xi)(Fp2T<Fp>& out, const Fp2T<Fp>& x) = &(Fp2T<Fp>::mul_xiC);

template<class Fp>
void (*Fp2T<Fp>::square)(Fp2T<Fp>& out, const Fp2T<Fp>& x) = &(Fp2T<Fp>::squareC);

template<class Fp>
void (*Fp2T<Fp>::mul_Fp_0)(Fp2T<Fp>& z, const Fp2T<Fp>& x, const Fp& y) = &(Fp2T<Fp>::mul_Fp_0C);

template<class Fp>
void (*Fp2T<Fp>::divBy2)(Fp2T<Fp>& out, const Fp2T<Fp>& x) = &(Fp2T<Fp>::divBy2C);

template<class Fp>
typename Fp2T<Fp>::Dbl::bin_op* Fp2T<Fp>::Dbl::add = &(Fp2T<Fp>::Dbl::addC);

template<class Fp>
typename Fp2T<Fp>::Dbl::bin_op* Fp2T<Fp>::Dbl::addNC = &(Fp2T<Fp>::Dbl::addNC_C);

template<class Fp>
typename Fp2T<Fp>::Dbl::uni_op* Fp2T<Fp>::Dbl::neg = &(Fp2T<Fp>::Dbl::negC);

template<class Fp>
typename Fp2T<Fp>::Dbl::bin_op* Fp2T<Fp>::Dbl::sub = &(Fp2T<Fp>::Dbl::subC);

template<class Fp>
typename Fp2T<Fp>::Dbl::bin_op* Fp2T<Fp>::Dbl::subNC = &(Fp2T<Fp>::Dbl::subNC_C);

template<class Fp>
typename Fp2T<Fp>::Dbl::uni_op* Fp2T<Fp>::Dbl::mul_xi = &(Fp2T<Fp>::Dbl::mul_xiC);

template<class Fp>
void (*Fp2T<Fp>::Dbl::mulOpt1)(Dbl&, const Fp2T&, const Fp2T&) = &(Fp2T<Fp>::Dbl::mulOpt1C);

template<class Fp>
void (*Fp2T<Fp>::Dbl::mulOpt2)(Dbl&, const Fp2T&, const Fp2T&) = &(Fp2T<Fp>::Dbl::mulOpt2C);

template<class Fp>
void (*Fp2T<Fp>::Dbl::square)(Dbl&, const Fp2T&) = &(Fp2T<Fp>::Dbl::squareC);

template<class Fp>
void (*Fp2T<Fp>::Dbl::mod)(Fp2T&, const Dbl&) = &(Fp2T<Fp>::Dbl::modC);

/*
	Fp6T = Fp2[v] / (v^3 - Xi), Xi = -u - 1
	x = a_ + b_ v + c_ v^2
*/
template<class T>
struct Fp6T : public mie::local::addsubmul<Fp6T<T>,
		mie::local::hasNegative<Fp6T<T> > > {
	typedef T Fp2;
	typedef typename T::Fp Fp;
	typedef ParamT<Fp2> Param;
	typedef typename Fp2::Dbl Fp2Dbl;
	Fp2 a_, b_, c_;
	Fp6T() { }
	Fp6T(int x)
		: a_(x)
		, b_(0)
		, c_(0)
	{
	}
	Fp6T(const Fp2& a, const Fp2& b, const Fp2& c)
		: a_(a)
		, b_(b)
		, c_(c)
	{
	}
	Fp6T(const Fp& a0, const Fp& a1, const Fp& a2, const Fp& a3, const Fp& a4, const Fp& a5)
		: a_(a0, a1)
		, b_(a2, a3)
		, c_(a4, a5)
	{
	}
	void clear()
	{
		a_.clear();
		b_.clear();
		c_.clear();
	}

	Fp* get() { return a_.get(); }
	const Fp* get() const { return a_.get(); }
	Fp2* getFp2() { return &a_; }
	const Fp2* getFp2() const { return &a_; }
	void set(const Fp2& v0, const Fp2& v1, const Fp2& v2)
	{
		a_ = v0;
		b_ = v1;
		c_ = v2;
	}
	bool isZero() const
	{
		return a_.isZero() && b_.isZero() && c_.isZero();
	}

	static inline void addC(Fp6T& z, const Fp6T& x, const Fp6T& y)
	{
		Fp2::add(z.a_, x.a_, y.a_);
		Fp2::add(z.b_, x.b_, y.b_);
		Fp2::add(z.c_, x.c_, y.c_);
	}
	static inline void subC(Fp6T& z, const Fp6T& x, const Fp6T& y)
	{
		Fp2::sub(z.a_, x.a_, y.a_);
		Fp2::sub(z.b_, x.b_, y.b_);
		Fp2::sub(z.c_, x.c_, y.c_);
	}
	static inline void neg(Fp6T& z, const Fp6T& x)
	{
		Fp2::neg(z.a_, x.a_);
		Fp2::neg(z.b_, x.b_);
		Fp2::neg(z.c_, x.c_);
	}

	// 2120clk x 128
	static inline void mulC(Fp6T& z, const Fp6T& x, const Fp6T& y)
	{
		Dbl zd;
		Dbl::mul(zd, x, y);
		Dbl::mod(z, zd);
	}

	/*
		1944clk * 2
	*/
	static void square(Fp6T& z, const Fp6T& x)
	{
		assert(&z != &x);
		Fp2 v3, v4, v5;
		Fp2::add(v4, x.a_, x.a_);
		Fp2::mul(v4, v4, x.b_);
		Fp2::square(v5, x.c_);
		Fp2::mul_xi(z.b_, v5);
		z.b_ += v4;
		Fp2::sub(z.c_, v4, v5);
		Fp2::square(v3, x.a_);
		Fp2::sub(v4, x.a_, x.b_);
		v4 += x.c_;
		Fp2::add(v5, x.b_, x.b_);
		Fp2::mul(v5, v5, x.c_);
		Fp2::square(v4, v4);
		Fp2::mul_xi(z.a_, v5);
		z.a_ += v3;
		z.c_ += v4;
		z.c_ += v5;
		z.c_ -= v3;
	}

	void inverse()
	{
		Fp6T z;
		Fp2 t0, t1, t2, t4, t5;
		Fp2::mul(t0, b_, c_);
		Fp2::mul_xi(z.a_, t0);
		Fp2::square(t0, a_);
		Fp2::sub(z.a_, t0, z.a_);
		Fp2::square(t1, b_);
		Fp2::mul(t5, a_, c_);
		Fp2::sub(z.c_, t1, t5);
		Fp2::square(t2, c_);
		Fp2::mul(t4, a_, b_);
		Fp2::mul_xi(z.b_, t2);
		z.b_ -= t4;
		Fp2::mul(t1, a_, z.a_);
		Fp2::mul(t5, c_, z.b_);
		Fp2::mul_xi(t4, t5);
		t1 += t4;
		Fp2::mul(t5, b_, z.c_);
		Fp2::mul_xi(t4, t5);
		t1 += t4;
		t1.inverse();
		Fp2::mul(a_, z.a_, t1);
		Fp2::mul(b_, z.b_, t1);
		Fp2::mul(c_, z.c_, t1);
	}

	bool operator==(const Fp6T& rhs) const
	{
		return a_ == rhs.a_ && b_ == rhs.b_ && c_ == rhs.c_;
	}
	bool operator!=(const Fp6T& rhs) const { return !operator==(rhs); }
	friend std::ostream& operator<<(std::ostream& os, const Fp6T& x)
	{
		return os << "[" << x.a_ << ",\n " << x.b_ << ",\n " << x.c_ << "]";
	}
	friend std::istream& operator>>(std::istream& is, Fp6T& x)
	{
		char c1, c2, c3, c4;
		is >> c1 >> x.a_ >> c2 >> x.b_ >> c3 >> x.c_ >> c4;
		if (c1 == '[' && c2 == ',' && c3 == ',' && c4 == ']') return is;
		throw std::ios_base::failure("bad Fp6");
	}

	static void (*add)(Fp6T& z, const Fp6T& x, const Fp6T& y);
	static void (*sub)(Fp6T& z, const Fp6T& x, const Fp6T& y);
	static void (*mul)(Fp6T& z, const Fp6T& x, const Fp6T& y);

	static void (*pointDblLineEval)(Fp6T& l, Fp2* R, const Fp* P);
	static void (*pointDblLineEvalWithoutP)(Fp6T& l, Fp2* R);
	/*
		Algorithm 11 in App.B of Aranha et al. ePrint 2010/526

		NOTE:
		The original version uses precomputed and stored value of -P[1].
		But, we do not use that, this algorithm always calculates it.

		input P[0..2], R[0..2]
		R <- [2]R,
		(l00, 0, l02, 0, l11, 0) = f_{R,R}(P),
		l = (a,b,c) = (l00, l11, l02)
		where P[2] == 1
	*/
	static void pointDblLineEvalWithoutPC(Fp6T& l, Fp2* R)
	{
		Fp2 t0, t1, t2, t3, t4, t5;
		Fp2Dbl T0, T1, T2;
		// X1, Y1, Z1 == R[0], R[1], R[2]
		// xp, yp = P[0], P[1]

		// # 1
		Fp2::square(t0, R[2]);
		Fp2::mul(t4, R[0], R[1]);
		Fp2::square(t1, R[1]);
		// # 2
		Fp2::add(t3, t0, t0);
		Fp2::divBy2(t4, t4);
		Fp2::add(t5, t0, t1);
		// # 3
		t0 += t3;
		// # 4
#ifdef BN_SUPPORT_SNARK
		if (ParamT<Fp2>::b == 82) {
			// (a + bu) * (9 - u) = (9a + b) + (9b - a)u
			t3.a_ = t0.b_;
			t3.b_ = t0.a_;
			Fp2::mul_xi(t0, t3);
			t2.a_ = t0.b_;
			t2.b_ = t0.a_;
		} else {
			// (a + bu) * binv_xi
			Fp2::mul(t2, t0, ParamT<Fp2>::b_invxi);
		}
#else
		// (a + bu)(1 - u) = (a + b) + (b - a)u
		Fp::add(t2.a_, t0.a_, t0.b_);
		Fp::sub(t2.b_, t0.b_, t0.a_);
#endif
		// # 5
		Fp2::square(t0, R[0]);
		Fp2::add(t3, t2, t2);
		// ## 6
		t3 += t2;
		Fp2::addNC(l.c_, t0, t0);
		// ## 7
		Fp2::sub(R[0], t1, t3);
		Fp2::addNC(l.c_, l.c_, t0);
		t3 += t1;
		// # 8
		R[0] *= t4;
		Fp2::divBy2(t3, t3);
		// ## 9
		Fp2Dbl::square(T0, t3);
		Fp2Dbl::square(T1, t2);
		// # 10
		Fp2Dbl::addNC(T2, T1, T1);
		Fp2::add(t3, R[1], R[2]);
		// # 11
#ifdef BN_SUPPORT_SNARK
		Fp2Dbl::add(T2, T2, T1);
#else
		Fp2Dbl::addNC(T2, T2, T1);
#endif
		Fp2::square(t3, t3);
		// # 12
		t3 -= t5;
		// # 13
		T0 -= T2;
		// # 14
		Fp2Dbl::mod(R[1], T0);
		Fp2::mul(R[2], t1, t3);
		t2 -= t1;
		// # 15
		Fp2::mul_xi(l.a_, t2);
		Fp2::neg(l.b_, t3);
	}
	static void mulFp6_24_Fp_01(Fp6T& l, const Fp* P)
	{
		Fp2::mul_Fp_0(l.c_, l.c_, P[0]);
		Fp2::mul_Fp_0(l.b_, l.b_, P[1]);
	}
	static void pointDblLineEvalC(Fp6T& l, Fp2* R, const Fp* P)
	{
		pointDblLineEvalWithoutP(l, R);
		// # 16, #17
		mulFp6_24_Fp_01(l, P);
	}
	/*
		Algorithm 12 in App.B of Aranha et al. ePrint 2010/526

		input : P[0..1], Q[0..1], R[0..2]
		R <- R + Q
		(l00, 0, l02, 0, l11, 0) = f_{R,Q}(P),
		l = (a,b,c) = (l00, l11, l02)
		where Q[2] == 1, and P[2] == 1
	*/
	static void pointAddLineEvalWithoutP(Fp6T& l, Fp2* R, const Fp2* Q)
	{
		Fp2 t1, t2, t3, t4;
		Fp2Dbl T1, T2;
		// # 1
		Fp2::mul(t1, R[2], Q[0]);
		Fp2::mul(t2, R[2], Q[1]);
		// # 2
		Fp2::sub(t1, R[0], t1);
		Fp2::sub(t2, R[1], t2);
		// # 3
		Fp2::square(t3, t1);
		// # 4
		Fp2::mul(R[0], t3, R[0]);
		Fp2::square(t4, t2);
		// # 5
		t3 *= t1;
		t4 *= R[2];
		// # 6
		t4 += t3;
		// # 7
		t4 -= R[0];
		// # 8
		t4 -= R[0];
		// # 9
		R[0] -= t4;
		// # 10
		Fp2Dbl::mulOpt1(T1, t2, R[0]);
		Fp2Dbl::mulOpt1(T2, t3, R[1]);
		// # 11
		Fp2Dbl::sub(T2, T1, T2);
		// # 12
		Fp2Dbl::mod(R[1], T2);
		Fp2::mul(R[0], t1, t4);
		Fp2::mul(R[2], t3, R[2]);
		// # 14
		Fp2::neg(l.c_, t2);
		// # 15
		Fp2Dbl::mulOpt1(T1, t2, Q[0]);
		Fp2Dbl::mulOpt1(T2, t1, Q[1]);
		// # 16
		Fp2Dbl::sub(T1, T1, T2);
		// # 17
		Fp2Dbl::mod(t2, T1);
		// ### @note: Be careful, below fomulas are typo.
		// # 18
		Fp2::mul_xi(l.a_, t2);
		l.b_ = t1;
	}
	static void pointAddLineEval(Fp6T& l, Fp2* R, const Fp2* Q, const Fp* P)
	{
		pointAddLineEvalWithoutP(l, R, Q);
		// # 13, #19
		mulFp6_24_Fp_01(l, P);
	}
	static void mul_Fp_b(Fp6T& z, const Fp& x)
	{
		Fp2::mul_Fp_0(z.b_, z.b_, x);
	}
	static void mul_Fp_c(Fp6T& z, const Fp& x)
	{
		Fp2::mul_Fp_0(z.c_, z.c_, x);
	}

	struct Dbl : public mie::local::addsubmul<Dbl, mie::local::hasNegative<Dbl> > {
		typedef typename Fp::Dbl FpDbl;
		typedef typename Fp2::Dbl Fp2Dbl;
		enum { SIZE = Fp2Dbl::SIZE * 3 };

		Fp2Dbl a_, b_, c_;

		std::string toString(int base = 10) const
		{
			return ("[" + a_.toString(base) + ",\n" + b_.toString(base) + ",\n" + c_.toString() + "]");
		}
		friend inline std::ostream& operator<<(std::ostream& os, const Dbl& x)
		{
			return os << x.toString();
		}

		Dbl() { }
		Dbl(const Fp6T& x)
			: a_(x.a_)
			, b_(x.b_)
			, c_(x.c_)
		{
		}
		Dbl(const Fp2& a, const Fp2& b, const Fp2& c)
			: a_(a)
			, b_(b)
			, c_(c)
		{
		}
		Dbl(const Fp2Dbl& a, const Fp2Dbl& b, const Fp2Dbl& c)
			: a_(a)
			, b_(b)
			, c_(c)
		{
		}
		Dbl(const std::string& a0, const std::string& a1, const std::string& b0, const std::string& b1, const std::string& c0, const std::string& c1)
			: a_(a0, a1)
			, b_(b0, b1)
			, c_(c0, c1)
		{
		}

		void setDirect(const mie::Vuint& v0, const mie::Vuint& v1, const mie::Vuint& v2, const mie::Vuint& v3, const mie::Vuint& v4, const mie::Vuint& v5)
		{
			a_.setDirect(v0, v1);
			b_.setDirect(v2, v3);
			c_.setDirect(v4, v5);
		}
		void setDirect(const Fp2Dbl& a, const Fp2Dbl& b, const Fp2Dbl& c)
		{
			a_ = a;
			b_ = b;
			c_ = c;
		}
		Fp2Dbl* get() { return &a_; }
		const Fp2Dbl* get() const { return &a_; }
		bool isZero() const
		{
			return a_.isZero() && b_.isZero() && c_.isZero();
		}

		friend inline bool operator==(const Dbl& x, const Dbl& y)
		{
			return x.a_ == y.a_ && x.b_ == y.b_ && x.c_ == y.c_;
		}
		friend inline bool operator!=(const Dbl& x, const Dbl& y) { return !(x == y); }

		typedef void (uni_op)(Dbl&, const Dbl&);
		typedef void (bin_op)(Dbl&, const Dbl&, const Dbl&);

		static void add(Dbl& z, const Dbl& x, const Dbl& y)
		{
			Fp2Dbl::add(z.a_, x.a_, y.a_);
			Fp2Dbl::add(z.b_, x.b_, y.b_);
			Fp2Dbl::add(z.c_, x.c_, y.c_);
		}

		static void addNC(Dbl& z, const Dbl& x, const Dbl& y)
		{
			Fp2Dbl::addNC(z.a_, x.a_, y.a_);
			Fp2Dbl::addNC(z.b_, x.b_, y.b_);
			Fp2Dbl::addNC(z.c_, x.c_, y.c_);
		}

		static void neg(Dbl& z, const Dbl& x)
		{
			Fp2Dbl::neg(z.a_, x.a_);
			Fp2Dbl::neg(z.b_, x.b_);
			Fp2Dbl::neg(z.c_, x.c_);
		}

		static void sub(Dbl& z, const Dbl& x, const Dbl& y)
		{
			Fp2Dbl::sub(z.a_, x.a_, y.a_);
			Fp2Dbl::sub(z.b_, x.b_, y.b_);
			Fp2Dbl::sub(z.c_, x.c_, y.c_);
		}

		static void subNC(Dbl& z, const Dbl& x, const Dbl& y)
		{
			Fp2Dbl::subNC(z.a_, x.a_, y.a_);
			Fp2Dbl::subNC(z.b_, x.b_, y.b_);
			Fp2Dbl::subNC(z.c_, x.c_, y.c_);
		}
		static void (*mul)(Dbl&, const Fp6T& x, const Fp6T& y);

		/*
			1978clk * 262 ; QQQ
			=> 1822clk => 1580clk
		*/
		static void mulC(Dbl& z, const Fp6T& x, const Fp6T& y)
		{
			Fp2 t0, t1;
			Fp2Dbl T0, T1, T2;
			// # 1
			Fp2Dbl::mulOpt1(T0, x.a_, y.a_);
			Fp2Dbl::mulOpt1(T1, x.b_, y.b_);
			Fp2Dbl::mulOpt1(T2, x.c_, y.c_);
			// # 2
			Fp2::addNC(t0, x.b_, x.c_);
			Fp2::addNC(t1, y.b_, y.c_);
			// # 3
			Fp2Dbl::mulOpt2(z.c_, t0, t1);
			// # 4
			Fp2Dbl::addNC(z.b_, T1, T2);
			// # 5
			FpDbl::sub(z.c_.a_, z.c_.a_, z.b_.a_);
			// # 6
			FpDbl::subNC(z.c_.b_, z.c_.b_, z.b_.b_);
			// # 7
			Fp2Dbl::mul_xi(z.b_, z.c_);
			// # 8
			Fp2Dbl::add(z.a_, z.b_, T0);
			// # 9
			Fp2::addNC(t0, x.a_, x.b_);
			Fp2::addNC(t1, y.a_, y.b_);
			// # 10
			Fp2Dbl::mulOpt2(z.c_, t0, t1);
			// # 11
			Fp2Dbl::addNC(z.b_, T0, T1);
			// # 12
			FpDbl::sub(z.c_.a_, z.c_.a_, z.b_.a_);
			// # 13
			FpDbl::subNC(z.c_.b_, z.c_.b_, z.b_.b_);
			/// c1 except xi * t2 term
			// # 14, 15
#ifdef BN_SUPPORT_SNARK
			Fp2Dbl::mul_xi(z.b_, T2); // store xi * t2 term
#else
			FpDbl::subOpt1(z.b_.a_, T2.a_, T2.b_);
			FpDbl::add(z.b_.b_, T2.a_, T2.b_);
#endif
			// # 16
			Fp2Dbl::add(z.b_, z.b_, z.c_);
			// # 17
			Fp2::addNC(t0, x.a_, x.c_);
			Fp2::addNC(t1, y.a_, y.c_);
			// # 18
			Fp2Dbl::mulOpt2(z.c_, t0, t1);
			// # 19
			Fp2Dbl::addNC(T2, T2, T0);
			// # 20
			FpDbl::sub(z.c_.a_, z.c_.a_, T2.a_);
			// # 22
			FpDbl::add(z.c_.a_, z.c_.a_, T1.a_);
			// # 21
			FpDbl::subNC(z.c_.b_, z.c_.b_, T2.b_);
			// # 23
			FpDbl::addNC(z.c_.b_, z.c_.b_, T1.b_);
		}
		static void mod(Fp6T& z, const Dbl& x)
		{
			Fp2Dbl::mod(z.a_, x.a_);
			Fp2Dbl::mod(z.b_, x.b_);
			Fp2Dbl::mod(z.c_, x.c_);
		}
	};
};

template<class Fp2>
void (*Fp6T<Fp2>::add)(Fp6T<Fp2>& z, const Fp6T<Fp2>& x, const Fp6T<Fp2>& y) = &(Fp6T<Fp2>::addC);

template<class Fp2>
void (*Fp6T<Fp2>::sub)(Fp6T<Fp2>& z, const Fp6T<Fp2>& x, const Fp6T<Fp2>& y) = &(Fp6T<Fp2>::subC);

template<class Fp2>
void (*Fp6T<Fp2>::mul)(Fp6T<Fp2>& z, const Fp6T<Fp2>& x, const Fp6T<Fp2>& y) = &(Fp6T<Fp2>::mulC);

template<class Fp2>
void (*Fp6T<Fp2>::pointDblLineEval)(Fp6T<Fp2>& z, Fp2* x, const typename Fp2::Fp* y) = &(Fp6T<Fp2>::pointDblLineEvalC);

template<class Fp2>
void (*Fp6T<Fp2>::pointDblLineEvalWithoutP)(Fp6T<Fp2>& z, Fp2* x) = &(Fp6T<Fp2>::pointDblLineEvalWithoutPC);

template<class Fp2>
void (*Fp6T<Fp2>::Dbl::mul)(Dbl& z, const Fp6T& x, const Fp6T& y) = &(Fp6T<Fp2>::Dbl::mulC);

template<class Fp2>
struct CompressT;

/*
	Fp12T = Fp6[w] / (w^2 - v)
	x = a_ + b_ w
*/
template<class T>
struct Fp12T : public mie::local::addsubmul<Fp12T<T> > {
	typedef T Fp6;
	typedef typename Fp6::Fp2 Fp2;
	typedef typename Fp6::Fp Fp;
	typedef ParamT<Fp2> Param;
	typedef typename Fp2::Dbl Fp2Dbl;
	typedef typename Fp6::Dbl Fp6Dbl;

	Fp6 a_, b_;
	Fp12T() { }
	Fp12T(int x)
		: a_(x)
		, b_(0)
	{
	}
	Fp12T(const Fp6& a, const Fp6& b)
		: a_(a)
		, b_(b)
	{
	}
	Fp12T(const Fp& a0, const Fp& a1, const Fp& a2, const Fp& a3, const Fp& a4, const Fp& a5,
		const Fp& a6, const Fp& a7, const Fp& a8, const Fp& a9, const Fp& a10, const Fp& a11)
		: a_(a0, a1, a2, a3, a4, a5)
		, b_(a6, a7, a8, a9, a10, a11)
	{
	}

	Fp12T(const Fp2& a0, const Fp2& a1, const Fp2& a2, const Fp2& a3, const Fp2& a4, const Fp2& a5)
		: a_(a0, a1, a2)
		, b_(a3, a4, a5)
	{
	}

	void clear()
	{
		a_.clear();
		b_.clear();
	}

	Fp* get() { return a_.get(); }
	const Fp* get() const { return a_.get(); }
	Fp2* getFp2() { return a_.getFp2(); }
	const Fp2* getFp2() const { return a_.getFp2(); }
	void set(const Fp2& v0, const Fp2& v1, const Fp2& v2, const Fp2& v3, const Fp2& v4, const Fp2& v5)
	{
		a_.set(v0, v1, v2);
		b_.set(v3, v4, v5);
	}

	bool isZero() const
	{
		return a_.isZero() && b_.isZero();
	}
	bool operator==(const Fp12T& rhs) const
	{
		return a_ == rhs.a_ && b_ == rhs.b_;
	}
	bool operator!=(const Fp12T& rhs) const { return !operator==(rhs); }
	friend std::ostream& operator<<(std::ostream& os, const Fp12T& x)
	{
		return os << "[" << x.a_ << ",\n " << x.b_ << "]";
	}
	friend std::istream& operator>>(std::istream& is, Fp12T& x)
	{
		char c1, c2, c3;
		is >> c1 >> x.a_ >> c2 >> x.b_ >> c3;
		if (c1 == '[' && c2 == ',' && c3 == ']') return is;
		throw std::ios_base::failure("bad Fp12");
	}
	static inline void add(Fp12T& z, const Fp12T& x, const Fp12T& y)
	{
		Fp6::add(z.a_, x.a_, y.a_);
		Fp6::add(z.b_, x.b_, y.b_);
	}
	static inline void sub(Fp12T& z, const Fp12T& x, const Fp12T& y)
	{
		Fp6::sub(z.a_, x.a_, y.a_);
		Fp6::sub(z.b_, x.b_, y.b_);
	}
	static inline void neg(Fp12T& z, const Fp12T& x)
	{
		Fp6::neg(z.a_, x.a_);
		Fp6::neg(z.b_, x.b_);
	}

	// 6.4k x 22
	static void (*mul)(Fp12T& z, const Fp12T& x, const Fp12T& y);
	static inline void mulC(Fp12T& z, const Fp12T& x, const Fp12T& y)
	{
		Dbl zd;
		Fp6 t0, t1;
		Fp6Dbl T0, T1, T2;
		// # 1
		Fp6Dbl::mul(T0, x.a_, y.a_);
		Fp6Dbl::mul(T1, x.b_, y.b_);
		Fp6::add(t0, x.a_, x.b_);
		Fp6::add(t1, y.a_, y.b_);
		// # 2
		Fp6Dbl::mul(zd.a_, t0, t1);
		// # 3
		Fp6Dbl::add(T2, T0, T1);
		// # 4
		Fp6Dbl::sub(zd.b_, zd.a_, T2);
		// #6, 7, 8
		mul_gamma_add<Fp6Dbl, Fp2Dbl>(zd.a_, T1, T0);
		Dbl::mod(z, zd);
	}

	/*
		z = *this * *this
		4800clk x 64
	*/
	static void (*square)(Fp12T& z);
	static void squareC(Fp12T& z)
	{
		Fp6 t0, t1;
		// # 1, 2
		Fp6::add(t0, z.a_, z.b_);
		// b_.mul_gamma(t1); t1 += a_; # 3
		mul_gamma_add<Fp6, Fp2>(t1, z.b_, z.a_);
		// # 4
		z.b_ *= z.a_;
		Fp6::mul(z.a_, t0, t1);
		// # 5, 6, 7 @note It's typo.
		mul_gamma_add<Fp6, Fp2>(t1, z.b_, z.b_);
		// # 8
		z.a_ -= t1;
		z.b_ += z.b_;
	}

	/*
		square over Fp4
		Operation Count:

		3 * Fp2Dbl::square
		2 * Fp2Dbl::mod
		1 * Fp2Dbl::mul_xi == 1 * (2 * Fp2::add/sub) == 2 * Fp2::add/sub
		3 * Fp2Dbl::add/sub == 3 * (2 * Fp2::add/sub) == 6 * Fp2::add/sub
		1 * Fp2::add/sub

		Total:

		3 * Fp2Dbl::square
		2 * Fp2Dbl::mod
		9 * Fp2::add/sub
	 */
	static inline void sq_Fp4UseDbl(Fp2& z0, Fp2& z1, const Fp2& x0, const Fp2& x1)
	{
		Fp2Dbl T0, T1, T2;
		Fp2Dbl::square(T0, x0);
		Fp2Dbl::square(T1, x1);
		Fp2Dbl::mul_xi(T2, T1);
		T2 += T0;
		Fp2::add(z1, x0, x1);
		Fp2Dbl::mod(z0, T2);
		// overwrite z[0] (position 0).
		Fp2Dbl::square(T2, z1);
		T2 -= T0;
		T2 -= T1;
		Fp2Dbl::mod(z1, T2);
	}

	/*
		square over only cyclotomic subgroup
		z_ = x_^2
		output to z_

		It is based on:
		- Robert Granger and Michael Scott.
		Faster squaring in the cyclotomic subgroup of sixth degree extensions.
		PKC2010, pp. 209--223. doi:10.1007/978-3-642-13013-7_13.
	*/
	/*
		Operation Count:
		3 * sq_Fp4UseDbl == 3 * (
			3 * Fp2Dbl::square
			2 * Fp2Dbl::mod
			9 * Fp2::add/sub
		) == (
			9 * Fp2Dbl::square
			6 * Fp2Dbl::mod
			27 * Fp2::add/sub
		)
		18 * Fp2::add/sub
		1  * Fp2::mul_xi

		Total:

		9  * Fp2Dbl::square
		6  * Fp2Dbl::mod
		46 * Fp2::add/sub
		3260k x 4
	*/
	void Fp2_2z_add_3x(Fp2& z, const Fp2& x)
	{
		Fp::_2z_add_3x(z.a_, x.a_);
		Fp::_2z_add_3x(z.b_, x.b_);
	}
	void sqru()
	{
		Fp2& z0(a_.a_);
		Fp2& z4(a_.b_);
		Fp2& z3(a_.c_);
		Fp2& z2(b_.a_);
		Fp2& z1(b_.b_);
		Fp2& z5(b_.c_);
		Fp2 t0, t1;
		sq_Fp4UseDbl(t0, t1, z0, z1); // a^2 = t0 + t1*y
		// For A
		Fp2::sub(z0, t0, z0);
		z0 += z0;
		z0 += t0;
#if 0
		Fp2_2z_add_3x(z1, t1);
#else
		Fp2::add(z1, t1, z1);
		z1 += z1;
		z1 += t1;
#endif
		// t0 and t1 are unnecessary from here.
		Fp2 t2, t3;
		sq_Fp4UseDbl(t0, t1, z2, z3); // b^2 = t0 + t1*y
		sq_Fp4UseDbl(t2, t3, z4, z5); // c^2 = t2 + t3*y
		// For C
		Fp2::sub(z4, t0, z4);
		z4 += z4;
		z4 += t0;
#if 0
		Fp2_2z_add_3x(z5, t1);
#else
		Fp2::add(z5, t1, z5);
		z5 += z5;
		z5 += t1;
#endif
		// For B
		Fp2::mul_xi(t0, t3);
#if 0
		Fp2_2z_add_3x(z2, t0);
#else
		Fp2::add(z2, t0, z2);
		z2 += z2;
		z2 += t0;
#endif
		Fp2::sub(z3, t2, z3);
		z3 += z3;
		z3 += t2;
	}

	/*
		This is same as sqru, but output given reference.
	*/
	void sqru(Fp12T& zz) const
	{
		zz = *this;
		zz.sqru();
	}

	void inverse()
	{
		Fp6 tmp0;
		Fp6 tmp1;
		Fp2 tmp2;
		Fp6::square(tmp0, a_);
		Fp6::square(tmp1, b_);
		Fp2::mul_xi(tmp2, tmp1.c_);
		tmp0.a_ -= tmp2;
		tmp0.b_ -= tmp1.a_;
		tmp0.c_ -= tmp1.b_;
		tmp0.inverse();
		Fp6::mul(a_, a_, tmp0);
		Fp6::mul(b_, b_, tmp0);
		Fp6::neg(b_, b_);
	}

	/*
		(a + bw) -> (a - bw) gammar
	*/
	void Frobenius(Fp12T& z) const
	{
		/* this assumes (q-1)/6 is odd */
		if (&z != this) {
			z.a_.a_.a_ = a_.a_.a_;
			z.a_.b_.a_ = a_.b_.a_;
			z.a_.c_.a_ = a_.c_.a_;
			z.b_.a_.a_ = b_.a_.a_;
			z.b_.b_.a_ = b_.b_.a_;
			z.b_.c_.a_ = b_.c_.a_;
		}
		Fp::neg(z.a_.a_.b_, a_.a_.b_);
		Fp::neg(z.a_.b_.b_, a_.b_.b_);
		Fp::neg(z.a_.c_.b_, a_.c_.b_);
		Fp::neg(z.b_.a_.b_, b_.a_.b_);
		Fp::neg(z.b_.b_.b_, b_.b_.b_);
		Fp::neg(z.b_.c_.b_, b_.c_.b_);
#ifdef BN_SUPPORT_SNARK
		z.a_.b_ *= Param::gammar[1];
		z.a_.c_ *= Param::gammar[3];
#else
		assert(Param::gammar[1].a_ == 0);
		assert(Param::gammar[3].b_ == 0);
		Fp2::mul_Fp_1(z.a_.b_, Param::gammar[1].b_);
		Fp2::mul_Fp_0(z.a_.c_, z.a_.c_, Param::gammar[3].a_);
#endif
		z.b_.a_ *= Param::gammar[0];
		z.b_.b_ *= Param::gammar[2];
		z.b_.c_ *= Param::gammar[4];
	}

	/*
		gammar = c + dw
		a + bw -> t = (a - bw)(c + dw)
		~t = (a + bw)(c - dw)
		~t * (c + dw) = (a + bw) * ((c + dw)(c - dw))
		gammar2 = (c + dw)(c - dw) in Fp6
	*/
	void Frobenius2(Fp12T& z) const
	{
#if 0
		Frobenius(z);
		z.Frobenius(z);
#else
		if (&z != this) {
			z.a_.a_ = a_.a_;
		}
		z.a_.a_ = a_.a_;
		Fp2::mul_Fp_0(z.a_.b_, a_.b_, Param::gammar2[1].a_);
		Fp2::mul_Fp_0(z.a_.c_, a_.c_, Param::gammar2[3].a_);
		Fp2::mul_Fp_0(z.b_.a_, b_.a_, Param::gammar2[0].a_);
		Fp2::mul_Fp_0(z.b_.b_, b_.b_, Param::gammar2[2].a_);
		Fp2::mul_Fp_0(z.b_.c_, b_.c_, Param::gammar2[4].a_);
#endif
	}

	void Frobenius3(Fp12T& z) const
	{
#if 0
		Frobenius2(z);
		z.Frobenius(z);
#else
		z.a_.a_.a_ = a_.a_.a_;
		z.a_.b_.a_ = a_.b_.a_;
		z.a_.c_.a_ = a_.c_.a_;
		z.b_.a_.a_ = b_.a_.a_;
		z.b_.b_.a_ = b_.b_.a_;
		z.b_.c_.a_ = b_.c_.a_;
		Fp::neg(z.a_.a_.b_, a_.a_.b_);
		Fp::neg(z.a_.b_.b_, a_.b_.b_);
		Fp::neg(z.a_.c_.b_, a_.c_.b_);
		Fp::neg(z.b_.a_.b_, b_.a_.b_);
		Fp::neg(z.b_.b_.b_, b_.b_.b_);
		Fp::neg(z.b_.c_.b_, b_.c_.b_);

#ifdef BN_SUPPORT_SNARK
		z.a_.b_ *= Param::gammar3[1];
		z.a_.c_ *= Param::gammar3[3];
#else
		z.a_.b_.mul_x();
		Fp2::mul_Fp_0(z.a_.c_, z.a_.c_, Param::gammar3[3].a_);
#endif
		z.b_.a_ *= Param::gammar3[0];
		z.b_.b_ *= Param::gammar3[2];
		z.b_.c_ *= Param::gammar3[4];
#endif
	}

	/*
		@note destory *this
	*/
	void mapToCyclo(Fp12T& z)
	{
		// (a + b*i) -> ((a - b*i) * (a + b*i)^(-1))^(q^2+1)
		//
		// See Beuchat page 9: raising to 6-th power is the same as
		// conjugation, so this entire function computes
		// z^((p^6-1) * (p^2+1))
		z.a_ = a_;
		Fp6::neg(z.b_, b_);
		inverse();
		z *= *this;
		z.Frobenius2(*this);
		z *= *this;
	}

	/*
		Final exponentiation based on:
		- Laura Fuentes-Casta{\~n}eda, Edward Knapp, and Francisco
		Rodr\'{\i}guez-Henr\'{\i}quez.
		Faster hashing to $\mathbb{G}_2$.
		SAC 2011, pp. 412--430. doi:10.1007/978-3-642-28496-0_25.

		*this = final_exp(*this)
	*/
#ifdef BN_SUPPORT_SNARK
	static void pow_neg_t(Fp12T &out, const Fp12T &in)
	{
		out = in;
		Fp12T inConj;
		inConj.a_ = in.a_;
		Fp6::neg(inConj.b_, in.b_); // in^-1 == in^(p^6)

		for (size_t i = 1; i < Param::zReplTbl.size(); i++) {
			out.sqru();
			if (Param::zReplTbl[i] > 0) {
				Fp12T::mul(out, out, in);
			} else if (Param::zReplTbl[i] < 0) {
				Fp12T::mul(out, out, inConj);
			}
		}
		// invert by conjugation
		Fp6::neg(out.b_, out.b_);
	}
#endif

	void final_exp()
	{
		Fp12T f, f2z, f6z, f6z2, f12z3;
		Fp12T a, b;
		Fp12T& z = *this;
		mapToCyclo(f);

#ifdef BN_SUPPORT_SNARK
		Fp12T::pow_neg_t(f2z, f);
		f2z.sqru(); // f2z = f^(-2*z)
		f2z.sqru(f6z);
		f6z *= f2z; // f6z = f^(-6*z)
		Fp12T::pow_neg_t(f6z2, f6z);
		// A variable a is unnecessary only here.
		f6z2.sqru(a);
		// Compress::fixed_power(f12z3, a); // f12z3 = f^(-12*z^3)
		Fp12T::pow_neg_t(f12z3, a);
		// It will compute inversion of f2z, thus, conjugation free.
		Fp6::neg(f6z.b_, f6z.b_); // f6z = f^(6z)
		Fp6::neg(f12z3.b_, f12z3.b_); // f12z3 = f^(12*z^3)
		// Computes a and b.
		Fp12T::mul(a, f12z3, f6z2); // a = f^(12*z^3 + 6z^2)
		a *= f6z; // a = f^(12*z^3 + 6z^2 + 6z)
		Fp12T::mul(b, a, f2z); // b = f^(12*z^3 + 6z^2 + 4z)w
		// @note f2z, f6z, and f12z are unnecessary from here.
		// Last part.
		Fp12T::mul(z, a, f6z2); // z = f^(12*z^3 + 12z^2 + 6z)
		z *= f; // z = f^(12*z^3 + 12z^2 + 6z + 1)
		b.Frobenius(f2z); // f2z = f^(q(12*z^3 + 6z^2 + 4z))
		z *= f2z; // z = f^(q(12*z^3 + 6z^2 + 4z) + (12*z^3 + 12z^2 + 6z + 1))
		a.Frobenius2(f2z); // f2z = f^(q^2(12*z^3 + 6z^2 + 6z))
		z *= f2z; // z = f^(q^2(12*z^3 + 6z^2 + 6z) + q(12*z^3 + 6z^2 + 4z) + (12*z^3 + 12z^2 + 6z + 1))
		Fp6::neg(f.b_, f.b_); // f = -f
		b *= f; // b = f^(12*z^3 + 6z^2 + 4z - 1)
		b.Frobenius3(f2z); // f2z = f^(q^3(12*z^3 + 6z^2 + 4z - 1))
		z *= f2z;
		// z = f^(q^3(12*z^3 + 6z^2 + 4z - 1) +
		// q^2(12*z^3 + 6z^2 + 6z) +
		// q(12*z^3 + 6z^2 + 4z) +
		// (12*z^3 + 12z^2 + 6z + 1))
		// see page 6 in the "Faster hashing to G2" paper
#else
		// Hard part starts from here.
		// Computes addition chain.
		typedef CompressT<Fp2> Compress;
		Compress::fixed_power(f2z, f);
		f2z.sqru();
		f2z.sqru(f6z);
		f6z *= f2z;
		Compress::fixed_power(f6z2, f6z);
		// A variable a is unnecessary only here.
		f6z2.sqru(a);
		Compress::fixed_power(f12z3, a);
		// It will compute inversion of f2z, thus, conjugation free.
		Fp6::neg(f6z.b_, f6z.b_);
		Fp6::neg(f12z3.b_, f12z3.b_);
		// Computes a and b.
		Fp12T::mul(a, f12z3, f6z2);
		a *= f6z;
		Fp12T::mul(b, a, f2z);
		// @note f2z, f6z, and f12z are unnecessary from here.
		// Last part.
		Fp12T::mul(z, a, f6z2);
		z *= f;
		b.Frobenius(f2z);
		z *= f2z;
		a.Frobenius2(f2z);
		z *= f2z;
		Fp6::neg(f.b_, f.b_);
		b *= f;
		b.Frobenius3(f2z);
		z *= f2z;
#endif
	}

	struct Dbl : public mie::local::addsubmul<Dbl, mie::local::hasNegative<Dbl> > {
		typedef typename Fp2::Dbl Fp2Dbl;
		typedef typename Fp6::Dbl Fp6Dbl;
		enum { SIZE = Fp6Dbl::SIZE * 2 };

		Fp6Dbl a_, b_;

		std::string toString(int base = 10) const
		{
			return ("[" + a_.toString(base) + ",\n" + b_.toString(base) + "]");
		}
		friend inline std::ostream& operator<<(std::ostream& os, const Dbl& x)
		{
			return os << x.toString();
		}

		Dbl() { }
		Dbl(const Fp12T& x)
			: a_(x.a_)
			, b_(x.b_)
		{
		}
		Dbl(const Fp6& a, const Fp6& b)
			: a_(a)
			, b_(b)
		{
		}
		Dbl(const Fp6Dbl& a, const Fp6Dbl& b)
			: a_(a)
			, b_(b)
		{
		}
		Dbl(const std::string& a, const std::string& b)
			: a_(a)
			, b_(b)
		{
		}

		void setDirect(const Fp6Dbl& a, const Fp6Dbl& b)
		{
			a_ = a;
			b_ = b;
		}
		Fp6Dbl* get() { return &a_; }
		const Fp6Dbl* get() const { return &a_; }
		bool isZero() const { return a_.isZero() && b_.isZero(); }

		friend inline bool operator==(const Dbl& x, const Dbl& y)
		{
			return x.a_ == y.a_ && x.b_ == y.b_;
		}
		friend inline bool operator!=(const Dbl& x, const Dbl& y)
		{
			return ! (x == y);
		}

		typedef void (uni_op)(Dbl&, const Dbl&);
		typedef void (bin_op)(Dbl&, const Dbl&, const Dbl&);

		static void add(Dbl& z, const Dbl& x, const Dbl& y)
		{
			Fp6Dbl::add(z.a_, x.a_, y.a_);
			Fp6Dbl::add(z.b_, x.b_, y.b_);
		}

		static void addNC(Dbl& z, const Dbl& x, const Dbl& y)
		{
			Fp6Dbl::addNC(z.a_, x.a_, y.a_);
			Fp6Dbl::addNC(z.b_, x.b_, y.b_);
		}

		static void neg(Dbl& z, const Dbl& x)
		{
			Fp6Dbl::neg(z.a_, x.a_);
			Fp6Dbl::neg(z.b_, x.b_);
		}

		static void sub(Dbl& z, const Dbl& x, const Dbl& y)
		{
			Fp6Dbl::sub(z.a_, x.a_, y.a_);
			Fp6Dbl::sub(z.b_, x.b_, y.b_);
		}

		static void subNC(Dbl& z, const Dbl& x, const Dbl& y)
		{
			Fp6Dbl::subNC(z.a_, x.a_, y.a_);
			Fp6Dbl::subNC(z.b_, x.b_, y.b_);
		}

		/*
			z *= x,
			position: 0   1   2      3   4   5
			    x = (l00, 0, l02) + (0, l11, 0)*w
			x is represented as:
			(x.a_, x.b_, x.c_) = (l00, l11, l02)
			4800clk * 66
		*/
		/*
			Operation Count:

			13 * Fp2Dbl::mulOpt2
			6  * Fp2Dbl::mod
			10 * Fp2::add/sub
			19 * Fp2Dbl::add/sub == 19 * (2 * Fp2::add/sub) == 38 * Fp2::add/sub
			4  * Fp2Dbl::mul_xi  == 4  * (2 * Fp2::add/sub) == 8  * Fp2::add/sub

			Total:

			13 * Fp2Dbl::mulOpt2
			6  * Fp2Dbl::mod
			56 * Fp2::add/sub
		*/
		static void (*mul_Fp2_024)(Fp12T& z, const Fp6& x);
		static void mul_Fp2_024C(Fp12T& z, const Fp6& x)
		{
			Fp2& z0 = z.a_.a_;
			Fp2& z1 = z.a_.b_;
			Fp2& z2 = z.a_.c_;
			Fp2& z3 = z.b_.a_;
			Fp2& z4 = z.b_.b_;
			Fp2& z5 = z.b_.c_;
			const Fp2& x0 = x.a_;
			const Fp2& x2 = x.c_;
			const Fp2& x4 = x.b_;
			Fp2 t0, t1, t2;
			Fp2 s0;
			Fp2Dbl T3, T4;
			Fp2Dbl D0, D2, D4;
			Fp2Dbl S1;
			Fp2Dbl::mulOpt2(D0, z0, x0);
			Fp2Dbl::mulOpt2(D2, z2, x2);
			Fp2Dbl::mulOpt2(D4, z4, x4);
			Fp2::add(t2, z0, z4);
			Fp2::add(t1, z0, z2);
			Fp2::add(s0, z1, z3);
			s0 += z5;
			// For z.a_.a_ = z0.
			Fp2Dbl::mulOpt2(S1, z1, x2);
			Fp2Dbl::add(T3, S1, D4);
			Fp2Dbl::mul_xi(T4, T3);
			T4 += D0;
			Fp2Dbl::mod(z0, T4);
			// For z.a_.b_ = z1.
			Fp2Dbl::mulOpt2(T3, z5, x4);
			S1 += T3;
			T3 += D2;
			Fp2Dbl::mul_xi(T4, T3);
			Fp2Dbl::mulOpt2(T3, z1, x0);
			S1 += T3;
			T4 += T3;
			Fp2Dbl::mod(z1, T4);
			// For z.a_.c_ = z2.
			Fp2::add(t0, x0, x2);
			Fp2Dbl::mulOpt2(T3, t1, t0);
			T3 -= D0;
			T3 -= D2;
			Fp2Dbl::mulOpt2(T4, z3, x4);
			S1 += T4;
			T3 += T4;
			// z3 needs z2.
			// For z.b_.a_ = z3.
			Fp2::add(t0, z2, z4);
			Fp2Dbl::mod(z2, T3);
			Fp2::add(t1, x2, x4);
			Fp2Dbl::mulOpt2(T3, t0, t1);
			T3 -= D2;
			T3 -= D4;
			Fp2Dbl::mul_xi(T4, T3);
			Fp2Dbl::mulOpt2(T3, z3, x0);
			S1 += T3;
			T4 += T3;
			Fp2Dbl::mod(z3, T4);
			// For z.b_.b_ = z4.
			Fp2Dbl::mulOpt2(T3, z5, x2);
			S1 += T3;
			Fp2Dbl::mul_xi(T4, T3);
			Fp2::add(t0, x0, x4);
			Fp2Dbl::mulOpt2(T3, t2, t0);
			T3 -= D0;
			T3 -= D4;
			T4 += T3;
			Fp2Dbl::mod(z4, T4);
			// For z.b_.c_ = z5.
			Fp2::add(t0, x0, x2);
			t0 += x4;
			Fp2Dbl::mulOpt2(T3, s0, t0);
			T3 -= S1;
			Fp2Dbl::mod(z5, T3);
		}

		/*
			z = cv2 * cv3,
			position:0  1   2      3   4   5
			cv2 = (l00, 0, l02) + (0, l11, 0)*w
			cv3 = (l00, 0, l02) + (0, l11, 0)*w
			these are represented as:
			(cv*.a_, cv*.b_, cv*.c_) = (l00, l11, l02)
		*/
		/*
			Operation Count:

			6  * Fp2Dbl::mulOpt2
			5  * Fp2Dbl::mod
			6  * Fp2::add/sub
			7  * Fp2Dbl::add/sub == 7 * (2 * Fp2::add/sub) == 14 * Fp2::add/sub
			3  * Fp2Dbl::mul_xi == 3 * (2 * Fp2::add/sub)  == 6  * Fp2::add/sub

			Total:

			6  * Fp2Dbl::mulOpt2
			5  * Fp2Dbl::mod
			26 * Fp2::add/sub
			call:2
		*/
		static void mul_Fp2_024_Fp2_024(Fp12T& z, const Fp6& cv2, const Fp6& cv3)
		{
			Fp2& z0 = z.a_.a_;
			Fp2& z1 = z.a_.b_;
			Fp2& z2 = z.a_.c_;
			Fp2& z3 = z.b_.a_;
			Fp2& z4 = z.b_.b_;
			Fp2& z5 = z.b_.c_;
			const Fp2& x0 = cv2.a_;
			const Fp2& x2 = cv2.c_;
			const Fp2& x4 = cv2.b_;
			const Fp2& y0 = cv3.a_;
			const Fp2& y2 = cv3.c_;
			const Fp2& y4 = cv3.b_;
			Fp2Dbl T00, T22, T44, T02, T24, T40;
			Fp2Dbl::mulOpt2(T00, x0, y0);
			Fp2Dbl::mulOpt2(T22, x2, y2);
			Fp2Dbl::mulOpt2(T44, x4, y4);
			Fp2::add(z0, x0, x2);
			Fp2::add(z1, y0, y2);
			Fp2Dbl::mulOpt2(T02, z0, z1);
			T02 -= T00;
			T02 -= T22;
			Fp2Dbl::mod(z2, T02);
			Fp2::add(z0, x2, x4);
			Fp2::add(z1, y2, y4);
			Fp2Dbl::mulOpt2(T24, z0, z1);
			T24 -= T22;
			T24 -= T44;
			Fp2Dbl::mul_xi(T02, T24);
			Fp2Dbl::mod(z3, T02);
			Fp2::add(z0, x4, x0);
			Fp2::add(z1, y4, y0);
			Fp2Dbl::mulOpt2(T40, z0, z1);
			T40 -= T00;
			T40 -= T44;
			Fp2Dbl::mod(z4, T40);
			Fp2Dbl::mul_xi(T02, T22);
			Fp2Dbl::mod(z1, T02);
			Fp2Dbl::mul_xi(T02, T44);
			T02 += T00;
			Fp2Dbl::mod(z0, T02);
			z5.clear();
		}

		static void mod(Fp12T& z, Dbl& x)
		{
			Fp6Dbl::mod(z.a_, x.a_);
			Fp6Dbl::mod(z.b_, x.b_);
		}
	};
};

template<class Fp6>
void (*Fp12T<Fp6>::square)(Fp12T& x) = &(Fp12T<Fp6>::squareC);

template<class Fp6>
void (*Fp12T<Fp6>::Dbl::mul_Fp2_024)(Fp12T& x, const Fp6& y) = &(Fp12T<Fp6>::Dbl::mul_Fp2_024C);

template<class Fp6>
void (*Fp12T<Fp6>::mul)(Fp12T& z, const Fp12T& x, const Fp12T& y) = &(Fp12T<Fp6>::mulC);

template<class T>
struct CompressT {
	typedef T Fp2;
	typedef typename Fp2::Fp Fp;
	typedef ParamT<Fp2> Param;
	typedef typename Fp2::Dbl Fp2Dbl;
	typedef Fp6T<Fp2> Fp6;
	typedef Fp12T<Fp6> Fp12;
	enum { N = 4 };

	Fp12& z_; // must be top for asm !!!
	Fp2& g1_;
	Fp2& g2_;
	Fp2& g3_;
	Fp2& g4_;
	Fp2& g5_;

	// z is output area
	CompressT(Fp12& z, const Fp12& x)
		: z_(z)
		, g1_(z.getFp2()[4])
		, g2_(z.getFp2()[3])
		, g3_(z.getFp2()[2])
		, g4_(z.getFp2()[1])
		, g5_(z.getFp2()[5])
	{
		g2_ = x.getFp2()[3];
		g3_ = x.getFp2()[2];
		g4_ = x.getFp2()[1];
		g5_ = x.getFp2()[5];
	}
	CompressT(Fp12& z, const CompressT& c)
		: z_(z)
		, g1_(z.getFp2()[4])
		, g2_(z.getFp2()[3])
		, g3_(z.getFp2()[2])
		, g4_(z.getFp2()[1])
		, g5_(z.getFp2()[5])
	{
		g2_ = c.g2_;
		g3_ = c.g3_;
		g4_ = c.g4_;
		g5_ = c.g5_;
	}

	friend std::ostream& operator<<(std::ostream& os, const CompressT& x)
	{
		os << "C[" << x.g2_ << ",\n" << x.g3_ << ",\n" << x.g4_ << ",\n" << x.g5_ << ",\n" << "]";
		return os;
	}

private:
	void decompressBeforeInv(Fp2& nume, Fp2& denomi) const
	{
		assert(&nume != &denomi);

		if (g2_.isZero()) {
			Fp2::add(nume, g4_, g4_);
			nume *= g5_;
			denomi = g3_;
		} else {
			Fp2 t;
			Fp2::square(nume, g5_);
			Fp2::mul_xi(denomi, nume);
			Fp2::square(nume, g4_);
			Fp2::sub(t, nume, g3_);
			t += t;
			t += nume;
			Fp2::add(nume, denomi, t);
			Fp2::divBy4(nume, nume);
			denomi = g2_;
		}
	}

	// output to z
	void decompressAfterInv()
	{
		Fp2& g0 = z_.getFp2()[0];
		Fp2 t0, t1;
		// Compute g0.
		Fp2::square(t0, g1_);
		Fp2::mul(t1, g3_, g4_);
		t0 -= t1;
		t0 += t0;
		t0 -= t1;
		Fp2::mul(t1, g2_, g5_);
		t0 += t1;
		Fp2::mul_xi(g0, t0);
		g0.a_ += Param::i1;
	}

public:
	// not used
	void decompress()
	{
		Fp2 nume, denomi;
		decompressBeforeInv(nume, denomi);
		denomi.inverse();
		g1_ = nume * denomi; // g1 is recoverd.
		decompressAfterInv();
	}

	/*
		2275clk * 186 = 423Kclk QQQ
	*/
	static void squareC(CompressT& z)
	{
		Fp2 t0, t1, t2;
		Fp2Dbl T0, T1, T2, T3;
		Fp2Dbl::square(T0, z.g4_);
		Fp2Dbl::square(T1, z.g5_);
		// # 7
		Fp2Dbl::mul_xi(T2, T1);
		// # 8
		T2 += T0;
		// # 9
		Fp2Dbl::mod(t2, T2);
		// # 1
		Fp2::add(t0, z.g4_, z.g5_);
		Fp2Dbl::square(T2, t0);
		// # 2
		T0 += T1;
//		Fp2Dbl::addNC(T0, T0, T1); // QQQ : OK?
		T2 -= T0;
		// # 3
		Fp2Dbl::mod(t0, T2);
		Fp2::add(t1, z.g2_, z.g3_);
		Fp2Dbl::square(T3, t1);
		Fp2Dbl::square(T2, z.g2_);
		// # 4
		Fp2::mul_xi(t1, t0);
#if 1 // RRR
		Fp::_3z_add_2xC(z.g2_.a_, t1.a_);
		Fp::_3z_add_2xC(z.g2_.b_, t1.b_);
#else
		// # 5
		z.g2_ += t1;
		z.g2_ += z.g2_;
		// # 6
		z.g2_ += t1;
#endif
		Fp2::sub(t1, t2, z.g3_);
		t1 += t1;
		// # 11 !!!!
		Fp2Dbl::square(T1, z.g3_);
		// # 10 !!!!
		Fp2::add(z.g3_, t1, t2);
		// # 12
		Fp2Dbl::mul_xi(T0, T1);
		// # 13
		T0 += T2;
//		Fp2Dbl::addNC(T0, T0, T2); // QQQ : OK?
		// # 14
		Fp2Dbl::mod(t0, T0);
		Fp2::sub(z.g4_, t0, z.g4_);
		z.g4_ += z.g4_;
		// # 15
		z.g4_ += t0;
		// # 16
		Fp2Dbl::addNC(T2, T2, T1);
		T3 -= T2;
		// # 17
		Fp2Dbl::mod(t0, T3);
#if 1 // RRR
		Fp::_3z_add_2xC(z.g5_.a_, t0.a_);
		Fp::_3z_add_2xC(z.g5_.b_, t0.b_);
#else
		z.g5_ += t0;
		z.g5_ += z.g5_;
		z.g5_ += t0; // # 18
#endif
	}
	static void square_nC(CompressT& z, int n)
	{
		for (int i = 0; i < n; i++) {
			squareC(z);
		}
	}

	/*
		Exponentiation over compression for:
		z = x^Param::z.abs()
	*/
	static void fixed_power(Fp12& z, const Fp12& x)
	{
#if 0
		z = power(x, Param::z.abs());
#else
		assert(&z != &x);
		Fp12 d62;
		Fp2 c55nume, c55denomi, c62nume, c62denomi;
		CompressT c55(z, x);
		CompressT::square_n(c55, 55); // 106k
		c55.decompressBeforeInv(c55nume, c55denomi);
		CompressT c62(d62, c55);
		CompressT::square_n(c62, 62 - 55); // 13.6k
		c62.decompressBeforeInv(c62nume, c62denomi);
		Fp2 acc;
		Fp2::mul(acc, c55denomi, c62denomi);
		acc.inverse();
		Fp2 t;
		Fp2::mul(t, acc, c62denomi);
		Fp2::mul(c55.g1_, c55nume, t);
		c55.decompressAfterInv(); // 1.1k
		Fp2::mul(t, acc, c55denomi);
		Fp2::mul(c62.g1_, c62nume, t);
		c62.decompressAfterInv();
		z *= x; // 6.5k
		z *= d62;
#endif
	}
	static void (*square_n)(CompressT& z, int n);
private:
	CompressT(const CompressT&);
	void operator=(const CompressT&);
};

template<class Fp2>
void (*CompressT<Fp2>::square_n)(CompressT&, int) = &(CompressT<Fp2>::square_nC);

namespace ecop {

template<class FF>
inline void copy(FF* out, const FF* in)
{
	out[0] = in[0];
	out[1] = in[1];
	out[2] = in[2];
}

/*
	@memo Jacobian coordinates: Y^2 = X^3 + b*Z^6
*/
template<class Fp>
inline bool isOnECJac3(const Fp* P)
{
	typedef Fp2T<Fp> Fp2;
	typedef ParamT<Fp2> Param;
	if (P[2] == 0) return true;

	Fp Z6p_2;
	Fp::square(Z6p_2, P[2]);
	Fp::mul(Z6p_2, Z6p_2, P[2]);
	Fp::square(Z6p_2, Z6p_2);
	Z6p_2 *= Param::b;
	return P[1] * P[1] == P[0] * P[0] * P[0] + Z6p_2;
}

/*
	@memo Y^2=X^3+b
	Homogeneous.
*/
template<class Fp>
inline bool isOnECHom2(const Fp* P)
{
	typedef Fp2T<Fp> Fp2;
	typedef ParamT<Fp2> Param;
	return P[1] * P[1] == P[0] * P[0] * P[0] + Param::b;
}

/*
	@memo Y^2=X^3+b
	Homogeneous.
*/
template<class Fp>
inline bool isOnECHom3(const Fp* P)
{
	typedef Fp2T<Fp> Fp2;
	typedef ParamT<Fp2> Param;
	if (P[2] == 0) return true;

	Fp ZZZ;
	Fp::square(ZZZ, P[2]);
	Fp::mul(ZZZ, ZZZ, P[2]);
	ZZZ *= Param::b;
	return P[1] * P[1] * P[2] == P[0] * P[0] * P[0] + ZZZ;
}

/*
	@memo Y^2=X^3+b/xi
*/
template<class Fp>
inline bool isOnTwistECJac3(const Fp2T<Fp>* P)
{
	typedef Fp2T<Fp> Fp2;
	typedef ParamT<Fp2> Param;

	if (P[2] == 0) return true;
	Fp2 Z6p;
	Fp2::square(Z6p, P[2]);
	Fp2::mul(Z6p, Z6p, P[2]);
	Fp2::square(Z6p, Z6p);
	return P[1] * P[1] == P[0] * P[0] * P[0] + Param::b_invxi * Z6p;
}

/*
	@memo Y^2=X^3+b/xi
	Homogeneous.
*/
template<class Fp>
inline bool isOnTwistECHom2(const Fp2T<Fp>* P)
{
	typedef Fp2T<Fp> Fp2;
	typedef ParamT<Fp2> Param;
	return P[1] * P[1] == (P[0] * P[0] * P[0] + Param::b_invxi);
}

/*
	@memo Y^2=X^3+b/xi
	Homogeneous.
*/
template<class Fp>
inline bool isOnTwistECHom3(const Fp2T<Fp>* P)
{
	typedef Fp2T<Fp> Fp2;
	typedef ParamT<Fp2> Param;
	if (P[2] == 0) return true;
	return P[1] * P[1] * P[2] == (P[0] * P[0] * P[0] + Param::b_invxi * P[2] * P[2] * P[2]);
}

/*
	For Jacobian coordinates
*/
template<class FF>
inline void NormalizeJac(FF* out, const FF* in)
{
	if (in[2] == 0) {
		out[0].clear();
		out[1].clear();
		out[2].clear();
	} else if (in[2] == 1) {
		copy(out, in);
	} else {
		FF A, AA, t0;
		A = in[2];
		A.inverse();
		FF::square(AA, A);
		FF::mul(out[0], in[0], AA);
		FF::mul(t0, AA, A);
		FF::mul(out[1], in[1], t0);
		out[2] = 1;
	}
}

/*
	For Homogeneous
*/
template<class FF>
inline void NormalizeHom(FF* out, const FF* in)
{
	if (in[2] == 0) {
		out[0].clear();
		out[1].clear();
		out[2].clear();
	} else if (in[2] == 1) {
		copy(out, in);
	} else {
		FF A = in[2];
		A.inverse();
		FF::mul(out[0], in[0], A);
		FF::mul(out[1], in[1], A);
		out[2] = 1;
	}
}

/*
	Jacobi coordinate
	(out[0], out[1], out[2]) = 2(in[0], in[1], in[2])
*/
template<class FF>
inline void ECDouble(FF* out, const FF* in)
{
	FF A, B, C, D, E, F, t0, t1, t2, t3, t4, t5, t6, t7, t8;
	FF::square(A, in[0]);
	FF::square(B, in[1]);
	FF::square(C, B);
	FF::add(t0, in[0], B);
	FF::square(t1, t0);
	FF::sub(t2, t1, A);
	FF::sub(t3, t2, C);
	FF::add(D, t3, t3);
	FF::add(E, A, A);
	FF::add(E, E, A);
	FF::square(F, E);
	FF::add(t4, D, D);
	FF::sub(out[0], F, t4);
	FF::sub(t5, D, out[0]);
	t6 = C; t6 += t6; t6 += t6; t6 += t6; // t6 = 8*C
	FF::mul(t7, E, t5);
	FF::mul(t8, in[1], in[2]);
	FF::sub(out[1], t7, t6);
	FF::add(out[2], t8, t8);
}

/*
	Jacobi coordinate
	(out[0], out[1], out[2]) = (a[0], a[1], a[2]) + (b[0], b[1], b[2])
*/
template<class FF>
inline void ECAdd(FF* out, const FF* a, const FF* b)
{
	if (a[2].isZero()) {
		copy(out, b);
		return;
	}
	if (b[2].isZero()) {
		copy(out, a);
		return;
	}
	FF Z1Z1, Z2Z2, U1, U2, t0, S1, t1, S2, H, t2, I, J, t3, r, V, t4, t5;
	FF t6, t7, t8, t9, t10, t11, t12, t13, t14;
	FF::square(Z1Z1, a[2]);
	FF::square(Z2Z2, b[2]);
	FF::mul(U1, a[0], Z2Z2);
	FF::mul(U2, b[0], Z1Z1);
	FF::mul(t0, b[2], Z2Z2);
	FF::mul(S1, a[1], t0);
	FF::mul(t1, a[2], Z1Z1);
	FF::mul(S2, b[1], t1);
	FF::sub(H, U2, U1);
	FF::sub(t3, S2, S1);

	if (H.isZero()) {
		if (t3.isZero()) {
			ECDouble(out, a);
		} else {
			out[2].clear();
		}
		return;
	}

	FF::add(t2, H, H);
	FF::square(I, t2);
	FF::mul(J, H, I);
	FF::add(r, t3, t3);
	FF::mul(V, U1, I);
	FF::square(t4, r);
	FF::add(t5, V, V);
	FF::sub(t6, t4, J);
	FF::sub(out[0], t6, t5);
	FF::sub(t7, V, out[0]);
	FF::mul(t8, S1, J);
	FF::add(t9, t8, t8);
	FF::mul(t10, r, t7);
	FF::sub(out[1], t10, t9);
	FF::add(t11, a[2], b[2]);
	FF::square(t12, t11);
	FF::sub(t13, t12, Z1Z1);
	FF::sub(t14, t13, Z2Z2);
	FF::mul(out[2], t14, H);
}

/*
	out = in * m
	@param out [out] Jacobi coord (out[0], out[1], out[2])
	@param in [in] Jacobi coord (in[0], in[1], in[2])
	@param m [in] scalar
	@note MSB first binary method.

	@note don't use Fp as INT
	the inner format of Fp is not compatible with mie::Vuint
*/
template<class FF, class INT>
inline void ScalarMult(FF* out, const FF* in, const INT& m)
{
	typedef typename mie::util::IntTag<INT> Tag;
	typedef typename Tag::value_type value_type;

	if (m == 0) {
		out[0].clear();
		out[1].clear();
		out[2].clear();
		return;
	}
	FF inCopy[3];
	if (out == in) {
		ecop::copy(inCopy, in);
		in = inCopy;
	}

	const int mSize = (int)Tag::getBlockSize(m);
	const int vSize = (int)sizeof(value_type) * 8;
	const value_type mask = value_type(1) << (vSize - 1);
	assert(mSize > 0); // if mSize == 0, it had been returned.
	/*
		Extract and process for MSB of most significant word.
	*/
	value_type v = Tag::getBlock(m, mSize - 1);
	int j = 0;

	while ((v != 0) && (!(v & mask))) {
		v <<= 1;
		++j;
	}

	v <<= 1;
	++j;
	ecop::copy(out, in);
	/*
		Process for most significant word.
	*/
	for (; j != vSize; ++j, v <<= 1) {
		ECDouble(out, out);
		if (v & mask) {
			ECAdd(out, out, in);
		}
	}

	/*
		Process for non most significant words.
	*/
	for (int i = mSize - 2; i >= 0; --i) {
		v = Tag::getBlock(m, i);
		for (j = 0; j != vSize; ++j, v <<= 1) {
			ECDouble(out, out);
			if (v & mask) {
				ECAdd(out, out, in);
			}
		}
	}
}

template<class Fp>
void FrobEndOnTwist_1(Fp2T<Fp>* Q, const Fp2T<Fp>* P)
{
	typedef Fp2T<Fp> Fp2;
	typedef ParamT<Fp2> Param;
	// applying Q[0] <- P[0]^q
#ifdef BN_SUPPORT_SNARK
	Q[0].a_ = P[0].a_;
	Fp::neg(Q[0].b_, P[0].b_);

	// Q[0] *= xi^((p-1)/3)
	Q[0] *= Param::gammar[1];

	// applying Q[1] <- P[1]^q
	Q[1].a_ = P[1].a_;
	Fp::neg(Q[1].b_, P[1].b_);

	// Q[1] *= xi^((p-1)/2)
	Q[1] *= Param::gammar[2];
#else
	Q[0].a_ = P[0].a_;
	Fp::neg(Q[0].b_, P[0].b_);
	Fp2::mul_Fp_1(Q[0], Param::W2p.b_);
	Q[1].a_ = P[1].a_;
	Fp::neg(Q[1].b_, P[1].b_);
	Q[1] *= Param::W3p;
#endif
}

template<class Fp>
void FrobEndOnTwist_2(Fp2T<Fp>* Q, const Fp2T<Fp>* P)
{
#ifdef BN_SUPPORT_SNARK
	Fp2T<Fp> scratch[2];
	FrobEndOnTwist_1(scratch, P);
	FrobEndOnTwist_1(Q, scratch);
#else
	typedef Fp2T<Fp> Fp2;
	typedef ParamT<Fp2> Param;
	Fp2::mul_Fp_0(Q[0], P[0], Param::Z);
	Fp2::neg(Q[1], P[1]);
#endif
}

template<class Fp>
void FrobEndOnTwist_8(Fp2T<Fp>* Q, const Fp2T<Fp>* P)
{
#ifdef BN_SUPPORT_SNARK
	Fp2T<Fp> scratch2[2], scratch4[2], scratch6[2];
	FrobEndOnTwist_2(scratch2, P);
	FrobEndOnTwist_2(scratch4, scratch2);
	FrobEndOnTwist_2(scratch6, scratch4);
	FrobEndOnTwist_2(Q, scratch6);
#else
	typedef Fp2T<Fp> Fp2;
	typedef ParamT<Fp2> Param;
	Fp2::mul_Fp_0(Q[0], P[0], Param::Z);
	Q[1] = P[1];
#endif
}

} // namespace ecop

/*
	calc optimal ate pairing
	@param f [out] e(Q, P)
	@param Q [in] affine coord. (Q[0], Q[1])
	@param P [in] affine coord. (P[0], P[1])
	@note not defined for infinity point
*/
template<class Fp>
void opt_atePairing(Fp12T<Fp6T<Fp2T<Fp> > >& f, const Fp2T<Fp> Q[2], const Fp P[2])
{
	typedef Fp2T<Fp> Fp2;
	typedef ParamT<Fp2> Param;
	typedef Fp6T<Fp2> Fp6;
	typedef Fp12T<Fp6> Fp12;
	Fp2 T[3];
	T[0] = Q[0];
	T[1] = Q[1];
	T[2] = Fp2(1);
	Fp2 Qneg[2];
	if (Param::useNAF) {
		Qneg[0] = Q[0];
		Fp2::neg(Qneg[1], Q[1]);
	}
	// at 1.
	Fp6 d;
	Fp6::pointDblLineEval(d, T, P);
	Fp6 e;
	assert(Param::siTbl[1] == 1);
	Fp6::pointAddLineEval(e, T, Q, P);
	Fp12::Dbl::mul_Fp2_024_Fp2_024(f, d, e);
	// loop from 2.
	Fp6 l;
	// 844kclk
	for (size_t i = 2; i < Param::siTbl.size(); i++) {
		// 3.6k x 63
		Fp6::pointDblLineEval(l, T, P);
		// 4.7k x 63
		Fp12::square(f);
		// 4.48k x 63
		Fp12::Dbl::mul_Fp2_024(f, l);

		if (Param::siTbl[i] > 0) {
			// 9.8k x 3
			// 5.1k
			Fp6::pointAddLineEval(l, T, Q, P);
			Fp12::Dbl::mul_Fp2_024(f, l);
		}
		else if (Param::siTbl[i] < 0) {
			Fp6::pointAddLineEval(l, T, Qneg, P);
			Fp12::Dbl::mul_Fp2_024(f, l);
		}
	}

	// addition step
	Fp2 Q1[2];
	ecop::FrobEndOnTwist_1(Q1, Q);
	Fp2 Q2[2];
#ifdef BN_SUPPORT_SNARK
	ecop::FrobEndOnTwist_2(Q2, Q);
	Fp2::neg(Q2[1], Q2[1]);
#else
	ecop::FrobEndOnTwist_8(Q2, Q);
	// @memo z < 0
	Fp6::neg(f.b_, f.b_);
	Fp2::neg(T[1], T[1]);
#endif
	Fp12 ft;
	Fp6::pointAddLineEval(d, T, Q1, P); // 5k
	Fp6::pointAddLineEval(e, T, Q2, P); // 5k
	Fp12::Dbl::mul_Fp2_024_Fp2_024(ft, d, e); // 2.7k
	Fp12::mul(f, f, ft); // 6.4k
	// final exponentiation
	f.final_exp();
}

/*
	opt_atePairingJac is a wrapper function of opt_atePairing
	@param f [out] e(Q, P)
	@param Q [in] Jacobi coord. (_Q[0], _Q[1], _Q[2])
	@param _P [in] Jacobi coord. (_P[0], _P[1], _P[2])
	output : e(Q, P)
*/
template<class Fp>
void opt_atePairingJac(Fp12T<Fp6T<Fp2T<Fp> > >& f, const Fp2T<Fp> _Q[3], const Fp _P[3])
{
	if (_Q[2] == 0 || _P[2] == 0) {
		f = 1;
		return;
	}

	Fp2T<Fp> Q[3];
	Fp P[3];
	ecop::NormalizeJac(Q, _Q);
	ecop::NormalizeJac(P, _P);
	opt_atePairing(f, Q, P);
}

#ifdef _MSC_VER
	#pragma warning(push)
	#pragma warning(disable : 4127) /* const condition */
#endif

template<class T>
class EcT {
public:
	mutable T p[3];
	EcT() {}
	EcT(const T& x, const T& y, bool verify = true)
	{
		set(x, y, verify);
	}
	EcT(const T& x, const T& y, const T& z, bool verify = true)
	{
		set(x, y, z, verify);
	}
	void normalize() const
	{
		if (isZero() || p[2] == 1) return;
		T r;
		r = p[2];
		r.inverse();
		T::square(p[2], r);
		p[0] *= p[2];
		r *= p[2];
		p[1] *= r;
		p[2] = 1;
	}

	bool isValid() const;

	void set(const T& x, const T& y, bool verify = true)
	{
		p[0] = x;
		p[1] = y;
		p[2] = 1;
		if (verify && !isValid()) {
			throw std::runtime_error("set(x, y) : bad point");
		}
	}
	void set(const T& x, const T& y, const T& z, bool verify = true)
	{
		p[0] = x;
		p[1] = y;
		p[2] = z;
		if (verify && !isValid()) {
			throw std::runtime_error("set(x, y, z) : bad point");
		}
	}
	void clear()
	{
		p[0].clear();
		p[1].clear();
		p[2].clear();
	}

	static inline void dbl(EcT& R, const EcT& P)
	{
		ecop::ECDouble(R.p, P.p);
	}
	static inline void add(EcT& R, const EcT& P, const EcT& Q)
	{
		ecop::ECAdd(R.p, P.p, Q.p);
	}
	static inline void sub(EcT& R, const EcT& P, const EcT& Q)
	{
		EcT negQ;
		neg(negQ, Q);
		add(R, P, negQ);
	}
	static inline void neg(EcT& R, const EcT& P)
	{
		R.p[0] = P.p[0];
		T::neg(R.p[1], P.p[1]);
		R.p[2] = P.p[2];
	}
	template<class N>
	static inline void mul(EcT& R, const EcT& P, const N& y)
	{
		ecop::ScalarMult(R.p, P.p, y);
	}
	template<class N>
	EcT& operator*=(const N& y) { mul(*this, *this, y); return *this; }
	template<class N>
	EcT operator*(const N& y) const { EcT c; mul(c, *this, y); return c; }
	bool operator==(const EcT& rhs) const
	{
		normalize();
		rhs.normalize();
		if (isZero()) {
			if (rhs.isZero()) return true;
			return false;
		}
		if (rhs.isZero()) return false;
		return p[0] == rhs.p[0] && p[1] == rhs.p[1];
	}
	bool operator!=(const EcT& rhs) const
	{
		return !operator==(rhs);
	}
	bool isZero() const
	{
		return p[2].isZero();
	}
	friend inline std::ostream& operator<<(std::ostream& os, const EcT& self)
	{
		if (self.isZero()) {
			return os << '0';
		} else {
			self.normalize();
			return os << self.p[0].toString(16) << '_' << self.p[1].toString(16);
		}
	}
	friend inline std::istream& operator>>(std::istream& is, EcT& self)
	{
		std::string str;
		is >> str;
		if (str == "0") {
			self.clear();
		} else {
			self.p[2] = 1;
			size_t pos = str.find('_');
			if (pos == std::string::npos) {
				throw std::runtime_error("operator>>:bad format");
			}
			str[pos] = '\0';
			self.p[0].set(&str[0]);
			self.p[1].set(&str[pos + 1]);
		}
		return is;
	}
	EcT& operator+=(const EcT& rhs) { add(*this, *this, rhs); return *this; }
	EcT& operator-=(const EcT& rhs) { sub(*this, *this, rhs); return *this; }
	friend EcT operator+(const EcT& a, const EcT& b) { EcT c; EcT::add(c, a, b); return c; }
	friend EcT operator-(const EcT& a, const EcT& b) { EcT c; EcT::sub(c, a, b); return c; }
};

#ifdef _MSC_VER
	#pragma warning(pop)
#endif

typedef mie::Fp Fp;
typedef Fp::Dbl FpDbl;
typedef Fp2T<Fp> Fp2;
typedef Fp2::Dbl Fp2Dbl;
typedef ParamT<Fp2> Param;
typedef Fp6T<Fp2> Fp6;
typedef Fp6::Dbl Fp6Dbl;
typedef Fp12T<Fp6> Fp12;
typedef Fp12::Dbl Fp12Dbl;
typedef CompressT<Fp2> Compress;

typedef EcT<Fp2> Ec2;
typedef EcT<Fp> Ec1;

inline void opt_atePairing(Fp12& f, const Ec2& Q, const Ec1& P)
{
	Q.normalize();
	P.normalize();
	if (Q.isZero() || P.isZero()) {
		f = 1;
		return;
	}
	opt_atePairing<Fp>(f, Q.p, P.p);
}

template<>
inline bool EcT<Fp2>::isValid() const
{
	return ecop::isOnTwistECJac3(p);
}

template<>
inline bool EcT<Fp>::isValid() const
{
	return ecop::isOnECJac3(p);
}

/*
	see https://github.com/herumi/ate-pairing/blob/master/test/bn.cpp
*/
namespace components {

/*
	inQ[3] : permit not-normalized
*/
inline void precomputeG2(std::vector<Fp6>& coeff, Fp2 Q[3], const Fp2 inQ[3])
{
	coeff.clear();
	bn::ecop::NormalizeJac(Q, inQ);

	Fp2 T[3];
	T[0] = Q[0];
	T[1] = Q[1];
	T[2] = Fp2(1);
	Fp2 Qneg[2];
	if (Param::useNAF) {
		Qneg[0] = Q[0];
		Fp2::neg(Qneg[1], Q[1]);
	}

	Fp6 d;
	Fp6::pointDblLineEvalWithoutP(d, T);
	coeff.push_back(d);

	Fp6 e;
	assert(Param::siTbl[1] == 1);
	Fp6::pointAddLineEvalWithoutP(e, T, Q);
	coeff.push_back(e);

	bn::Fp6 l;
	// 844kclk
	for (size_t i = 2; i < Param::siTbl.size(); i++) {
		Fp6::pointDblLineEvalWithoutP(l, T);
		coeff.push_back(l);

		if (Param::siTbl[i] > 0) {
			Fp6::pointAddLineEvalWithoutP(l, T, Q);
			coeff.push_back(l);
		}
		else if (Param::siTbl[i] < 0) {
			Fp6::pointAddLineEvalWithoutP(l, T, Qneg);
			coeff.push_back(l);
		}
	}

	// addition step
	Fp2 Q1[2];
	bn::ecop::FrobEndOnTwist_1(Q1, Q);
	Fp2 Q2[2];
#ifdef BN_SUPPORT_SNARK
	bn::ecop::FrobEndOnTwist_2(Q2, Q);
	Fp2::neg(Q2[1], Q2[1]);
#else
	// @memo z < 0
	ecop::FrobEndOnTwist_8(Q2, Q);
	Fp2::neg(T[1], T[1]);
#endif

	Fp6::pointAddLineEvalWithoutP(d, T, Q1);
	coeff.push_back(d);

	Fp6::pointAddLineEvalWithoutP(e, T, Q2);
	coeff.push_back(e);
}

/*
	precP : normalized point
*/
inline void millerLoop(Fp12& f, const std::vector<Fp6>& Qcoeff, const Fp precP[2])
{
	assert(Param::siTbl[1] == 1);
	size_t idx = 0;

	Fp6 d = Qcoeff[idx];
	Fp6::mulFp6_24_Fp_01(d, precP);
	idx++;

	Fp6 e = Qcoeff[idx];
	Fp6::mulFp6_24_Fp_01(e, precP);
	Fp12::Dbl::mul_Fp2_024_Fp2_024(f, d, e);

	idx++;
	bn::Fp6 l;
	for (size_t i = 2; i < Param::siTbl.size(); i++) {
		l = Qcoeff[idx];
		idx++;
		Fp12::square(f);
		Fp6::mulFp6_24_Fp_01(l, precP);

		Fp12::Dbl::mul_Fp2_024(f, l);

		if (Param::siTbl[i]) {
			l = Qcoeff[idx];
			idx++;
			Fp6::mulFp6_24_Fp_01(l, precP);
			Fp12::Dbl::mul_Fp2_024(f, l);
		}
	}

#ifndef BN_SUPPORT_SNARK
	// @memo z < 0
	Fp6::neg(f.b_, f.b_);
#endif
	Fp12 ft;

	d = Qcoeff[idx];
	Fp6::mulFp6_24_Fp_01(d, precP);
	idx++;

	e = Qcoeff[idx];
	Fp6::mulFp6_24_Fp_01(e, precP);

	Fp12::Dbl::mul_Fp2_024_Fp2_024(ft, d, e);
	Fp12::mul(f, f, ft);
}

inline void millerLoop2(Fp12& f, const std::vector<Fp6>& Q1coeff, const Fp precP1[2],
	const std::vector<Fp6>& Q2coeff, const Fp precP2[2])
{
	assert(Param::siTbl[1] == 1);
	size_t idx = 0;

	Fp6 d1 = Q1coeff[idx];
	Fp6::mulFp6_24_Fp_01(d1, precP1);
	Fp6 d2 = Q2coeff[idx];
	Fp6::mulFp6_24_Fp_01(d2, precP2);
	idx++;

	Fp12 f1;
	Fp6 e1 = Q1coeff[idx];
	Fp6::mulFp6_24_Fp_01(e1, precP1);
	Fp12::Dbl::mul_Fp2_024_Fp2_024(f1, d1, e1);

	Fp12 f2;
	Fp6 e2 = Q2coeff[idx];
	Fp6::mulFp6_24_Fp_01(e2, precP2);
	Fp12::Dbl::mul_Fp2_024_Fp2_024(f2, d2, e2);
	Fp12::mul(f, f1, f2);

	idx++;
	bn::Fp6 l1, l2;
	for (size_t i = 2; i < Param::siTbl.size(); i++) {
		l1 = Q1coeff[idx];
		l2 = Q2coeff[idx];
		idx++;
		Fp12::square(f);

		Fp6::mulFp6_24_Fp_01(l1, precP1);
		Fp6::mulFp6_24_Fp_01(l2, precP2);

		Fp12::Dbl::mul_Fp2_024_Fp2_024(f1, l1, l2);
		Fp12::mul(f, f, f1);

		if (Param::siTbl[i]) {
			l1 = Q1coeff[idx];
			l2 = Q2coeff[idx];
			idx++;
			Fp6::mulFp6_24_Fp_01(l1, precP1);
			Fp6::mulFp6_24_Fp_01(l2, precP2);
			Fp12::Dbl::mul_Fp2_024_Fp2_024(f1, l1, l2);
			Fp12::mul(f, f, f1);
		}
	}

#ifndef BN_SUPPORT_SNARK
	// @memo z < 0
	Fp6::neg(f.b_, f.b_);
#endif

	d1 = Q1coeff[idx];
	Fp6::mulFp6_24_Fp_01(d1, precP1);

	d2 = Q2coeff[idx];
	Fp6::mulFp6_24_Fp_01(d2, precP2);
	idx++;

	e1 = Q1coeff[idx];
	Fp6::mulFp6_24_Fp_01(e1, precP1);

	e2 = Q2coeff[idx];
	Fp6::mulFp6_24_Fp_01(e2, precP2);

	Fp12::Dbl::mul_Fp2_024_Fp2_024(f1, d1, e1);
	Fp12::Dbl::mul_Fp2_024_Fp2_024(f2, d2, e2);
	Fp12::mul(f, f, f1);
	Fp12::mul(f, f, f2);
}

} // components

} // bn
