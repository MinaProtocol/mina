#pragma once
/**
	Zm = Z/mZ field class (not optimzied)
	m : integer
*/
#include <vector>
#include <string>
#include <cassert>
#include <string>
#include <stdio.h>
#include <stdlib.h>
#include <sstream>
#include <iomanip>
#include <stdexcept>
#include <algorithm>
#include <iostream>

#ifndef MIE_ZM_VUINT_BIT_LEN
	// minimum 512
	#define MIE_ZM_VUINT_BIT_LEN (64 * 9)
#endif

#define MIE_USE_X64ASM

#ifdef _MSC_VER
	#include <intrin.h>
	#include <malloc.h>
#endif
#if !defined(_MSC_VER) || (_MSC_VER >= 1600)
	#include <stdint.h>
#else
	typedef unsigned __int64 uint64_t;
	typedef __int64 int64_t;
	typedef unsigned int uint32_t;
	typedef int int32_t;
#endif

#ifdef _MSC_VER
	#ifndef MIE_ALIGN
		#define MIE_ALIGN(x) __declspec(align(x))
	#endif
	#ifndef MIE_FORCE_INLINE
		#define MIE_FORCE_INLINE __forceinline
	#endif
	#ifndef MIE_ALLOCA_
		#define MIE_ALLOCA_(x) _alloca(x)
	#endif
#else
	#ifndef MIE_ALIGN
		#define MIE_ALIGN(x) __attribute__((aligned(16)))
	#endif
	#ifndef MIE_FORCE_INLINE
		#define MIE_FORCE_INLINE __attribute__((always_inline))
	#endif
	#ifndef MIE_ALLOCA_
		#define MIE_ALLOCA_(x) __builtin_alloca(x)
	#endif
#endif

namespace mie {

#if defined(_WIN64) || defined(__x86_64__)
	typedef uint64_t Unit;
	#define MIE_USE_UNIT64
#else
	typedef uint32_t Unit;
	#define MIE_USE_UNIT32
	#undef MIE_USE_X64ASM
#endif

static inline uint64_t make64(uint32_t H, uint32_t L)
{
	return ((uint64_t)H << 32) | L;
}

static inline void split64(uint32_t *H, uint32_t *L, uint64_t x)
{
	*H = uint32_t(x >> 32);
	*L = uint32_t(x);
}

namespace local {

inline std::istream& getDigits(std::istream& is, std::string& str, bool allowNegative = false)
{
	std::ios_base::fmtflags keep = is.flags();
	size_t pos = 0;
	char c;
	while (is >> c) {
		if (('0' <= c && c <= '9') /* digits */
		  || (pos == 1 && (str[0] == '0' && c == 'x')) /* 0x.. */
		  || ('a' <= c && c <= 'f') /* lowercase hex */
		  || ('A' <= c && c <= 'F') /* uppercase hex */
		  || (allowNegative && pos == 0 && c == '-')) { /* -digits */
			str.push_back(c);
			if (pos == 0) {
				is >> std::noskipws;
			}
			pos++;
		} else {
			is.unget();
			break;
		}
	}
	is.flags(keep);
	return is;
}


static inline void errExit(const std::string& msg = "")
{
	printf("err %s\n", msg.c_str());
	exit(1);
}

/*
	T must have compare, add, sub, mul
*/
template<class T>
struct Empty {};

template<class T, class E = Empty<T> >
struct comparable : E {
	MIE_FORCE_INLINE friend bool operator<(const T& x, const T& y) { return T::compare(x, y) < 0; }
	MIE_FORCE_INLINE friend bool operator>=(const T& x, const T& y) { return !operator<(x, y); }

	MIE_FORCE_INLINE friend bool operator>(const T& x, const T& y) { return T::compare(x, y) > 0; }
	MIE_FORCE_INLINE friend bool operator<=(const T& x, const T& y) { return !operator>(x, y); }
	MIE_FORCE_INLINE friend bool operator==(const T& x, const T& y) { return T::compare(x, y) == 0; }
	MIE_FORCE_INLINE friend bool operator!=(const T& x, const T& y) { return !operator==(x, y); }
};

template<class T, class E = Empty<T> >
struct addsubmul : E {
	template<class N>
	MIE_FORCE_INLINE T& operator+=(const N& rhs) { T::add(static_cast<T&>(*this), static_cast<T&>(*this), rhs); return static_cast<T&>(*this); }
	MIE_FORCE_INLINE T& operator-=(const T& rhs) { T::sub(static_cast<T&>(*this), static_cast<T&>(*this), rhs); return static_cast<T&>(*this); }
	MIE_FORCE_INLINE T& operator*=(const T& rhs) { T::mul(static_cast<T&>(*this), static_cast<T&>(*this), rhs); return static_cast<T&>(*this); }
	MIE_FORCE_INLINE friend T operator+(const T& a, const T& b) { T c; T::add(c, a, b); return c; }
	MIE_FORCE_INLINE friend T operator-(const T& a, const T& b) { T c; T::sub(c, a, b); return c; }
	MIE_FORCE_INLINE friend T operator*(const T& a, const T& b) { T c; T::mul(c, a, b); return c; }
};

template<class T, class E = Empty<T> >
struct dividable : E {
	MIE_FORCE_INLINE T& operator/=(const T& rhs) { T rdummy; T::div(static_cast<T*>(this), rdummy, static_cast<const T&>(*this), rhs); return static_cast<T&>(*this); }
	MIE_FORCE_INLINE T& operator%=(const T& rhs) { T::div(0, static_cast<T&>(*this), static_cast<const T&>(*this), rhs); return static_cast<T&>(*this); }

