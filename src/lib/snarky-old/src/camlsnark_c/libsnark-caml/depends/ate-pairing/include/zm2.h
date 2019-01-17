#pragma once

/**
	Fp : finite field with characteristic 254bit prime
	t = - 2^62 - 2^55 + 2^0
	p = 36*t*t*t*t + 36*t*t*t + 24*t*t + 6*t + 1
*/
#include "zm.h"
#ifdef MIE_ATE_USE_GMP
#include <gmpxx.h>
#endif

namespace mie {

class Fp : public local::addsubmul<Fp,
					 local::comparable<Fp,
					 local::hasNegative<Fp,
					 local::inversible<Fp> > > > {
public:
	typedef mie::Unit value_type;

	/*
		double size of Fp
	*/
	enum {
		N = 32 / sizeof(Unit)
	};
	Fp()
	{
	}
	MIE_FORCE_INLINE Fp(int x)
	{
		set(x);
	}
	MIE_FORCE_INLINE explicit Fp(const std::string& str)
	{
		set(str);
	}
	MIE_FORCE_INLINE explicit Fp(const mie::Unit *x)
	{
		std::copy(x, x + N, v_);
	}
	Fp(const mie::Vuint& rhs)
	{
		set(rhs);
	}
	void set(int x)
	{
		if (x == 0) {
			clear();
		} else if (x == 1) {
			const mie::Vuint& r = getMontgomeryR();
			assert(r.size() == N);
			std::copy(&r[0], &r[0] + N, v_);
		} else if (x > 0) {
			v_[0] = x;
			std::fill(v_ + 1, v_ + N, 0);
			mul(*this, *this, montgomeryR2_);
		} else {
			v_[0] = -x;
			std::fill(v_ + 1, v_ + N, 0);
			mul(*this, *this, montgomeryR2_);
			neg(*this, *this);
		}
	}
	void set(const std::string& str)
	{
		set(mie::Vuint(str));
	}
	void set(const mie::Vuint& x)
	{
		assert(x < getModulo());
		mie::Vuint y(x);
//		count++;std::cout << "count=" << count << ", x=" << x << std::endl;
		y *= getMontgomeryR();
		y %= getModulo();
		setDirect(*this, y);
	}
	static inline int compare(const Fp& x, const Fp& y)
	{
		return mie::local::PrimitiveFunction::compare(&x[0], N, &y[0], N);
	}
	static void (*add)(Fp& out, const Fp& x, const Fp& y);

	// add without mod
	static void (*addNC)(Fp& out, const Fp& x, const Fp& y);
	static void (*subNC)(Fp& out, const Fp& x, const Fp& y);
	static void (*shr1)(Fp& out, const Fp& x);
	static void (*shr2)(Fp& out, const Fp& x);

	static void (*sub)(Fp& out, const Fp& x, const Fp& y);
	static void (*neg)(Fp& out, const Fp& x);
	static void (*mul)(Fp& out, const Fp& x, const Fp& y);
	static int (*preInv)(Fp& r, const Fp& x);
	/*
		z = 3z + 2x
	*/
	static inline void _3z_add_2xC(Fp& z, const Fp& x)
	{
		addNC(z, z, x);
		addNC(z, z, z);
		addNC(z, z, x);
		fast_modp(z);
	}
	/*
		z = 2z + 3x
	*/
	static inline void _2z_add_3x(Fp& z, const Fp& x)
	{
		addNC(z, x, z);
		addNC(z, z, z);
		addNC(z, z, x);
		fast_modp(z);
	}

	inline friend std::ostream& operator<<(std::ostream& os, const Fp& x)
	{
		return os << x.toString(os.flags() & std::ios_base::hex ? 16 : 10);
	}
	inline friend std::istream& operator>>(std::istream& is, Fp& x)
	{
		std::string str;
		mie::local::getDigits(is, str);
		x.set(str);
		return is;
	}
	MIE_FORCE_INLINE bool isZero() const
	{
		Unit t = 0;
		for (size_t i = 0; i < N; i++) {
			t |= v_[i];
		}
		return t == 0;
	}
	MIE_FORCE_INLINE void clear()
	{
		std::fill(v_, v_ + N, 0);
	}
	static inline void fromMont(Fp& y, const Fp& x)
	{
		mul(y, x, one_);
	}
	static inline void toMont(Fp& y, const Fp& x)
	{
		mul(y, x, montgomeryR2_);
	}
	// return real low value
	Unit getLow() const
	{
		Fp t;
		fromMont(t, *this);
		return t.v_[0];
	}
	bool isOdd() const
	{
		return (getLow() & 1) != 0;
	}
	mie::Vuint get() const
	{
		Fp t;
		fromMont(t, *this);
		mie::Vuint ret(t.v_, N);
		return ret;
	}
	static inline void inv(Fp& out, const Fp& x)
	{
#ifdef MIE_USE_X64ASM
		Fp r;
		int k = preInv(r, x);
#else
		static const Fp p(&p_[0]);
		Fp u, v, r, s;
		u = p;
		v = x;
		r.clear();
		s.clear(); s[0] = 1; // s is real 1
		int k = 0;
		while (!v.isZero()) {
			if ((u[0] & 1) == 0) {
				shr1(u, u);
				addNC(s, s, s);
			} else if ((v[0] & 1) == 0) {
				shr1(v, v);
				addNC(r, r, r);
			} else if (v >= u) {
				subNC(v, v, u);
				addNC(s, s, r);
				shr1(v, v);
				addNC(r, r, r);
			} else {
				subNC(u, u, v);
				addNC(r, r, s);
				shr1(u, u);
				addNC(s, s, s);
			}
			k++;
		}
		if (r >= p) {
			subNC(r, r, p);
		}
		assert(!r.isZero());
		subNC(r, p, r);
#endif
		/*
			xr = 2^k
			R = 2^256
			get r2^(-k)R^2 = r 2^(512 - k)
		*/
		mul(out, r, invTbl_[k]);
	}
	void inverse()
	{
		inv(*this, *this);
	}

	static inline void divBy2(Fp &z, const Fp &x)
	{
		unsigned int i = x[0] & 0x1;
		shr1(z, x);
		addNC(z, z, halfTbl_[i]);
	}

	static inline void divBy4(Fp &z, const Fp &x)
	{
		unsigned int i = x[0] & 0x3;
		shr2(z, x);
		addNC(z, z, quarterTbl_[i]);
	}

	/* z <- z mod p for z in [0, 6p] */
	static inline void fast_modp(Fp &z)
	{
		uint64_t t = z.v_[3] >> 61;
		z -= getDirectP((int)t);
	}

	template<class T>
	static MIE_FORCE_INLINE void setDirect(Fp& out, const T& in)
	{
		const size_t n = in.size();
//		assert(n <= N);
		if (n < N) {
			std::copy(&in[0], &in[0] + n, out.v_);
			std::fill(out.v_ + n, out.v_ + N, 0);
		} else {
			// ignore in[i] for i >= N
			std::copy(&in[0], &in[0] + N, out.v_);
		}
	}
	std::string toString(int base = 10) const { return get().toString(base); }
	MIE_FORCE_INLINE const Unit& operator[](size_t i) const { return v_[i]; }
	MIE_FORCE_INLINE Unit& operator[](size_t i) { return v_[i]; }
	MIE_FORCE_INLINE size_t size() const { return N; }

	static void setModulo(const mie::Vuint& p, int mode, bool useMulx = true, bool definedBN_SUPPORT_SNARK =
#ifdef BN_SUPPORT_SNARK
		true
#else
		false
#endif
	);
	static inline const mie::Vuint& getModulo() { return p_; }
	static const Fp& getDirectP(int n); /* n = 0..6 */
	static inline const mie::Vuint& getMontgomeryR() { return montgomeryR_; }
private:
	MIE_ALIGN(16) Unit v_[N];
	static mie::Vuint p_;
	static mie::Fp invTbl_[512];
public:
	static mie::Fp *halfTbl_; // [2] = [0, 1/2 mod p]
private:
	static mie::Fp *quarterTbl_; // [4] = [0, 1/4, 2/4, 3/4]
	static mie::Vuint montgomeryR_; // 1 = 1r
	static mie::Vuint p_add1_div4_; // (p + 1) / 4
	static mie::Fp montgomeryR2_; // m(x, r^2) = xr ; x -> xr
	static mie::Fp one_; // 1
	// m(xr, r^(-2)r) = xr^(-1) ; xr -> xr^(-1)

	static void setTablesForDiv(const mie::Vuint& p);

public:
	static inline void square(Fp& out, const Fp& x) { mul(out, x, x); }
#ifdef MIE_ATE_USE_GMP
	static void toMpz(mpz_class& y, const Fp& x)
	{
		mpz_import(y.get_mpz_t(), N, -1, sizeof(Unit), 0, 0, x.v_);
	}
	static void fromMpz(Fp& y, const mpz_class& x)
	{
		size_t size;
		mpz_export(y.v_, &size, -1, sizeof(Unit), 0, 0, x.get_mpz_t());
		for (size_t i = size; i < N; i++) {
			y.v_[i] = 0;
		}
	}
#endif
	static bool squareRoot(Fp& y, const Fp& x)
	{
		Fp t;
		t = mie::power(x, p_add1_div4_);
		if (t * t != x) return false;
		y = t;
		return true;
	}

	struct Dbl : public local::addsubmul<Dbl,
		local::comparable<Dbl,
		local::hasNegative<Dbl> > > {
		enum {
			SIZE = sizeof(Unit) * N * 2
		};
		static MIE_FORCE_INLINE void setDirect(Dbl &out, const mie::Vuint &in)
		{
			const size_t n = in.size();
			if (n < N * 2) {
				std::copy(&in[0], &in[0] + n, out.v_);
				std::fill(out.v_ + n, out.v_ + N * 2, 0);
			} else {
				// ignore in[i] for i >= N * 2
				std::copy(&in[0], &in[0] + N * 2, out.v_);
			}
		}
		static MIE_FORCE_INLINE void setDirect(Dbl &out, const std::string &in)
		{
			mie::Vuint t(in);
			setDirect(out, t);
		}

		template<class T>
		void setDirect(const T &in) { setDirect(*this, in); }

		MIE_FORCE_INLINE void clear()
		{
			std::fill(v_, v_ + N * 2, 0);
		}

		Unit *ptr() { return v_; }
		const Unit *const_ptr() const { return v_; }
		mie::Vuint getDirect() const { return mie::Vuint(v_, N * 2); }
		MIE_FORCE_INLINE const Unit& operator[](size_t i) const { return v_[i]; }
		MIE_FORCE_INLINE Unit& operator[](size_t i) { return v_[i]; }
		MIE_FORCE_INLINE size_t size() const { return N * 2; }

		std::string toString(int base = 10) const
		{
			return ("Dbl(" + getDirect().toString(base) + ")");
		}
		friend inline std::ostream& operator<<(std::ostream& os, const Dbl& x)
		{
			return os << x.toString(os.flags() & std::ios_base::hex ? 16 : 10);
		}

		Dbl() {}
		explicit Dbl(const Fp &x)
		{
			mul(*this, x, montgomeryR2_);
		}
		explicit Dbl(const std::string &str) { setDirect(*this, str); }

		static inline int compare(const Dbl& x, const Dbl& y)
		{
			return mie::local::PrimitiveFunction::compare(&x[0], N * 2, &y[0], N * 2);
		}

		typedef void (uni_op)(Dbl &z, const Dbl &x);
		typedef void (bin_op)(Dbl &z, const Dbl &x, const Dbl &y);

		/*
			z = (x + y) mod px
		*/
		static bin_op *add;
		static bin_op *addNC;

		static uni_op *neg;

		/*
			z = (x - y) mod px
		*/
		static bin_op *sub;
		static bin_op *subNC;

		static void subOpt1(Dbl &z, const Dbl &x, const Dbl &y)
		{
			assert(&z != &x);
			assert(&z != &y);
			addNC(z, x, pNTbl_[1]);
			subNC(z, z, y);
		}

		/*
			z = x * y
		*/
		static void (*mul)(Dbl &z, const Fp &x, const Fp &y);

		/*
			z = MontgomeryReduction(x)
		*/
		static void (*mod)(Fp &z, const Dbl &x);

		/*
			x <- x mod pN
		*/
		static Dbl *pNTbl_; // [4];
	private:
			MIE_ALIGN(16) Unit v_[N * 2];
	};
};

namespace util {
template<>
struct IntTag<mie::Fp> {
	typedef size_t value_type;
	static inline value_type getBlock(const mie::Fp&, size_t)
	{
		err();
		return 0;
	}
	static inline size_t getBlockSize(const mie::Fp&)
	{
		err();
		return 0;
	}
	static inline void err()
	{
		printf("Use mie::Vuint intead of Fp for the 3rd parameter for ScalarMulti\n");
		exit(1);
	}
};

} // mie::util

} // mie