	MIE_FORCE_INLINE friend T operator/(const T& a, const T& b) { T q, r; T::div(&q, r, a, b); return q; }
	MIE_FORCE_INLINE friend T operator%(const T& a, const T& b) { T r; T::div(0, r, a, b); return r; }
};

template<class T, class E = Empty<T> >
struct hasNegative : E {
	MIE_FORCE_INLINE T operator-() const { T c; T::neg(c, static_cast<const T&>(*this)); return c; }
};

template<class T, class E = Empty<T> >
struct shiftable : E {
	MIE_FORCE_INLINE T operator<<(size_t n) const { T out; T::shl(out, static_cast<const T&>(*this), n); return out; }
	MIE_FORCE_INLINE T operator>>(size_t n) const { T out; T::shr(out, static_cast<const T&>(*this), n); return out; }

//	T& operator<<=(size_t n) { *this = *this << n; return static_cast<T&>(*this); }
//	T& operator>>=(size_t n) { *this = *this >> n; return static_cast<T&>(*this); }
	MIE_FORCE_INLINE T& operator<<=(size_t n) { T::shl(static_cast<T&>(*this), static_cast<const T&>(*this), n); return static_cast<T&>(*this); }
	MIE_FORCE_INLINE T& operator>>=(size_t n) { T::shr(static_cast<T&>(*this), static_cast<const T&>(*this), n); return static_cast<T&>(*this); }
};

template<class T, class E = Empty<T> >
struct inversible : E {
	MIE_FORCE_INLINE void inverse() { T& self = static_cast<T&>(*this);T out; T::inv(out, self); self = out; }
	MIE_FORCE_INLINE friend T operator/(const T& x, const T& y) { T out; T::inv(out, y); out *= x; return out; }
	MIE_FORCE_INLINE T& operator/=(const T& x) { T rx; T::inv(rx, x); T& self = static_cast<T&>(*this); self *= rx; return self; }
};

struct PrimitiveFunction {
	/*
		compare x[] and y[]
		@retval positive  if x > y
		@retval 0         if x == y
		@retval negative  if x < y
	*/
	static inline int compare(const Unit *x, size_t xn, const Unit *y, size_t yn)
	{
		assert(xn > 0 && yn > 0);
		if (xn != yn) return xn > yn ? 1 : -1;
		for (int i = (int)xn - 1; i >= 0; i--) {
			if (x[i] != y[i]) return x[i] > y[i] ? 1 : -1;
		}
		return 0;
	}
	/*
		out[] = x[] + y[]
		out may be equal to x or y
	*/
	static bool (*addN)(Unit *out, const Unit *x, const Unit *y, size_t n);
	/*
		out[] = x[] + y
	*/
	static bool (*add1)(Unit *out, const Unit *x, size_t n, Unit y);
	/*
		out[] = x[] - y[]
		out may be equal to x or y
	*/
	static bool (*subN)(Unit *out, const Unit *x, const Unit *y, size_t n);
	/*
		out[] = x[] - y
	*/
	static bool (*sub1)(Unit *out, const Unit *x, size_t n, Unit y);

	static void (*mul1)(Unit *out, const Unit *x, size_t n, Unit y);

	/*
		q[] = x[] / y
		@retval r = x[] % y
		q may be equal to x
	*/
	static Unit (*div1)(Unit *q, const Unit *x, size_t n, Unit y);
	/*
		q[] = x[] / y
		@retval r = x[] % y
	*/
	static Unit (*mod1)(const Unit *x, size_t n, Unit y);
};

template<class T, size_t = 0>
class VariableBuffer {
	std::vector<T> v_;
public:
	typedef T value_type;
	VariableBuffer()
	{
	}
	void clear() { v_.clear(); }

	/*
		@note extended buffer may be not cleared
	*/
	void alloc(size_t n)
	{
#if NDEBUG
		v_.resize(n);
#else
		size_t m = v_.size();
		v_.resize(n);
		if (n > m) {
			std::fill(&v_[0] + m, &v_[0] + n, (T)-1);
		}
#endif
	}

	/*
		*this = rhs
		rhs may be destroyed
	*/
	void moveFrom(VariableBuffer& rhs) { v_.swap(rhs.v_); }
	size_t size() const { return v_.size(); }
	const T& operator[](size_t n) const { return v_[n]; }
	T& operator[](size_t n) { return v_[n]; }
};

template<class T, size_t BitLen>
class FixedBuffer {
	enum {
		N = (BitLen + sizeof(T) * 8 - 1) / (sizeof(T) * 8)
	};
	T v_[N];
	size_t size_;
public:
	typedef T value_type;
	FixedBuffer()
		: size_(0)
	{
	}
	FixedBuffer(const FixedBuffer& rhs)
	{
		operator=(rhs);
	}
	FixedBuffer& operator=(const FixedBuffer& rhs)
	{
		size_ = rhs.size_;
		std::copy(rhs.v_, rhs.v_ + rhs.size_, v_);
		return *this;
	}
	void clear() { size_ = 0; }
	void alloc(size_t n)
	{
		verify(n);
		size_ = n;
	}
	void forceAlloc(size_t n) // for placement new
	{
		size_ = n;
	}
	size_t size() const { return size_; }
	void moveFrom(const FixedBuffer& rhs)
	{
		operator=(rhs);
	}
	// to avoid warning of gcc
	void verify(size_t n) const
	{
		if (n > N) {
			printf("n=%d, N=%d\n", (int)n, (int)N);
			local::errExit("too large size. increase MIE_ZM_VUINT_BIT_LEN in include/zm.h");
		}
	}
	const T& operator[](size_t n) const { verify(n); return v_[n]; }
	T& operator[](size_t n) { verify(n); return v_[n]; }
};

} // local

/**
	unsigned integer with variable length
*/
template<class Buffer>
struct VuintT : public local::dividable<VuintT<Buffer>,
					   local::addsubmul<VuintT<Buffer>,
					   local::comparable<VuintT<Buffer>,
					   local::shiftable<VuintT<Buffer>, Buffer> > > > {
	typedef local::PrimitiveFunction F;
	typedef typename Buffer::value_type T;

	VuintT(T x = 0)
	{
		set(x);
	}
	explicit VuintT(const std::string& str)
	{
		set(str);
	}
	VuintT(const uint32_t *x, size_t size)
	{
		set(x, size);
	}
	VuintT(const uint64_t *x, size_t size)
	{
		set(x, size);
	}
	void set(T x)
	{
		Buffer::alloc(1);
		(*this)[0] = x;
	}
	void set(const uint32_t *x, size_t size)
	{
		Buffer::clear();
		if (size == 0) {
			set((T)0);
			return;
		}
#ifdef MIE_USE_UNIT32
		Buffer::alloc(size);
		for (size_t i = 0; i < size; i++) {
			(*this)[i] = x[i];
		}
#else
		Buffer::alloc((size + 1) / 2);
		for (size_t i = 0; i < size / 2; i++) {
			(*this)[i] = make64(x[i * 2 + 1], x[i * 2]);
		}
		if (size & 1) {
			(*this)[size / 2] = x[size - 1];
		}
#endif
		trim();
	}
	void set(const uint64_t *x, size_t size)
	{
		Buffer::clear();
		if (size == 0) {
			set((T)0);
			return;
		}
#ifdef MIE_USE_UNIT32
		Buffer::alloc(size * 2);
		for (size_t i = 0; i < size; i++) {
			uint32_t L, H;
			split64(&H, &L, x[i]);
			(*this)[i * 2 + 0] = L;
			(*this)[i * 2 + 1] = H;
		}
#else
		Buffer::alloc(size);
		for (size_t i = 0; i < size; i++) {
			(*this)[i] = x[i];
		}
#endif
		trim();
	}

	/***
		If an index refer to the out of valid range,
		then it returns 0.
	*/
	T getAtWithCheck(size_t i) const
	{
		if (i >= this->size()) {
			return 0;
		} else {
			return (*this)[i];
		}
	}

	void clear() { set((T)0); }
	std::string toString(int base = 10) const
	{
		std::ostringstream os;
		switch (base) {
		case 10:
			{
				const uint32_t i1e9 = 1000000000U;
				static const VuintT zero = 0;
				VuintT x = *this;

				std::vector<uint32_t> t;
				while (x > zero) {
					uint32_t r = (uint32_t)div1(&x, x, i1e9);
					t.push_back(r);
				}
				if (t.empty()) {
					return "0";
				}
				os << t[t.size() - 1];
				for (size_t i = 1, n = t.size(); i < n; i++) {
					os << std::setfill('0') << std::setw(9) << t[n - 1 - i];
				}
			}
			break;
		case 16:
			{
				os << "0x" << std::hex;
				const size_t n = Buffer::size();
				os << (*this)[n - 1];
				for (size_t i = 1; i < n; i++) {
					os << std::setfill('0') << std::setw(sizeof(Unit) * 2) << (*this)[n - 1 - i];
				}
			}
			break;
		default:
			local::errExit("toString not support base");
		}
		return os.str();
	}
	/*
		@param str [in] number string
		@note "0x..."   => base = 16
		      "0b..."   => base = 2
		      otherwise => base = 10
	*/
	void set(const std::string& str, int base = 0)
	{
		std::string t;
		if (str.size() >= 2 && str[0] == '0') {
			switch (str[1]) {
			case 'x':
				if (base != 0 && base != 16) local::errExit("bad base in set(str)");
				base = 16;
				t = str.substr(2);
				break;
			default:
				local::errExit("not support base in set(str) 0x");
			}
		}
		if (base == 0) {
			base = 10;
		}
		if (t.empty()) t = str;

		switch (base) {
		case 16:
			{
				std::vector<uint32_t> x;
				while (!t.empty()) {
					size_t remain = std::min((int)t.size(), 8);
					char *endp;
					uint32_t v = strtoul(&t[t.size() - remain], &endp, 16);
					if (*endp) goto ERR;
					x.push_back(v);
					t = t.substr(0, t.size() - remain);
				}
				set(&x[0], x.size());
			}
			break;
		default:
		case 10:
			{
				std::vector<uint32_t> x;
				while (!t.empty()) {
					size_t remain = std::min((int)t.size(), 9);
					char *endp;
					uint32_t v = strtol(&t[t.size() - remain], &endp, 10);
					if (*endp) goto ERR;
					x.push_back(v);
					t = t.substr(0, t.size() - remain);
				}
				clear();
				for (size_t i = 0, n = x.size(); i < n; i++) {
					(*this) *= 1000000000;
					(*this) += x[n - 1 - i];
				}
			}
			break;
		}
		return;
	ERR:
		throw std::invalid_argument(std::string("bad digit `") + str + "`");
	}
	void fromStr(const std::string& str, int base = 10)
	{
		set(str, base);
	}
	std::string toStr(int base = 10) const { return toString(base); }
	static int compare(const VuintT& x, const VuintT& y)
	{
		return F::compare(&x[0], x.size(), &y[0], y.size());
	}
	size_t size() const { return Buffer::size(); }

	bool isZero() const
	{
		return Buffer::size() == 1 && (*this)[0] == 0;
	}

	size_t bitLen() const
	{
		if (isZero()) return 0;

		size_t size = this->size();
		T v = (*this)[size - 1];
		union di t;
		t.f = (double)v;
		size_t ret = 1 + (size_t(t.i >> 52) - (1 << 10) + 1) +
			(size - 1) * sizeof(T) * 8;
		return ret;
	}

	bool testBit(size_t i) const
	{
		size_t unit_pos = i / (sizeof(T) * 8);
		size_t bit_pos  = i % (sizeof(T) * 8);
		T mask = T(1) << bit_pos;
		return ((*this)[unit_pos] & mask) != 0;
	}

	static bool add_in(VuintT& out, const VuintT& x, const VuintT& y)
	{
		const VuintT *px = &x;
		const VuintT *py = &y;
		if (y.size() > x.size()) {
			std::swap(px, py);
		}
		size_t max = px->size();
		size_t min = py->size();
		out.alloc(max);
		bool c = F::addN(&out[0], &(*px)[0], &(*py)[0], min);
		if (max > min) {
			c = F::add1(&out[min], &(*px)[min], max - min, c);
		}
		return c;
	}

	static inline void add(VuintT& out, const VuintT& x, const VuintT& y)
	{
		bool c = add_in(out, x, y);
		if (c) {
			out.alloc(out.size() + 1);
			out[out.size() - 1] = 1;
		} else {
			out.trim();
		}
	}
	static inline void add(VuintT& out, const VuintT& x, uint32_t y)
	{
		const size_t n = x.size();
		out.alloc(n);
		bool c = F::add1(&out[0], &x[0], n, y);
		if (c) {
			out.alloc(n + 1);
			out[n] = 1;
		}
	}
	static bool sub_in(VuintT& out, const VuintT& x, const VuintT& y)
	{
		const size_t xn = x.size();
		const size_t yn = y.size();
		assert(xn >= yn);
		out.alloc(xn);
		bool c = F::subN(&out[0], &x[0], &y[0], yn);
		if (xn > yn) {
			c = F::sub1(&out[yn], &x[yn], xn - yn, c);
		}
		return c;
	}

	static void sub(VuintT& out, const VuintT& x, const VuintT& y)
	{
		bool c = sub_in(out, x, y);
		if (c) {
			local::errExit("can't sub");
		}
		out.trim();
	}

	static void mul1(VuintT& out, const VuintT& x, T y)
	{
		const size_t xn = x.size();
		out.alloc(xn + 1);
		F::mul1(&out[0], &x[0], xn, y);
		out.trim();
	}
	static void mul(VuintT& out, const VuintT& x, const VuintT& y)
	{
		const size_t xn = x.size();
		const size_t yn = y.size();

		VuintT xt, yt;
		const Unit *px = &x[0], *py = &y[0];
		if (&out == &x) {
			xt = x;
			px = &xt[0];
		}
		if (&out == &y) {
			if (&x == &y) {
				py = px;
			} else {
				yt = y;
				py = &yt[0];
			}
		}
		out.alloc(xn + yn);
		mul(&out[0], px, xn, py, yn);
		out.trim();
	}
	/**
		@param q [out] q = x / y
		@param x [in]
		@param y [in] must be not zero
		@return x % y
	*/
	static T div1(VuintT *q, const VuintT& x, T y)
	{
		const size_t xn = x.size();
		T r;
		if (q) {
			q->alloc(xn); // assume q is not destroyed if q == x
			r = F::div1(&(*q)[0], &x[0], xn, y);
			q->trim();
		} else {
			r = F::mod1(&x[0], xn, y);
		}
		return r;
	}
	/**
		@param q [out] x / y if q != 0
		@param r [out] x % y
		@retval true if y != 0
		@retavl false if y == 0
	*/
	static bool div(VuintT* q, VuintT& r, const VuintT& x, const VuintT& y)
	{
//std::cout << "x=" << x << std::endl;
//std::cout << "y=" << y << std::endl;
		assert(q != &r);
		const size_t xn = x.size();
		const size_t yn = y.size();
		if (yn == 1) {
			if (y[0] == 0) return false;
			r.set(div1(q, x, y[0]));
			return true;
		}
		int cmp = F::compare(&x[0], xn, &y[0], yn);
		if (cmp < 0) {
			if (&r != &x) {
				r = x;
			}
			if (q) q->clear();
		} else if (cmp == 0) {
			// imply &x == &y
			if (q) q->set(1);
			r.clear();
		} else {
			assert(&x != &y);
			VuintT qt;
			Unit *pqt = 0;
			bool directQ = false;
			if (q == 0) {
				pqt = 0;
			} else if (q != &x && q != &y) {
				q->alloc(xn - yn + 1);
				pqt = &(*q)[0];
				directQ = true;
			} else {
				qt.alloc(xn - yn + 1);
				pqt = &qt[0];
			}
			VuintT rt;
			Unit *prt = 0;
			bool directR = false;
			if (&r != &x && &r != &y) {
				r = x;
				directR = true;
				prt = &r[0];
			} else {
				rt = x;
				prt = &rt[0];
			}
			div(pqt, prt, xn, &y[0], yn);
			if (q) {
				if (directQ) {
					q->trim();
				} else {
					qt.trim();
					q->moveFrom(qt);
				}
			}
			if (directR) {
				r.trim();
			} else {
				rt.trim();
				r.moveFrom(rt);
			}
		}
//puts("out");
		return true;
	}
	inline friend std::ostream& operator<<(std::ostream& os, const VuintT& x)
	{
		return os << x.toString(os.flags() & std::ios_base::hex ? 16 : 10);
	}
	inline friend std::istream& operator>>(std::istream& is, VuintT& x)
	{
		std::string str;
		local::getDigits(is, str);
		x.set(str);
		return is;
	}

	/*
		shift left Unit
	*/
	static inline void shlUnit(VuintT& out, const VuintT& x, size_t n)
	{
		const size_t xn = x.size();
		out.alloc(xn + n);
		for (int i = (int)xn - 1; i >= 0; i--) {
			out[i + n] = x[i];
		}
		std::fill(&out[0], &out[0] + n, 0);
		out.trim();
	}
	/*
		shift left bit
		0 < n < sizeof(T)
	*/
	static inline void shlBit(VuintT& out, const VuintT& x, size_t n)
	{
		const size_t unitSize = sizeof(T) * 8;
		assert(0 < n && n < unitSize);
		const size_t xn = x.size();
		out.alloc(xn);

		T prev = 0;
		size_t rn = unitSize - n;
		for (size_t i = 0; i < xn; i++) {
			T t = x[i];
			out[i] = (t << n) | (prev >> rn);
			prev = t;
		}
		prev >>= rn;
		if (prev) {
			out.alloc(xn + 1);
			out[xn] = prev;
		}
	}
	/*
		shift right byte
	*/
	static inline void shrUnit(VuintT& out, const VuintT& x, size_t n)
	{
		const size_t xn = x.size();
		if (xn <= n) {
			out = 0;
		} else {
			out.alloc(xn); // not on because of x may be equal to out
			const size_t on = xn - n;
			for (size_t i = 0; i < on; i++) {
				out[i] = x[i + n];
			}
			out.alloc(on);
		}
	}
	/*
		shift right bit
		0 < n < sizeof(T)
	*/
	static inline void shrBit(VuintT& out, const VuintT& x, size_t n)
	{
		const size_t unitSize = sizeof(T) * 8;
		assert(0 < n && n < unitSize);
		const size_t xn = x.size();
		T prev = 0;
		size_t rn = unitSize - n;
		out.alloc(xn);
		for (int i = (int)xn - 1; i >= 0; i--) {
			T t = x[i];
			out[i] = (t >> n) | (prev << rn);
			prev = t;
		}
		out.trim();
	}
	static inline void shl(VuintT& out, const VuintT& x, size_t n)
	{
		if (n == 0) {
			out = x;
		} else {
			const size_t unitSize = sizeof(T) * 8;
			size_t q = n / unitSize;
			size_t r = n % unitSize;
			const VuintT *p = &x;
			if (q) {
				shlUnit(out, x, q);
				p = &out;
			}
			if (r) {
				shlBit(out, *p, r);
			}
		}
	}
	static inline void shr(VuintT& out, const VuintT& x, size_t n)
	{
		if (n == 0) {
			out = x;
		} else {
			const size_t unitSize = sizeof(T) * 8;
			size_t q = n / unitSize;
			size_t r = n % unitSize;
			const VuintT *p = &x;
			if (q) {
				shrUnit(out, x, q);
				p = &out;
			}
			if (r) {
				shrBit(out, *p, r);
			}
		}
	}
private:
	union di {
		double f;
		uint64_t i;
	};
	/*
		get approximate value from x[xn - 1..]
		@param up [in] round up if true
	*/
	static inline double GetApp(const T *x, size_t xn, bool up)
	{
		assert(xn >= 2);
		T H = x[xn - 1];
		assert(H);
		union di di;
		di.f = (double)H;
		unsigned int len = int(di.i >> 52) - 1023 + 1;
#ifdef MIE_USE_UNIT32
		uint32_t M = x[xn - 2];
		if (len >= 21) {
			di.i |= M >> (len - 21);
		} else {
			di.i |= uint64_t(M) << (21 - len);
			if (xn >= 3) {
				uint32_t L = x[xn - 3];
				di.i |= L >> (len + 11);
			}
		}
#else
		if (len < 53) {
			uint64_t L = x[xn - 2];
			di.i |= L >> (len + 11);
		} else {
			// avoid rounding in converting from uint64_t to double
			di.f = (double)(H & ~((uint64_t(1) << (len - 53)) - 1));
		}
#endif
		double t = di.f;
		if (up) {
			di.i = uint64_t(len + 1022 - 52 + 1) << 52;
			t += di.f;
		}
		return t;
	}
public:
	void trim()
	{
		// remove leading zero
		assert(Buffer::size());
		int i = (int)Buffer::size() - 1;
		for (; i > 0; i--) {
			if ((*this)[i]) break;
		}
		Buffer::alloc(i ? i + 1: 1);
	}
	static inline void mul(T *out, const T *x, size_t xn, const T *y, size_t yn)
	{
		assert(xn > 0 && yn > 0);
		if (yn > xn) {
			std::swap(yn, xn);
			std::swap(x, y);
		}

		std::fill(&out[xn + 1], &out[xn + yn], 0);
		F::mul1(&out[0], x, xn, y[0]);

#if 1
		T *t2 = (T*)MIE_ALLOCA_(sizeof(T) * (xn + 1));
#else
		Buffer t2;
		t2.alloc(xn + 1);
#endif
		for (size_t i = 1; i < yn; i++) {
			F::mul1(&t2[0], x, xn, y[i]);
			F::addN(&out[i], &out[i], &t2[0], xn + 1);
		}
	}
	static inline void div(T *q, T *x, size_t xn, const T *y, size_t yn)
	{
		assert(xn >= yn && yn >= 2);
		if (q) {
			std::fill(q, q + xn - yn + 1, 0);
		}
		Buffer t;
		t.alloc(yn + 1);
		double yt = GetApp(y, yn, true);
		while (F::compare(x, xn, y, yn) >= 0) {
			size_t len = yn;
			double xt = GetApp(x, xn, false);
			if (F::compare(&x[xn - len], yn, y, yn) < 0) {
				xt *= double(1ULL << (sizeof(T) * 8 - 1)) * 2;
				len++;
			}
			T qt = T(xt / yt);
			if (qt == 0) qt = 1;
			F::mul1(&t[0], y, yn, qt);
			bool b = F::subN(&x[xn - len], &x[xn - len], &t[0], len);
			if (b) {
				assert(!b);
			}
			if (q) q[xn - len] += qt;

			while (xn >= yn && x[xn - 1] == 0) {
				xn--;
			}
		}
	}
};

template<class V>
class VsintT : public local::addsubmul<VsintT<V>,
					  local::comparable<VsintT<V>,
					  local::dividable<VsintT<V>,
					  local::hasNegative<VsintT<V>,
					  local::shiftable<VsintT<V> > > > > > {
	V v_;
	bool isNeg_;
public:
	typedef typename V::value_type value_type;
	VsintT(int x = 0)
		: v_(::abs(x))
		, isNeg_(x < 0)
	{
	}
	explicit VsintT(const std::string& str)
	{
		set(str);
	}
	VsintT(const V& x)
		: v_(x)
		, isNeg_(false)
	{
	}
	void set(value_type x)
	{
		v_.set(x);
	}
	void set(int64_t x)
	{
		isNeg_ = x < 0;
		v_.set(isNeg_ ? -x : x);
	}
	void set(const V& x)
	{
		v_ = x;
		isNeg_ = false;
	}
	void set(const uint64_t *ptr, size_t size) { v_.set(ptr, size); }
	const V& get() const { return v_; }
	V& get() { return v_; }
	void clear() { v_.set((value_type)0); isNeg_ = false; }
	std::string toString(int base = 10) const
	{
		if (isNeg_) return "-" + v_.toString(base);
		return v_.toString(base);
	}
	void set(const std::string& str, int base = 10)
	{
		isNeg_ = false;
		if (str.size() > 0 && str[0] == '-') {
			isNeg_ = true;
			v_.set(&str[1], base);
		} else {
			v_.set(str, base);
		}
	}
	void fromStr(const std::string& str, int base = 10)
	{
		set(str, base);
	}
	std::string toStr(int base = 10) { return toString(base); }
	static inline int compare(const VsintT& x, const VsintT& y)
	{
		if (x.isNeg_ ^ y.isNeg_) {
			if (x.isZero() && y.isZero()) return 0;
			return x.isNeg_ ? -1 : 1;
		} else {
			// same sign
			return V::compare(x.v_, y.v_) * (x.isNeg_ ? -1 : 1);
		}
	}
	size_t size() const { return v_.size(); }
	bool isZero() const { return v_.isZero(); }
	bool isNegative() const { return isNeg_ && !isZero(); }
	static inline void add(VsintT& out, const VsintT& x, const VsintT& y)
	{
		if ((x.isNeg_ ^ y.isNeg_) == 0) {
			// same sign
			V::add(out.v_, x.v_, y.v_);
			out.isNeg_ = x.isNeg_;
			return;
		}
		int r = V::compare(x.v_, y.v_);
		if (r >= 0) {
			V::sub(out.v_, x.v_, y.v_);
			out.isNeg_ = x.isNeg_;
		} else {
			V::sub(out.v_, y.v_, x.v_);
			out.isNeg_ = y.isNeg_;
		}
	}
	static inline void sub(VsintT& out, const VsintT& x, const VsintT& y)
	{
		if (x.isNeg_ ^ y.isNeg_) {
			// different sign
			V::add(out.v_, x.v_, y.v_);
			out.isNeg_ = x.isNeg_;
			return;
		}
		// same sign
		int r = V::compare(x.v_, y.v_);
		if (r >= 0) {
			V::sub(out.v_, x.v_, y.v_);
			out.isNeg_ = x.isNeg_;
		} else {
			V::sub(out.v_, y.v_, x.v_);
			out.isNeg_ = !y.isNeg_;
		}
	}
	static inline void mul(VsintT& out, const VsintT& x, const VsintT& y)
	{
		V::mul(out.v_, x.v_, y.v_);
		out.isNeg_ = x.isNeg_ ^ y.isNeg_;
	}
	static inline bool div(VsintT *q, VsintT& r, const VsintT& x, const VsintT& y)
	{
#if 1
		// like Python
		//  13 / -5 = -3 ... -2
		// -13 /  5 = -3 ...  2
		// -13 / -5 =  2 ... -3
		V yy = y.v_;
		bool ret = V::div(q ? &(q->v_) : 0, r.v_, x.v_, y.v_);
		if (!ret) return false;
		bool qsign = x.isNeg_ ^ y.isNeg_;
		if (r.v_.isZero()) {
			r.isNeg_ = false;
		} else {
			if (qsign) {
				if (q) {
					q->v_ += 1;
				}
				r.v_ = yy - r.v_;
			}
			r.isNeg_ = y.isNeg_;
		}
		if (q) q->isNeg_ = qsign;
		return true;
#else
		//  13 / -5 = -2 ...  3
		// -13 /  5 = -2 ... -3
		// -13 / -5 =  2 ... -3
		bool ret = V::div(q ? &(q->v_) : 0, r.v_, x.v_, y.v_);
		bool qsign = x.isNeg_ ^ y.isNeg_;
		r.isNeg_ = x.isNeg_;
		if (q) q->isNeg_ = qsign;
		return ret;
#endif
	}
	static inline void neg(VsintT& out, const VsintT& x)
	{
		out.v_ = x.v_;
		out.isNeg_ = !x.isNeg_;
	}
	inline friend std::ostream& operator<<(std::ostream& os, const VsintT& x)
	{
		if (x.isNeg_) os << "-";
		return os << x.v_;
	}
	inline friend std::istream& operator>>(std::istream& is, VsintT& x)
	{
		std::string str;
		local::getDigits(is, str, true);
		x.set(str);
		return is;
	}
	static inline void shl(VsintT& out, const VsintT& x, size_t n)
	{
		V::shl(out.v_, x.v_, n);
		out.isNeg_ = x.isNeg_;
	}
	static inline void shr(VsintT& out, const VsintT& x, size_t n)
	{
		if (x.isZero()) {
			out.clear();
			return;
		}
		if (x.isNeg_) {
			local::errExit("shr can't deal with negative value");
		} else {
			V::shr(out.v_, x.v_, n);
			out.isNeg_ = false;
		}
	}

	static inline void absolute(V& out, const VsintT& in)
	{
		out = in.get();
	}

	inline V abs() const { V x; absolute(x, *this); return x; }
	VsintT operator<<(size_t n) const
	{
		VsintT out; shl(out, *this, n); return out;
	}
	VsintT& operator<<=(size_t n)
	{
		shl(*this, *this, n); return *this;
	}
};

//typedef VuintT<local::VariableBuffer> Vuint;
typedef VuintT<local::FixedBuffer<mie::Unit, MIE_ZM_VUINT_BIT_LEN> > Vuint;
typedef VsintT<Vuint> Vsint;

/**
	Z/mZ class by Vuint
	@note Tag is prepared for multi instances of different m
*/
template<class V = Vuint, class Tag = Vuint>
class ZmZ : public local::addsubmul<ZmZ<V, Tag>,
				   local::comparable<ZmZ<V, Tag>,
				   local::hasNegative<ZmZ<V, Tag>,
				   local::inversible<ZmZ<V, Tag> > > > > {
public:
	typedef void base_type;
	typedef typename V::value_type value_type;
private:
	V v_;
	static V m_;
	void modulo()
	{
		v_ %= m_;
	}
public:
	ZmZ(int x = 0)
	{
		set(x);
	}
	explicit ZmZ(const std::string& str)
	{
		set(str);
	}
	ZmZ(const V& rhs)
		: v_(rhs)
	{
		modulo();
	}
	void set(const ZmZ &x) { v_ = x.v_; }
	void set(int x)
	{
		if (x == 0) {
			v_.clear();
		} else if (x > 0) {
			v_.set(x);
		} else {
			if (x == -2147483647 - 1 || m_ < -x) {
				local::errExit("x is too small");
			}
			v_ = m_;
			v_ -= -x;
		}
	}
	void set(const std::string& str)
	{
		v_.set(str);
		modulo();
	}
	void set(const uint32_t *x, size_t size)
	{
		v_.set(x, size);
		modulo();
	}
	void set(const uint64_t *x, size_t size)
	{
		v_.set(x, size);
		modulo();
	}
	void set(const V& rhs)
	{
		v_ = rhs;
		modulo();
	}
	static inline int compare(const ZmZ& x, const ZmZ& y)
	{
		return V::compare(x.v_, y.v_);
	}
	static inline void add(ZmZ& out, const ZmZ& x, const ZmZ& y)
	{
		V::add(out.v_, x.v_, y.v_);
		if (out.v_ >= m_) {
			out.v_ -= m_;
		}
	}
	static inline void sub(ZmZ& out, const ZmZ& x, const ZmZ& y)
	{
		if (x.v_ < y.v_) {
			if (&out != &y) {
				V::add(out.v_, x.v_, m_);
				out.v_ -= y.v_;
			} else {
				V t = x.v_ + m_;
				out.v_ = t - y.v_;
			}
		} else {
			V::sub(out.v_, x.v_, y.v_);
		}
	}
	static inline void neg(ZmZ& out, const ZmZ& x)
	{
		if (x.isZero()) {
			out = x;
		} else {
			V::sub(out.v_, m_, x.v_);
		}
	}
	static inline void mul(ZmZ& out, const ZmZ& x, const ZmZ& y)
	{
#if 0 // for only FixedBuffer(this code is dangerous and not good)
		const size_t xn = x.size();
		const size_t yn = y.size();

		V *t = new(MIE_ALLOCA_(sizeof(value_type) * (xn + yn))) V;
		t->forceAlloc(xn + yn);
		V::mul(&(*t)[0], &x[0], xn, &y[0], yn);
		t->trim();
		V::div(0, out.v_, *t, m_);
		out.v_.trim();
#else
		V::mul(out.v_, x.v_, y.v_);
		out.modulo();
#endif
	}
	inline friend std::ostream& operator<<(std::ostream& os, const ZmZ& x)
	{
		return os << x.v_;
	}
	bool isZero() const { return v_.isZero(); }
	void clear() { v_ = 0; }
	const V& get() const { return v_; }
	/*
		out = 1/x mod m
	*/
	static inline void inv(ZmZ& out, const ZmZ& x)
	{
		assert(!x.isZero());
		ZmZ a = 1;
		if (a.v_ == x.v_) {
			out = a;
			return;
		}

		V t;
		ZmZ q;
		V::div(&q.v_, t, m_, x.v_);
		assert(!t.isZero()); // because m_ is prime
		V s = x.v_;
		ZmZ b = -q;

		for (;;) {
			V::div(&q.v_, s, s, t);
			if (s.isZero()) {
				out = b;
				return;
			}
			a -= b * q;

			V::div(&q.v_, t, t, s);
			if (t.isZero()) {
				out = a;
				return;
			}
			b -= a * q;
		}
	}
	std::string toString(int base = 10) const
	{
		return v_.toString(base);
	}
	const value_type& operator[](size_t i) const { return v_[i]; }
	value_type& operator[](size_t i) { return v_[i]; }
	size_t size() const { return v_.size(); }
	static void setModulo(const V& m)
	{
		m_ = m;
	}
	static inline const V& getModulo()
	{
		return m_;
	}
};

namespace util {
/*
	dispatch Uint, int, size_t, and so on
*/
template<class T>
struct IntTag {
	typedef typename T::value_type value_type;
	static inline value_type getBlock(const T& x, size_t i)
	{
		return x[i];
	}
	static inline size_t getBlockSize(const T& x)
	{
		return x.size();
	}
};

template<>
struct IntTag<int> {
	typedef int value_type;
	static inline value_type getBlock(const int& x, size_t)
	{
		return x;
	}
	static inline size_t getBlockSize(const int&)
	{
		return 1;
	}
};
template<>
struct IntTag<size_t> {
	typedef size_t value_type;
	static inline value_type getBlock(const size_t& x, size_t)
	{
		return x;
	}
	static inline size_t getBlockSize(const size_t&)
	{
		return 1;
	}
};

} // util

/**
	return pow(x, y)
*/
template<class T, class S>
T power(const T& x, const S& y)
{
	typedef typename mie::util::IntTag<S> Tag;
	typedef typename Tag::value_type value_type;
	T t(x);
	T out = 1;
	for (size_t i = 0, n = Tag::getBlockSize(y); i < n; i++) {
		value_type v = Tag::getBlock(y, i);
		int m = (int)sizeof(value_type) * 8;
		if (i == n - 1) {
			// avoid unused multiplication
			while (m > 0 && (v & (value_type(1) << (m - 1))) == 0) {
				m--;
			}
		}
		for (int j = 0; j < m; j++) {
			if (v & (value_type(1) << j)) {
				out *= t;
			}
			t *= t;
		}
	}
	return out;
}

template<class V, class Tag>
V ZmZ<V, Tag>::m_;

void zmInit();

} // mie
