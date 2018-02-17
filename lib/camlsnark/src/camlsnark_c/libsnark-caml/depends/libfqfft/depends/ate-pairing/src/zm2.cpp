/*
	bn::Fp is a finite field with characteristic 254-bit prime integer
*/
#include <iostream>
#include "zm.h"
#ifdef MIE_USE_X64ASM
#define XBYAK_NO_OP_NAMES
#include "xbyak/xbyak.h"
#include "xbyak/xbyak_util.h"
Xbyak::util::Clock sclk;
#endif
#include "bn.h"
#if defined(_MSC_VER) && (_MSC_VER <= 1500)
typedef unsigned char uint8_t;
#else
#include <stdint.h>
#endif

using namespace bn;

#ifdef DEBUG_COUNT
extern int g_count_m256;
extern int g_count_r512;
extern int g_count_add256;
#endif

// for C
// r = (1 << 256) % p
// rr = r^(-1) % p
mie::Vuint Fp::p_;
mie::Vuint Fp::montgomeryR_;
mie::Vuint Fp::p_add1_div4_;
Fp Fp::montgomeryR2_;
Fp Fp::one_;
Fp Fp::invTbl_[512];
struct MontgomeryDummy{};
static mie::Vuint pN;

/*
	p = 0x2523648240000001,ba344d8000000008,6121000000000013,a700000000000013
	N = 1 << 256
	6p < N, 7p > N
	s_pTbl[i] = ip for i < 7
*/

const size_t pTblSize = 10;
const size_t pNtblSize = 4;
struct Data {
	Fp pTbl[pTblSize];
	Fp halfTbl[2];
	Fp quarterTbl[4];
	FpDbl pNTbl[pNtblSize];
};
Data *s_data;

static Fp *s_pTbl;
Fp *Fp::halfTbl_;
Fp *Fp::quarterTbl_;
bn::FpDbl *bn::FpDbl::pNTbl_;

typedef mie::ZmZ<mie::Vuint, Fp> Fp_emu;

static inline void Fp_addC(Fp& out, const Fp& x, const Fp& y)
{
	static const mie::Vuint p(&s_pTbl[1][0], Fp::N);
	mie::Vuint a(&x[0], Fp::N), b(&y[0], Fp::N);
	a += b;
	if (a >= p) {
		a -= p;
	}
	Fp::setDirect(out, a);
}

static inline void Fp_addNC_C(Fp& out, const Fp& x, const Fp& y)
{
	mie::Vuint a(&x[0], Fp::N), b(&y[0], Fp::N);
	a += b;
	Fp::setDirect(out, a);
}

static inline void Fp_subNC_C(Fp& out, const Fp& x, const Fp& y)
{
	mie::Vuint a(&x[0], Fp::N), b(&y[0], Fp::N);
	a -= b;
	Fp::setDirect(out, a);
}

static inline void Fp_subC(Fp& out, const Fp& x, const Fp& y)
{
	static const mie::Vuint p(&s_pTbl[1][0], Fp::N);
	mie::Vuint a(&x[0], Fp::N), b(&y[0], Fp::N);
	if (a < b) {
		a = a + p - b;
	} else {
		a -= p;
	}
	Fp::setDirect(out, a);
}

static inline void Fp_mulC(Fp& out, const Fp& x, const Fp& y)
{
	Fp_emu a(x.get()), b(y.get());
	a *= b;
	out.set(a.get());
}

struct MontgomeryTest{};
static mie::Unit pp_mont;

static void Fp_negC(Fp& out, const Fp& x)
{
	static const Fp zero(0);
	Fp::sub(out, zero, x);
}

void (*Fp::add)(Fp& out, const Fp& x, const Fp& y) = &Fp_addC;
void (*Fp::addNC)(Fp& out, const Fp& x, const Fp& y) = &Fp_addNC_C;
void (*Fp::subNC)(Fp& out, const Fp& x, const Fp& y) = &Fp_subNC_C;
void (*Fp::shr1)(Fp& out, const Fp& x) = 0;
void (*Fp::shr2)(Fp& out, const Fp& x) = 0;
void (*Fp::sub)(Fp& out, const Fp& x, const Fp& y) = &Fp_subC;
void (*Fp::neg)(Fp& out, const Fp& x) = &Fp_negC;
void (*Fp::mul)(Fp& out, const Fp& x, const Fp& y) = &Fp_mulC;
int (*Fp::preInv)(Fp& r, const Fp& x) = 0;

const Fp& Fp::getDirectP(int n)
{
	assert(0 <= n && (size_t)n < pTblSize);
	return s_pTbl[n];
}

static void FpDbl_addC(FpDbl &z, const FpDbl &x, const FpDbl &y)
{
	mie::Vuint a(x.const_ptr(), Fp::N * 2);
	mie::Vuint b(y.const_ptr(), Fp::N * 2);

	assert(a < pN);
	assert(b < pN);
	a += b;
	if (a >= pN) {
		a -= pN;
	}
	z.setDirect(a);
}

static void FpDbl_addNC_C(FpDbl &z, const FpDbl &x, const FpDbl &y)
{
	mie::Vuint a(x.const_ptr(), Fp::N * 2);
	mie::Vuint b(y.const_ptr(), Fp::N * 2);

	a += b;
	z.setDirect(a);
}

static void FpDbl_negC(FpDbl &z, const FpDbl &x)
{
	mie::Vuint a(x.const_ptr(), Fp::N * 2);
	assert(a < pN);
	z.setDirect(a.isZero() ? a : pN - a);
}

static void FpDbl_subC(FpDbl &z, const FpDbl &x, const FpDbl &y)
{
	mie::Vuint a(x.const_ptr(), Fp::N * 2);
	mie::Vuint b(y.const_ptr(), Fp::N * 2);

	assert(a < pN);
	assert(b < pN);

	if (a < b) {
		a += pN;
	}
	a -= b;
	z.setDirect(a);
}

static void FpDbl_subNC_C(FpDbl &z, const FpDbl &x, const FpDbl &y)
{
	mie::Vuint a(x.const_ptr(), Fp::N * 2);
	mie::Vuint b(y.const_ptr(), Fp::N * 2);

	a -= b;
	z.setDirect(a);
}

static void FpDbl_mulC(FpDbl &z, const Fp &x, const Fp &y)
{
	mie::Vuint a(&x[0], Fp::N);
	mie::Vuint b(&y[0], Fp::N);
	a *= b;
	z.setDirect(a);
}

static void FpDbl_modC(Fp& out, const FpDbl& x)
{
	const size_t UnitLen = sizeof(mie::Unit) * 8;
	mie::Vuint c(x.const_ptr(), Fp::N * 2);
	const mie::Vuint& p =Fp::getModulo();

	const size_t n = 256 / UnitLen;
	for (size_t i = 0; i < n; i++) {
		mie::Unit u = c[0];
		mie::Unit q = u * pp_mont;
		c += q * p;
		c >>= UnitLen;
	}
	if (c >= p) {
		c -= p;
	}
	Fp::setDirect(out, c);
}

FpDbl::bin_op *FpDbl::add = &FpDbl_addC;
FpDbl::bin_op *FpDbl::addNC = &FpDbl_addNC_C;
FpDbl::uni_op *FpDbl::neg = &FpDbl_negC;
FpDbl::bin_op *FpDbl::sub = &FpDbl_subC;
FpDbl::bin_op *FpDbl::subNC = &FpDbl_subNC_C;
void (*FpDbl::mul)(Dbl&, const Fp&, const Fp&) = &FpDbl_mulC;
void (*FpDbl::mod)(Fp&, const Dbl&) = &FpDbl_modC;


#ifdef MIE_USE_X64ASM
using namespace Xbyak;

struct CpuExt {
	int type;
	int model;
	int family;
	int stepping;
	int extModel;
	int extFamily;
	int displayFamily;
	int displayModel;
	CpuExt()
	{
		unsigned int data[4];
		Xbyak::util::Cpu::getCpuid(1, data);
		stepping = data[0] & mask(4);
		model = (data[0] >> 4) & mask(4);
		family = (data[0] >> 8) & mask(4);
		type = (data[0] >> 12) & mask(2);
		extModel = (data[0] >> 16) & mask(4);
		extFamily = (data[0] >> 20) & mask(8);
		if (family == 0x0f) {
			displayFamily = family + extFamily;
		} else {
			displayFamily = family;
		}
		if (family == 6 || family == 0x0f) {
			displayModel = (extModel << 4) + model;
		} else {
			displayModel = model;
		}
	}
	unsigned int mask(int n) const
	{
		return (1U << n) - 1;
	}
};

/*
	-m 1 = interleaveLoad : true
	-m 0 = interleaveLoad : false

	interleaveLoad is fast
	cpu vendor=intel, family=6, model=7, extFamily=0, extModel=1, stepping=6 ; core2duo
	cpu vendor=intel, family=6, model=12, extFamily=0, extModel=2, stepping=2 ; Xeon X5650
	cpu vendor=intel, family=6, model=14, extFamily=0, extModel=1, stepping=5 ; Core i7 860
	cpu vendor=intel, family=6, model=5, extFamily=0, extModel=2, stepping=2 ; Core i5 M 520


	interleaveLoad is slow
	cpu vendor=intel, family=6, model=10, extFamily=0, extModel=2, stepping=7 ; core i7 2620
	cpu vendor=amd, family=15, model=4, extFamily=1, extModel=0, stepping=2 ; Opteron 2376
*/
bool interleaveLoad = false;
bool g_useMulx = false;

void detectCpu(int mode, bool useMulx)
{
	using namespace Xbyak::util;
	Xbyak::util::Cpu cpu;
	CpuExt ext;
	bool isIntel = cpu.has(Xbyak::util::Cpu::tINTEL);
//	printf("cpu vendor=%s, ", isIntel ? "intel" : "amd");
//	printf("family=%d, model=%d, extFamily=%d, extModel=%d, stepping=%d\n", ext.family, ext.model, ext.extFamily, ext.extModel, ext.stepping);
//	if (isIntel) printf("dislpayFamily=%02xh, displayModel=%02xh\n", ext.displayFamily, ext.displayModel);
	switch (mode) {
	case 0:
		interleaveLoad = false;
		break;
	case 1:
		interleaveLoad = true;
		break;
	default:
		interleaveLoad = true;
		if (!isIntel || (ext.family == 6 && ext.displayModel == 0x2a)) {
			interleaveLoad = false;
		}
//		printf("-m %d option is selected, but try -m %d to verify the determination.\n", interleaveLoad, 1 - interleaveLoad);
		break;
	}
	if (cpu.has(Xbyak::util::Cpu::tBMI2)) {
		g_useMulx = useMulx;
		if (g_useMulx) {
//			fprintf(stderr, "use mulx\n");
		}
	} else {
		g_useMulx = false;
	}
//	printf("interleaveLoad=%d\n", interleaveLoad);
}

// for debug
static Xbyak::util::Cpu s_cpu;
uint64_t debug_buf[128];
int debug_counter;
struct PutDebugCounter {
	~PutDebugCounter()
	{
		if (debug_counter) printf("debug_counter=%d\n", debug_counter);
	}
} s_putDebugCounter;

struct PairingCode;
template<class Code = PairingCode>
struct MakeStackFrame {
	Code *code_;
	int P_;
	MakeStackFrame(Code *code, int gtn, int numQword = 0)
		: code_(code)
		, P_(code_->storeReg(gtn, numQword))
	{
		code_->isRaxP_ = false;
	}
	~MakeStackFrame()
	{
		code_->restoreReg(P_);
		code_->ret();
	}
};

/*
	Ext1, Ext2, Ext6 are classes to calculate offset and size
*/
template<class F>
struct Ext1 {
	Ext1(const Reg64& r, int n = 0)
		: r_(r)
		, n_(n)
		, next(sizeof(F) + n)
	{
	}
	operator RegExp() const { return r_ + n_; }
	const Reg64& r_;
	const int n_;
	const int next;
private:
	Ext1(const Ext1&);
	void operator=(const Ext1&);
};

template<class F>
struct Ext2 {
	Ext2(const Reg64& r, int n = 0)
		: r_(r)
		, n_(n)
		, next(sizeof(F) * 2 + n)
		, a_(r, n)
		, b_(r, n + sizeof(F))
	{
	}
	operator RegExp() const { return r_ + n_; }
	const Reg64& r_;
	const int n_;
	const int next;
	Ext1<F> a_;
	Ext1<F> b_;
private:
	Ext2(const Ext2&);
	void operator=(const Ext2&);
};

template<class F>
struct Ext6 {
	Ext6(const Reg64& r, int n = 0)
		: r_(r)
		, n_(n)
		, next(sizeof(F) * 6 + n)
		, a_(r, n)
		, b_(r, n + sizeof(F) * 2)
		, c_(r, n + sizeof(F) * 4)
	{
	}
	operator RegExp() const { return r_ + n_; }
	const Reg64& r_;
	const int n_;
	const int next;
	Ext2<F> a_;
	Ext2<F> b_;
	Ext2<F> c_;
private:
	Ext6(const Ext6&);
	void operator=(const Ext6&);
};

template<class F>
struct Ext12 {
	Ext12(const Reg64& r, int n = 0)
		: r_(r)
		, n_(n)
		, next(sizeof(F) * 12 + n)
		, a_(r, n)
		, b_(r, n + sizeof(F) * 6)
	{
	}
	operator RegExp() const { return r_ + n_; }
	const Reg64& r_;
	const int n_;
	const int next;
	Ext6<F> a_;
	Ext6<F> b_;
private:
	Ext12(const Ext12&);
	void operator=(const Ext12&);
};

struct PairingCode : Xbyak::CodeGenerator {
	/*
		[z3:z2:z1:z0] = [m3:m2:m1:m0]
	*/
	void load_rm(const Reg64& z3, const Reg64& z2, const Reg64& z1, const Reg64& z0,
		const RegExp& m)
	{
		mov(z0, ptr [m + 8 * 0]);
		mov(z1, ptr [m + 8 * 1]);
		mov(z2, ptr [m + 8 * 2]);
		mov(z3, ptr [m + 8 * 3]);
	}
	/*
		[z3:z2:z1:z0] = [m3:m2:m1:m0]
	*/
	void store_mr(const RegExp& m, const Reg64& x3, const Reg64& x2, const Reg64& x1, const Reg64& x0)
	{
		mov(ptr [m + 8 * 0], x0);
		mov(ptr [m + 8 * 1], x1);
		mov(ptr [m + 8 * 2], x2);
		mov(ptr [m + 8 * 3], x3);
	}
	/*
		[z3:z2:z1:z0] += [x3:x2:x1:x0]
	*/
	void add_rr(const Reg64& z3, const Reg64& z2, const Reg64& z1, const Reg64& z0,
		const Reg64& x3, const Reg64& x2, const Reg64& x1, const Reg64& x0)
	{
		add(z0, x0);
		adc(z1, x1);
		adc(z2, x2);
		adc(z3, x3);
	}
	/*
		[z3:z2:z1:z0] += [m3:m2:m1:m0]
	*/
	void add_rm(const Reg64& z3, const Reg64& z2, const Reg64& z1, const Reg64& z0,
		const RegExp& m)
	{
		add(z0, ptr [m + 8 * 0]);
		adc(z1, ptr [m + 8 * 1]);
		adc(z2, ptr [m + 8 * 2]);
		adc(z3, ptr [m + 8 * 3]);
	}
#ifdef DEBUG_COUNT
	void upCount(int *count)
	{
		push(rax);
		mov(rax, (size_t)count);
		inc(qword[rax]);
		pop(rax);
	}
#endif
	/*
		[z3:z2:z1:z0] += [m3:m2:m1:m0] with carry
	*/
	void adc_rm(const Reg64& z3, const Reg64& z2, const Reg64& z1, const Reg64& z0,
		const RegExp& m)
	{
		adc(z0, ptr [m + 8 * 0]);
		adc(z1, ptr [m + 8 * 1]);
		adc(z2, ptr [m + 8 * 2]);
		adc(z3, ptr [m + 8 * 3]);
	}
	void load_add_rm(const Reg64& z3, const Reg64& z2, const Reg64& z1, const Reg64& z0,
		const RegExp& mx, const RegExp& my, bool withCarry)
	{
#ifdef DEBUG_COUNT
		upCount(&g_count_add256);
#endif
		if (interleaveLoad) {
			mov(z0, ptr [mx + 8 * 0]);
			if (withCarry) {
				adc(z0, ptr [my + 8 * 0]);
			} else {
				add(z0, ptr [my + 8 * 0]);
			}
			mov(z1, ptr [mx + 8 * 1]);
			adc(z1, ptr [my + 8 * 1]);
			mov(z2, ptr [mx + 8 * 2]);
			adc(z2, ptr [my + 8 * 2]);
			mov(z3, ptr [mx + 8 * 3]);
			adc(z3, ptr [my + 8 * 3]);
		} else {
			load_rm(z3, z2, z1, z0, mx);
			if (withCarry) {
				adc_rm(z3, z2, z1, z0, my);
			} else {
				add_rm(z3, z2, z1, z0, my);
			}
		}
	}
	void load_sub_rm(const Reg64& z3, const Reg64& z2, const Reg64& z1, const Reg64& z0,
		const RegExp& mx, const RegExp& my, bool withCarry)
	{
#ifdef DEBUG_COUNT
		upCount(&g_count_add256);
#endif
		if (interleaveLoad) {
			mov(z0, ptr [mx + 8 * 0]);
			if (withCarry) {
				sbb(z0, ptr [my + 8 * 0]);
			} else {
				sub(z0, ptr [my + 8 * 0]);
			}
			mov(z1, ptr [mx + 8 * 1]);
			sbb(z1, ptr [my + 8 * 1]);
			mov(z2, ptr [mx + 8 * 2]);
			sbb(z2, ptr [my + 8 * 2]);
			mov(z3, ptr [mx + 8 * 3]);
			sbb(z3, ptr [my + 8 * 3]);
		} else {
			load_rm(z3, z2, z1, z0, mx);
			if (withCarry) {
				sbb_rm(z3, z2, z1, z0, my);
			} else {
				sub_rm(z3, z2, z1, z0, my);
			}
		}
	}
	/*
		[z3:z2:z1:z0] -= [x3:x2:x1:x0]
	*/
	void sub_rr(const Reg64& z3, const Reg64& z2, const Reg64& z1, const Reg64& z0,
		const Reg64& x3, const Reg64& x2, const Reg64& x1, const Reg64& x0)
	{
		sub(z0, x0);
		sbb(z1, x1);
		sbb(z2, x2);
		sbb(z3, x3);
	}
	/*
		[z3:z2:z1:z0] -= [m3:m2:m1:m0]
	*/
	void sub_rm(const Reg64& z3, const Reg64& z2, const Reg64& z1, const Reg64& z0,
		const RegExp& m)
	{
		sub(z0, ptr [m + 8 * 0]);
		sbb(z1, ptr [m + 8 * 1]);
		sbb(z2, ptr [m + 8 * 2]);
		sbb(z3, ptr [m + 8 * 3]);
	}
	/*
		[z3:z2:z1:z0] -= [m3:m2:m1:m0] with carry
	*/
	void sbb_rm(const Reg64& z3, const Reg64& z2, const Reg64& z1, const Reg64& z0,
		const RegExp& m)
	{
		sbb(z0, ptr [m + 8 * 0]);
		sbb(z1, ptr [m + 8 * 1]);
		sbb(z2, ptr [m + 8 * 2]);
		sbb(z3, ptr [m + 8 * 3]);
	}
	void in_Fp_add_carry(const RegExp& mz, const RegExp& mx, const RegExp& my, bool withCarry)
	{
		if (interleaveLoad) {
			mov(gt1, ptr [mx + 8 * 0]);
			if (withCarry) {
				adc(gt1, ptr [my + 8 * 0]);
			} else {
				add(gt1, ptr [my + 8 * 0]);
			}
			mov(ptr [mz + 8 * 0], gt1);

			mov(gt2, ptr [mx + 8 * 1]);
			adc(gt2, ptr [my + 8 * 1]);
			mov(ptr [mz + 8 * 1], gt2);

			mov(gt3, ptr [mx + 8 * 2]);
			adc(gt3, ptr [my + 8 * 2]);
			mov(ptr [mz + 8 * 2], gt3);

			mov(gt4, ptr [mx + 8 * 3]);
			adc(gt4, ptr [my + 8 * 3]);
			mov(ptr [mz + 8 * 3], gt4);
		} else {
			load_add_rm(gt4, gt3, gt2, gt1, mx, my, withCarry);
			store_mr(mz, gt4, gt3, gt2, gt1);
		}
	}
	void in_Fp_sub_carry(const RegExp& mz, const RegExp& mx, const RegExp& my, bool withCarry)
	{
		if (interleaveLoad) {
			mov(gt1, ptr [mx + 8 * 0]);
			if (withCarry) {
				sbb(gt1, ptr [my + 8 * 0]);
			} else {
				sub(gt1, ptr [my + 8 * 0]);
			}
			mov(ptr [mz + 8 * 0], gt1);

			mov(gt2, ptr [mx + 8 * 1]);
			sbb(gt2, ptr [my + 8 * 1]);
			mov(ptr [mz + 8 * 1], gt2);

			mov(gt3, ptr [mx + 8 * 2]);
			sbb(gt3, ptr [my + 8 * 2]);
			mov(ptr [mz + 8 * 2], gt3);

			mov(gt4, ptr [mx + 8 * 3]);
			sbb(gt4, ptr [my + 8 * 3]);
			mov(ptr [mz + 8 * 3], gt4);
		} else {
			load_sub_rm(gt4, gt3, gt2, gt1, mx, my, withCarry);
			store_mr(mz, gt4, gt3, gt2, gt1);
		}
	}
	void in_Fp_addNC(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		in_Fp_add_carry(mz, mx, my, false);
	}
	void in_Fp_subNC(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		in_Fp_sub_carry(mz, mx, my, false);
	}
	void in_Fp_adcNC(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		in_Fp_add_carry(mz, mx, my, true);
	}
	void in_Fp_sbbNC(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		in_Fp_sub_carry(mz, mx, my, true);
	}
	/*
		gp1 = mz
		gp2 = mx
		gp3 = my
	*/
	void smart_set_gp(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		lea(gp1, ptr [mz]);
		if (mx == mz) {
			mov(gp2, gp1);
		} else {
			lea(gp2, ptr [mx]);
		}
		if (my == mz) {
			mov(gp3, gp1);
		} else if (my == mx) {
			mov(gp3, gp2);
		} else {
			lea(gp3, ptr [my]);
		}
	}
	void in_FpDbl_addNC(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		smart_set_gp(mz, mx, my);
		call(p_FpDbl_addNC);
	}
	void in_FpDbl_subNC(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		smart_set_gp(mz, mx, my);
		call(p_FpDbl_subNC);
	}
	void make_Fp_addNC(int n)
	{
#ifdef _WIN32
		const Reg64& z = rcx;
		const Reg64& x = rdx;
		const Reg64& y = r8;
#else
		const Reg64& z = rdi;
		const Reg64& x = rsi;
		const Reg64& y = rdx;
#endif
		const Reg64& z2 = r9;
		const Reg64& z1 = r10;
		const Reg64& z0 = r11;
		for (int i = 0; i < n; i++) {
			load_add_rm(rax, z2, z1, z0, x + 32 * i, y + 32 * i, false);
			store_mr(z + 32 * i, rax, z2, z1, z0);
		}
		ret();
	}
	void make_Fp_subNC()
	{
#ifdef _WIN32
		const Reg64& z = rcx;
		const Reg64& x = rdx;
		const Reg64& y = r8;
#else
		const Reg64& z = rdi;
		const Reg64& x = rsi;
		const Reg64& y = rdx;
#endif
		const Reg64& z2 = r9;
		const Reg64& z1 = r10;
		const Reg64& z0 = r11;
		load_sub_rm(x, z2, z1, z0, x, y, false);
		store_mr(z, x, z2, z1, z0);
		ret();
	}

	/*
		input rax = &s_pTbl[1], gt[4, 3, 2, 1]
		output gt[4, 3, 2, 1] mod p
		destroy gt5, gt6, gt7, rdx
	*/
	void in_Fp_add_modp()
	{
		mov(gt5, gt1);
		mov(gt6, gt2);
		mov(gt7, gt3);
		mov(rdx, gt4);

		sub_rm(gt4, gt3, gt2, gt1, rax);
#if 1 // faster@sandy 1.36Mclk
		cmovc(gt1, gt5);
		cmovc(gt2, gt6);
		cmovc(gt3, gt7);
		cmovc(gt4, rdx);
#else // 1.39Mclk
		jnc("@f");
		mov(gt1, gt5);
		mov(gt2, gt6);
		mov(gt3, gt7);
		mov(gt4, rdx);
	L("@@");
#endif
	}
	/*
		input rax : &s_pTbl[1]
		destroy gt1, ..., gt7, rdx
	*/
	void in_Fp_add(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		load_add_rm(gt4, gt3, gt2, gt1, mx, my, false);

		in_Fp_add_modp();
		store_mr(mz, gt4, gt3, gt2, gt1);
	}
	/*
		input rax = &s_pTbl[1], gt[4, 3, 2, 1]
		output gt[4, 3, 2, 1] mod p
		destroy gt5, gt6, gt7, rdx
	*/
	void in_Fp_sub_modp()
	{
#if 1
#if 1 // 1.36Mclk
		sbb(rdx, rdx);
		mov(gt5, rdx);
		mov(gt6, rdx);
		mov(gt7, rdx);
		and_(rdx, qword [rax + 8 * 0]);
		and_(gt5, qword [rax + 8 * 1]);
		and_(gt6, qword [rax + 8 * 2]);
		and_(gt7, qword [rax + 8 * 3]);
#else
		// 1.37Mclk
		mov(rdx, 0);
		mov(gt5, rdx);
		mov(gt6, rdx);
		mov(gt7, rdx);
		cmovc(rdx, qword [rax + 8 * 0]);
		cmovc(gt5, qword [rax + 8 * 1]);
		cmovc(gt6, qword [rax + 8 * 2]);
		cmovc(gt7, qword [rax + 8 * 3]);
#endif
		add_rr(gt4, gt3, gt2, gt1, gt7, gt6, gt5, rdx);
#else
		jnc("@f");
		add_rm(gt4, gt3, gt2, gt1, rax);
	L("@@");
#endif
	}
	/*
		input rax : &s_pTbl[1]
		destroy gt1, ..., gt7, rdx
	*/
	void in_Fp_sub(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		load_sub_rm(gt4, gt3, gt2, gt1, mx, my, false);
		in_Fp_sub_modp();
		store_mr(mz, gt4, gt3, gt2, gt1);
	}
	/*
		destroy gt1, ..., gt7, rdx, rax
	*/
	void in_FpDbl_add(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		mov(rax, (uint64_t)&s_pTbl[1]);
		in_Fp_addNC(mz, mx, my);
		load_add_rm(gt4, gt3, gt2, gt1, mx + sizeof(Fp), my + sizeof(Fp), true);
		in_Fp_add_modp();
		store_mr(mz + 32, gt4, gt3, gt2, gt1);
	}
	/*
		destroy gt1, ..., gt7, rdx, rax
	*/
	void sub_FpDbl_sub(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		mov(rax, (uint64_t)&s_pTbl[1]);
		in_Fp_subNC(mz, mx, my);
		load_sub_rm(gt4, gt3, gt2, gt1, mx + sizeof(Fp), my + sizeof(Fp), true);
		in_Fp_sub_modp();
		store_mr(mz + 32, gt4, gt3, gt2, gt1);
	}
	void in_FpDbl_sub(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		smart_set_gp(mz, mx, my);
		call(p_FpDbl_sub);
	}
	void set_p_FpDbl_add()
	{
		align(16);
		p_FpDbl_add = (void*)const_cast<uint8_t*>(getCurr());
		in_FpDbl_add(gp1, gp2, gp3);
		ret();
	}
	void set_p_FpDbl_addNC()
	{
		align(16);
		p_FpDbl_addNC = (void*)const_cast<uint8_t*>(getCurr());
		in_Fp_addNC(gp1, gp2, gp3);
		in_Fp_adcNC(gp1 + 32, gp2 + 32, gp3 + 32);
		ret();
	}
	void set_p_FpDbl_subNC()
	{
		align(16);
		p_FpDbl_subNC = (void*)const_cast<uint8_t*>(getCurr());
		in_Fp_subNC(gp1, gp2, gp3);
		in_Fp_sbbNC(gp1 + 32, gp2 + 32, gp3 + 32);
		ret();
	}
	void in_Fp2Dbl_add(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		smart_set_gp(mz, mx, my);
		call(p_FpDbl_add);
		add(gp1, 64);
		add(gp2, 64);
		add(gp3, 64);
		call(p_FpDbl_add);
	}
	void set_p_FpDbl_sub()
	{
		align(16);
		p_FpDbl_sub = (void*)const_cast<uint8_t*>(getCurr());
		sub_FpDbl_sub(gp1, gp2, gp3);
		ret();
	}
	void in_Fp2Dbl_sub(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		smart_set_gp(mz, mx, my);
		call(p_FpDbl_sub);
		add(gp1, 64);
		add(gp2, 64);
		add(gp3, 64);
		call(p_FpDbl_sub);
	}
	void in_Fp_add(int n, const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		mov(rax, (uint64_t)&s_pTbl[1]);
		for (int i = 0; i < n; i++) {
			in_Fp_add(mz + 32 * i, mx + 32 * i, my + 32 * i);
		}
	}

	void in_Fp_neg(const RegExp& mz, const RegExp& mx)
	{
		load_rm(gt4, gt3, gt2, gt1, mx);
		mov(rdx, gt1);
		or_(rdx, gt2);
		or_(rdx, gt3);
		or_(rdx, gt4);
		jz("@f");
		load_sub_rm(gt4, gt3, gt2, gt1, rax, mx, false);
L("@@");
		store_mr(mz, gt4, gt3, gt2, gt1);
	}
	void in_Fp_neg(int n, const RegExp& mz, const RegExp& mx)
	{
		mov(rax, (uint64_t)&s_pTbl[1]);
		for (int i = 0; i < n; i++) {
			in_Fp_neg(mz + 32 * i, mx + 32 * i);
		}
	}
	void in_Fp2_neg(const RegExp& mz, const RegExp& mx)
	{
		// smart_set_gp for only two arguments.
		lea(gp1, ptr [mz]);
		if (mx == mz) {
			mov(gp2, gp1);
		} else {
			lea(gp2, ptr [mx]);
		}

		call(p_Fp2_neg);
	}
	void set_p_Fp2_neg()
	{
		align(16);
		p_Fp2_neg = (void*)const_cast<uint8_t*>(getCurr());
		in_Fp_neg(2, gp1, gp2);
		ret();
	}

	void in_Fp2_add(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		smart_set_gp(mz, mx, my);
		call(p_Fp2_add);
	}
	void in_Fp2_sub(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		smart_set_gp(mz, mx, my);
		call(p_Fp2_sub);
	}
	void set_p_Fp2_addNC()
	{
		align(16);
		p_Fp2_addNC = (void*)const_cast<uint8_t*>(getCurr());
		in_Fp_addNC(gp1, gp2, gp3);
		in_Fp_addNC(gp1 + 32, gp2 + 32, gp3 + 32);
		ret();
	}
	void set_p_Fp2_add()
	{
		align(16);
		p_Fp2_add = (void*)const_cast<uint8_t*>(getCurr());
		in_Fp_add(2, gp1, gp2, gp3);
		ret();
	}
	void set_p_Fp2_sub()
	{
		align(16);
		p_Fp2_sub = (void*)const_cast<uint8_t*>(getCurr());
		in_Fp_sub(2, gp1, gp2, gp3);
		ret();
	}
	void in_Fp2_addNC(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		smart_set_gp(mz, mx, my);
		call(p_Fp2_addNC);
	}
	void in_Fp_sub(int n, const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		mov(rax, (uint64_t)&s_pTbl[1]);
		for (int i = 0; i < n; i++) {
			in_Fp_sub(mz + 32 * i, mx + 32 * i, my + 32 * i);
		}
	}
	void in_FpDbl_add(int n, const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		for (int i = 0; i < n; i++) {
			in_FpDbl_add(mz + 64 * i, mx + 64 * i, my + 64 * i);
		}
	}
	void in_FpDbl_addNC(int n, const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		for (int i = 0; i < n; i++) {
			in_FpDbl_addNC(mz + 64 * i, mx + 64 * i, my + 64 * i);
		}
	}
	void in_FpDbl_sub(int n, const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		for (int i = 0; i < n; i++) {
			sub_FpDbl_sub(mz + 64 * i, mx + 64 * i, my + 64 * i);
		}
	}

	/*
		add(uint64_t z[4], const uint64_t x[4], const uint64_t y[4]);
		z[3..0] = (y[3..0] + x[3..0]) % p
		@note accept z == y or z == x
	*/
	void make_Fp_add(int n)
	{
		MakeStackFrame<> sf(this, 7);
		in_Fp_add(n, gp1, gp2, gp3);
	}
	void make_Fp_sub(int n)
	{
		MakeStackFrame<> sf(this, 7);
		in_Fp_sub(n, gp1, gp2, gp3);
	}
	void set_p_Fp6_add()
	{
		align(16);
		p_Fp6_add = (void*)const_cast<uint8_t*>(getCurr());
		in_Fp_add(6, gp1, gp2, gp3);
		ret();
	}
	void make_Fp6_add()
	{
		MakeStackFrame<> sf(this, 7);
		call(p_Fp6_add);
	}
	void set_p_Fp6_sub()
	{
		align(16);
		p_Fp6_sub = (void*)const_cast<uint8_t*>(getCurr());
		in_Fp_sub(6, gp1, gp2, gp3);
		ret();
	}
	void make_Fp6_sub()
	{
		MakeStackFrame<> sf(this, 7);
		call(p_Fp6_sub);
	}

	void make_Fp_neg()
	{
#ifdef _WIN32
		const Reg64& z = rcx;
		const Reg64& x = rdx;
#else
		const Reg64& z = rdi;
		const Reg64& x = rsi;
#endif
		const Reg64& z3 = r8;
		const Reg64& z2 = r9;
		const Reg64& z1 = r10;
		const Reg64& z0 = r11;

		load_rm(z3, z2, z1, z0, x);
		mov(rax, z0);
		or_(rax, z1);
		or_(rax, z2);
		or_(rax, z3);
		jz("@f");
		mov(rax, (uint64_t)&s_pTbl[1]);
		load_sub_rm(z3, z2, z1, z0, rax, x, false);
	L("@@");
		store_mr(z, z3, z2, z1, z0);
		ret();
	}
	/*
		[x3:x2:x1:x0] >>= n
	*/
	void shrn(const Reg64& x3, const Reg64& x2, const Reg64& x1, const Reg64& x0, uint8 n)
	{
		shrd(x0, x1, n); // x0 = [x1:x0] >> n
		shrd(x1, x2, n); // x1 = [x2:x1] >> n
		shrd(x2, x3, n); // x2 = [x3:x2] >> n
		shr(x3, n); // x3 >> n
	}
	/*
		[x3:x2:x1:x0] >>= 1
	*/
	void shr1(const Reg64& x3, const Reg64& x2, const Reg64& x1, const Reg64& x0)
	{
		shrn(x3, x2, x1, x0, 1);
	}
	/*
		[x3:x2:x1:x0] <<= 1
	*/
	void shl1(const Reg64& x3, const Reg64& x2, const Reg64& x1, const Reg64& x0)
	{
		add_rr(x3, x2, x1, x0, x3, x2, x1, x0);
	}
	/*
		input : gp1, gp2, rax = s_pTbl[1]
		destroy : rdx, gt1, ..., gt7
	*/
	void sub_Fp_divBy2(const RegExp& z, const RegExp& x)
	{
		mov(rdx, ptr [x]);
		and_(rdx, 1); // x[0] & 1
		shl(rdx, 5); // * 32
		load_rm(gt4, gt3, gt2, gt1, x);
		shr1(gt4, gt3, gt2, gt1);
		mov(gt5, (uint64_t)Fp::halfTbl_);
		add(rdx, gt5);
		add_rm(gt4, gt3, gt2, gt1, rdx);
		store_mr(z, gt4, gt3, gt2, gt1);
	}
	void set_p_Fp2_divBy2()
	{
		align(16);
		p_Fp2_divBy2 = (void*)const_cast<uint8_t*>(getCurr());
		const Reg64& z = gp1;
		const Reg64& x = gp2;
		mov(rax, (uint64_t)&s_pTbl[1]);
		sub_Fp_divBy2(z, x);
		sub_Fp_divBy2(z + 32, x + 32);
		ret();
	}
	void make_Fp2_divBy2()
	{
		MakeStackFrame<> sf(this, 7);
		call(p_Fp2_divBy2);
	}
	/*
		x[3:2:1:0] <<= 1
	*/
	void shl1(const Reg64& x, const Reg64& t)
	{
		mov(t, ptr [x + 8 * 0]);
		add(ptr [x + 8 * 0], t);
		mov(t, ptr [x + 8 * 1]);
		adc(ptr [x + 8 * 1], t);
		mov(t, ptr [x + 8 * 2]);
		adc(ptr [x + 8 * 2], t);
		mov(t, ptr [x + 8 * 3]);
		adc(ptr [x + 8 * 3], t);
	}
	void make_Fp_shr(uint8 n = 1)
	{
#ifdef _WIN32
		const Reg64& z = rcx;
		const Reg64& x = rdx;
#else
		const Reg64& z = rdi;
		const Reg64& x = rsi;
#endif
		const Reg64& z3 = r8;
		const Reg64& z2 = r9;
		const Reg64& z1 = r10;
		const Reg64& z0 = r11;
		load_rm(z3, z2, z1, z0, x);
		shrn(z3, z2, z1, z0, n);
		store_mr(z, z3, z2, z1, z0);
		ret();
	}
	/*
		[d:x:t2:t1:t0] <- py[3:2:1:0] * x
		destroy x, t
	*/
	void mul4x1(const RegExp& py, const Reg64& x, const Reg64& t3, const Reg64& t2, const Reg64& t1, const Reg64& t0,
		const Reg64& t)
	{
		const Reg64& a = rax;
		const Reg64& d = rdx;
		if (g_useMulx) {
			mov(d, x);
			mulx(t1, t0, ptr [py + 8 * 0]);
			mulx(t2, a, ptr [py + 8 * 1]);
			add(t1, a);
			mulx(x, a, ptr [py + 8 * 2]);
			adc(t2, a);
			mulx(d, a, ptr [py + 8 * 3]);
			adc(x, a);
			adc(d, 0);
			return;
		}
		mov(a, ptr [py]);
		mul(x);
		mov(t0, a);
		mov(t1, d);
		mov(a, ptr [py + 8]);
		mul(x);
		mov(t, a);
		mov(t2, d);
		mov(a, ptr [py + 8 * 2]);
		mul(x);
		mov(t3, a);
		mov(a, x);
		mov(x, d);
		mul(qword [py + 8 * 3]);
		add(t1, t);
		adc(t2, t3);
		adc(x, a);
		adc(d, 0);
	}

	/*
		c = [c4:c3:c2:c1:c0]
		c += x[3..0] * y
		q = uint64_t(c0 * pp)
		c = (c + q * p) >> 64
		input  [c4:c3:c2:c1:c0], px, y, p
		output [c0:c4:c3:c2:c1]

		@note use rax, rdx, destroy y
		@note max([c4:c3:c2:c1:c0]) = 2p - 1, ie. c4 = 0 or 1
	*/
	void montgomery1(const Reg64& c4, const Reg64& c3, const Reg64& c2, const Reg64& c1, const Reg64& c0,
		const Reg64& px, const Reg64& y, const Reg64& p,
		const Reg64& t0, const Reg64& t1, const Reg64& t2, const Reg64& t3, const Reg64& t4, bool isFirst)
	{
		const Reg64& a = rax;
		const Reg64& d = rdx;
		if (isFirst) {
			mul4x1(px, y, c3, c2, c1, c0, c4);
			mov(c4, d);
			// [c4:y:c2:c1:c0] = px[3..0] * y
		} else {
			mul4x1(px, y, t3, t2, t1, t0, t4);
			// [d:y:t2:t1:t0] = px[3..0] * y
			add_rr(y, c2, c1, c0, c3, t2, t1, t0);
			adc(c4, d);
		}
		mov(rax, pp_);
		mul(c0); // q = a
		mov(c3, a);
		mul4x1(p, c3, t3, t2, t1, t0, t4);
		add(c0, t0);
//		mov(c0, 0); // c0 is always zero because Montgomery reduction
		adc(c1, t1);
		adc(c2, t2);
		adc(c3, y);
		adc(c4, d);
		adc(c0, 0);
	}
	/*
		input (z, x, y) = (gp1, gp2, gp3)
		z[0..3] <- montgomery(x[0..3], y[0..3])
		destroy gt1, ..., gt10, xm0, xm1, gp3
	*/
	void Fp_mul()
	{
#ifdef DEBUG_COUNT
		upCount(&g_count_m256);
		upCount(&g_count_r512);
#endif
		movq(xm0, gp1); // save gp1
		mov(gp1, (uint64_t)&s_pTbl[1]);
		movq(xm1, gp3);
		mov(gp3, ptr [gp3]);
		montgomery1(gt1, gt8, gt4, gt3, gt2, gp2, gp3, gp1, gt5, gt6, gt7, gt9, gt10, true);

		movq(gp3, xm1);
		mov(gp3, ptr [gp3 + 8]);
		montgomery1(gt2, gt1, gt8, gt4, gt3, gp2, gp3, gp1, gt5, gt6, gt7, gt9, gt10, false);

		movq(gp3, xm1);
		mov(gp3, ptr [gp3 + 16]);
		montgomery1(gt3, gt2, gt1, gt8, gt4, gp2, gp3, gp1, gt5, gt6, gt7, gt9, gt10, false);

		movq(gp3, xm1);
		mov(gp3, ptr [gp3 + 24]);
		montgomery1(gt4, gt3, gt2, gt1, gt8, gp2, gp3, gp1, gt5, gt6, gt7, gt9, gt10, false);
		// [gt8:gt4:gt3:gt2:gt1]

		mov(gt5, gt1);
		mov(gt6, gt2);
		mov(gt7, gt3);
		mov(rdx, gt4);
		sub_rm(gt4, gt3, gt2, gt1, gp1);
		cmovc(gt1, gt5);
		cmovc(gt2, gt6);
		cmovc(gt3, gt7);
		cmovc(gt4, rdx);

		movq(gp1, xm0); // load gp1
		store_mr(gp1, gt4, gt3, gt2, gt1);
	}
	void set_p_Fp_mul()
	{
		align(16);
		// (gp1, gp2, gp3), destory gp3
		p_Fp_mul = (void*)const_cast<uint8_t*>(getCurr());
		Fp_mul();
		ret();
	}
	void set_p_FpDbl_mod()
	{
		align(16);
		p_FpDbl_mod = (void*)const_cast<uint8_t*>(getCurr());
		mont_mod();
		ret();
	}
	// call:32
	void make_Fp_mul()
	{
		MakeStackFrame<> sf(this, 10);
		call(p_Fp_mul);
	}
	// call:32
	void make_Fp2_mul_Fp_0()
	{
		MakeStackFrame<> sf(this, 10);
		movq(xm2, gp3);
		call(p_Fp_mul); // mul(z.a_, x.a_, b);
		movq(gp3, xm2);
		add(gp1, sizeof(Fp));
		add(gp2, sizeof(Fp));
		call(p_Fp_mul); // mul(z.b_, x.b_, b);
	}

	/*
		pz[7..0] <- px[3..0] * py[3..0]
	*/
	void mul4x4(const RegExp& pz, const RegExp& px, const RegExp& py,
		const Reg64& t9, const Reg64& t8, const Reg64& t7, const Reg64& t6, const Reg64& t5, const Reg64& t4, const Reg64& t3, const Reg64& t2, const Reg64& t1, const Reg64& t0)
	{
#ifdef DEBUG_COUNT
		upCount(&g_count_m256);
#endif
		const Reg64& a = rax;
		const Reg64& d = rdx;

		if (g_useMulx) {
			mov(d, ptr [px]);
			mulx(t0, a, ptr [py + 8 * 0]);
			mov(ptr [pz + 8 * 0], a);
			mulx(t1, a, ptr [py + 8 * 1]);
			add(t0, a);
			mulx(t2, a, ptr [py + 8 * 2]);
			adc(t1, a);
			mulx(t3, a, ptr [py + 8 * 3]);
			adc(t2, a);
			adc(t3, 0);
		} else {
			mov(t5, ptr [px]);
			mov(a, ptr [py + 8 * 0]);
			mul(t5);
			mov(ptr [pz + 8 * 0], a);
			mov(t0, d);
			mov(a, ptr [py + 8 * 1]);
			mul(t5);
			mov(t3, a);
			mov(t1, d);
			mov(a, ptr [py + 8 * 2]);
			mul(t5);
			mov(t4, a);
			mov(t2, d);
			mov(a, ptr [py + 8 * 3]);
			mul(t5);
			add(t0, t3);
			mov(t3, 0);
			adc(t1, t4);
			adc(t2, a);
			adc(t3, d); // [t3:t2:t1:t0:pz[0]] = px[0] * py[3..0]
		}

		// here [t3:t2:t1:t0]

		mov(t9, ptr [px + 8]);

		// [d:t9:t7:t6:t5] = px[1] * py[3..0]
		mul4x1(py, t9, t8, t7, t6, t5, t4);
		add_rr(t3, t2, t1, t0, t9, t7, t6, t5);
		adc(d, 0);
		mov(t8, d);
		mov(ptr [pz + 8], t0);
		// here [t8:t3:t2:t1]

		mov(t9, ptr [px + 16]);

		// [d:t9:t6:t5:t4]
		mul4x1(py, t9, t7, t6, t5, t4, t0);
		add_rr(t8, t3, t2, t1, t9, t6, t5, t4);
		adc(d, 0);
		mov(t7, d);
		mov(ptr [pz + 16], t1);

		mov(t9, ptr [px + 24]);

		// [d:t9:t5:t4:t1]
		mul4x1(py, t9, t6, t5, t4, t1, t0);
		add_rr(t7, t8, t3, t2, t9, t5, t4, t1);
		adc(d, 0);
		store_mr(pz + 8 * 3, t7, t8, t3, t2);
		mov(ptr [pz + 8 * 7], d);
	}

	/*
		@input (z, x) = (gp1, gp2)
		z[3..0] = Montgomery reduction(x[7..0])
		@note destroy rax, rdx, gt1, ..., gt10, gp3, xm0, xm1
	*/
	void mont_mod()
	{
#ifdef DEBUG_COUNT
		upCount(&g_count_r512);
#endif
		const Reg64& a = rax;
		const Reg64& d = rdx;

		movq(xm0, gp1);
		mov(gp1, ptr [gp2 + 8 * 0]);

		mov(a, pp_);
		mul(gp1);
		mov(gp3, (uint64_t)&s_pTbl[1]);
		mov(gt7, a); // q

		// [d:gt7:gt3:gt2:gt1] = p * q
		mul4x1(gp3, gt7, gt4, gt3, gt2, gt1, gt8);

		add(gt1, gp1);
		adc(gt2, qword [gp2 + 8 * 1]);
		adc(gt3, qword [gp2 + 8 * 2]);
		adc(gt7, qword [gp2 + 8 * 3]);
		mov(gt4, ptr [gp2 + 8 * 4]);
		adc(gt4, d);
		mov(gt8, ptr [gp2 + 8 * 5]);
		adc(gt8, 0);
		mov(gt9, ptr [gp2 + 8 * 6]);
		adc(gt9, 0);
		mov(gt10, ptr [gp2 + 8 * 7]);
		adc(gt10, 0); // c' = [gt10:gt9:gt8:gt4:gt7:gt3:gt2]

		// free gp1, gt1, gt5, gp2, gt6

		mov(a, pp_);
		mul(gt2);
		mov(gp1, a); // q

		movq(xm1, gt10);
		// [d:gp1:gt5:gp2:gt6] = p * q
		mul4x1(gp3, gp1, gt1, gt5, gp2, gt6, gt10);
		movq(gt10, xm1);

		add_rr(gt4, gt7, gt3, gt2, gp1, gt5, gp2, gt6);
		adc(gt8, d);
		adc(gt9, 0);
		adc(gt10, 0); // c' = [gt10:gt9:gt8:gt4:gt7:gt3]

		// free gp1, gt1, gt2, gt5, gp2, gt6

		mov(a, pp_);
		mul(gt3);
		mov(gp1, a); // q

		// [d:gp1:gt5:gp2:gt6] = p * q
		mul4x1(gp3, gp1, gt1, gt5, gp2, gt6, gt2);

		add_rr(gt8, gt4, gt7, gt3, gp1, gt5, gp2, gt6);
		adc(gt9, d);
		adc(gt10, 0); // c' = [gt10:gt9:gt8:gt4:gt7]

		// free gp1, gt1, gt2, gt7, gt5, gp2, gt6

		mov(a, pp_);
		mul(gt7);
		mov(gp1, a); // q

		// [d:gp1:gt5:gp2:gt6] = p * q
		mul4x1(gp3, gp1, gt1, gt5, gp2, gt6, gt2);

		add_rr(gt9, gt8, gt4, gt7, gp1, gt5, gp2, gt6);
		adc(gt10, d); // c' = [gt10:gt9:gt8:gt4]

		mov(gp1, gt4);
		mov(gt1, gt8);
		mov(gt2, gt9);
		mov(gt3, gt10);
		sub_rm(gt10, gt9, gt8, gt4, gp3);
		cmovc(gt4, gp1);
		cmovc(gt8, gt1);
		cmovc(gt9, gt2);
		cmovc(gt10, gt3);

		movq(gp1, xm0);
		store_mr(gp1, gt10, gt9, gt8, gt4);
	}
#ifdef BN_SUPPORT_SNARK
	/*
		[mz] = ([mx] * 9 + [my]) mod p if doAdd is true
		[mz] = ([mx] * 9 + p - [my]) mod p if doAdd is false
	*/
	void in_Fp_mul_xi_addsub(const RegExp& mz, const RegExp& mx, const RegExp& my, bool doAdd)
	{
		/*
			require p * 10 < (1<<258) because sizeof(s_pTbl[0]) == 32
			x *= 9
			pTop = (p >> 193) + 1  # 0x183227397098d015
			pRev = (1<<124) / pTop # 0xa948e8c4c474094e
			def f(x):
				return ((x>>193) * pRev) >> 124
		*/
		const uint64_t pRev = uint64_t(0xa948e8c4c474094eLL);
		mov(gt4, 9);
		// [d:gt4:gt3:gt2:gt1] = [mx] * 9
		mul4x1(mx, gt4, gt5, gt3, gt2, gt1, gt6);
		if (doAdd) {
			add_rm(gt4, gt3, gt2, gt1, my);
			adc(d, 0);
		} else {
			mov(rax, (uint64_t)&s_pTbl[1]);
			add_rm(gt4, gt3, gt2, gt1, rax);
			adc(d, 0); // [mx] * 9 + p
			sub_rm(gt4, gt3, gt2, gt1, my);
			sbb(d, 0); // [mx] * 9 + p - [my]
		}
		// d = [d:gt4] >> 1 = x >> 193
		shld(d, gt4, 63);
		mov(rax, pRev);
		mul(d);
		shr(d, 60); // f(x)
		shl(d, 5);
		mov(rax, (uint64_t)&s_pTbl[1]);
		// use only 256bit value(d is not necessary)
		sub_rm(gt4, gt3, gt2, gt1, rax - 32 + rdx); // 0 <= [gt4:gt3:gt2:gt1] < 2p
		in_Fp_add_modp();
		store_mr(mz, gt4, gt3, gt2, gt1);
	}
#endif

	void in_Fp2_mul_xi(const RegExp& mz, const RegExp& mx)
	{
		mov(rax, (uint64_t)&s_pTbl[1]);
#ifdef BN_SUPPORT_SNARK
#if 1
		// 133clk -> 66clk
		in_Fp_mul_xi_addsub(mz, mx, mx + 32, false);
		in_Fp_mul_xi_addsub(mz + 32, mx + 32, mx, true);
#else
		in_Fp_add(mz, mx, mx); // 2
		in_Fp_add(mz, mz, mz); // 4
		in_Fp_add(mz, mz, mz); // 8
		in_Fp_add(mz, mz, mx); // 9
		in_Fp_sub(mz, mz, mx + 32);

		in_Fp_add(mz + 32, mx + 32, mx + 32); // 2
		in_Fp_add(mz + 32, mz + 32, mz + 32); // 4
		in_Fp_add(mz + 32, mz + 32, mz + 32); // 8
		in_Fp_add(mz + 32, mz + 32, mx + 32); // 9
		in_Fp_add(mz + 32, mz + 32, mx);
#endif
#else
		in_Fp_sub(mz, mx, mx + 32);
		in_Fp_add(mz + 32, mx, mx + 32);
#endif
	}
	void make_Fp2_mul_xi()
	{
		MakeStackFrame<> sf(this, 7);
		in_Fp2_mul_xi(gp1, gp2);
	}

	/*
		destroy : gt1, gt2, gt3, gt4, rdx(, rax)
		memo : gp3 is free
	*/
	void in_FpDbl_neg(const RegExp& mz, const RegExp& mx)
	{
		inLocalLabel();
		load_rm(gt4, gt3, gt2, gt1, mx);
		mov(rdx, gt4);
		or_(rdx, gt3);
		or_(rdx, gt2);
		or_(rdx, gp1);
		load_rm(gt4, gt3, gt2, gt1, mx + 32);
		or_(rdx, gt4);
		or_(rdx, gt3);
		or_(rdx, gt2);
		or_(rdx, gp1);
#ifdef DEBUG_COUNT
		jnz(".neg", T_NEAR);
#else
		jnz(".neg");
#endif
		// all zero
		store_mr(mz, rdx, rdx, rdx, rdx);
		store_mr(mz + 32, rdx, rdx, rdx, rdx);
#ifdef DEBUG_COUNT
		jmp(".exit", T_NEAR);
#else
		jmp(".exit");
#endif
	L(".neg");
		mov(rax, (uint64)&s_pTbl[0]); // rax refers to pN, lower 256-bits are zero.
		in_Fp_subNC(mz, rax, mx);
		in_Fp_sbbNC(mz + 32, rax + 32, mx + 32);
	L(".exit");
		outLocalLabel();
	}
	void make_FpDbl_neg()
	{
		MakeStackFrame<> sf(this, 4);
		in_FpDbl_neg(gp1, gp2);
	}
	void make_Fp2Dbl_neg()
	{
		MakeStackFrame<> sf(this, 4);
		in_FpDbl_neg(gp1, gp2);
		in_FpDbl_neg(gp1 + 64, gp2 + 64);
	}

	/*
		pz[7..0] <- (px[7..0] + py[7..0]) mod pN
	*/
	void make_FpDbl_add(int n)
	{
		MakeStackFrame<> sf(this, 7);
		in_FpDbl_add(n, gp1, gp2, gp3);
	}
	/*
		pz[7..0] <- (px[7..0] - py[7..0]) mod pN
	*/
	void make_FpDbl_sub(int n)
	{
		MakeStackFrame<> sf(this, 7);
		in_FpDbl_sub(n, gp1, gp2, gp3);
	}

	/*
		z[7..0] <- x[7..0] + y[7..0],
	*/
	void make_FpDbl_addNC(int n)
	{
		MakeStackFrame<> sf(this, 7);
		in_FpDbl_addNC(n, gp1, gp2, gp3);
	}
	/*
		z[7..0] <- x[7..0] - y[7..0],
	*/
	void make_FpDbl_subNC(int n)
	{
		MakeStackFrame<> sf(this, 7);
		for (int i = 0; i < n; i++) {
			in_Fp_subNC(gp1 + 64 * i, gp2 + 64 * i, gp3 + 64 * i);
			in_Fp_sbbNC(gp1 + 64 * i + 32, gp2 + 64 * i + 32, gp3 + 64 * i + 32);
		}
	}
	void in_Fp2Dbl_mul_xi(const RegExp& mz, const RegExp& mx)
	{
		mov(rax, (uint64_t)&s_pTbl[1]);
		lea(gp1, ptr [mz]);
		lea(gp2, ptr [mx]);
		call(p_Fp2Dbl_mul_xi);
	}
	void make_Fp2Dbl_mul_xi()
	{
		MakeStackFrame<> sf(this, 7);
		call(p_Fp2Dbl_mul_xi);
	}

	/*
		pz[7..0] <- px[3..0] * py[3..0]
	*/
	void make_FpDbl_mul()
	{
		MakeStackFrame<> sf(this, 10);
		mul4x4(gp1, gp2, gp3, gt9, gt8, gt7, gt6, gt5, gt4, gt3, gt2, gt1, gt10);
	}

	/*
		pz[3..0] <- mont_mod(px[7..0])
	*/
	void make_FpDbl_mod()
	{
		MakeStackFrame<> sf(this, 10);
		call(p_FpDbl_mod);
	}
	/*
		use xm0, xm1, xm2
	*/
	void in_Fp2Dbl_mod()
	{
		movq(xm2, gp2);
		call(p_FpDbl_mod);

		movq(gp2, xm2);
		add(gp2, 32 * 2);
		add(gp1, 32);
		call(p_FpDbl_mod);
	}
	/*
		pz[3..0] <-	mont_mod(px[7..0]),
		pz[7..4] <- mont_mod(px[15..8]).
	*/
	void make_Fp2Dbl_mod()
	{
		MakeStackFrame<> sf(this, 10);
		in_Fp2Dbl_mod();
	}
	/*
		input [x3:x2:x1:x0] < 6p
		output [x3:x2:x1:x0] % p
		destroy rax, rdx, t0, t1, t2, t3
		(i*p) >> 253 = 0,1,2,3,4,5,6 for i = 0, .., 6
		t = (i * p) >> 253
	*/
	void fast_modp(
		const Reg64& x3, const Reg64& x2, const Reg64& x1, const Reg64& x0,
		const Reg64& t0, const Reg64& t1, const Reg64& t2, const Reg64& t3)
	{
		const Reg64& a = rax;
		mov(rdx, x3);
		shr(rdx, 61); // rdx = [0:x3_63:x3_62:x3_61]

		shl(rdx, 5); // sizeof(Fp) = 32
		mov(a, (uint64_t)&s_pTbl[0]);
		sub_rm(x3, x2, x1, x0, a + rdx);
		sbb(rdx, rdx);

		load_rm(t3, t2, t1, t0, a + sizeof(Fp));
		and_(t0, rdx);
		and_(t1, rdx);
		and_(t2, rdx);
		and_(t3, rdx); // [t3:t2:t1:t0] = x < 0 ? p : 0
		add_rr(x3, x2, x1, x0, t3, t2, t1, t0);
	}

	// (z, x) = (gp1, gp2)
	// call:295
	void set_p_Fp2_square()
	{
		align(16);
		p_Fp2_square = (void*)const_cast<uint8_t*>(getCurr());
		in_Fp2_square();
		ret();
	}
	// 278clk x 295
	void in_Fp2_square()
	{
//begin_clock();
		const Ext2<Fp> z(gp1);
		const Ext2<Fp> x(gp2);
		const Ext1<Fp> t(rsp);
		const Ext1<FpDbl> d0(rsp, t.next);
		const Ext1<FpDbl> d1(rsp, d0.next);
		const int SS = d1.next;
		sub(rsp, SS);

#ifdef BN_SUPPORT_SNARK
		mov(rax, (uint64_t)&s_pTbl[1]);
		load_rm(gt4, gt3, gt2, gt1, x.b_);
		add_rr(gt4, gt3, gt2, gt1, gt4, gt3, gt2, gt1);
		in_Fp_add_modp(); // XITAG
		store_mr(t, gt4, gt3, gt2, gt1); // t = 2 * b

		// d0 = t[3..0] * a
		mul4x4(d0, t, x, gt10, gt9, gt8, gt7, gt6, gt5, gt4, gt3, gt2, gt1);

		mov(rax, (uint64_t)&s_pTbl[1]);

		load_add_rm(gt4, gt3, gt2, gt1, x.a_, rax, false); // t = a + p
		sub_rm(gt4, gt3, gt2, gt1, x.b_); // a + p - b
		store_mr(t, gt4, gt3, gt2, gt1); // t = a + p - b

		in_Fp_add(z.a_, x.a_, x.b_);
#else
		load_rm(gt4, gt3, gt2, gt1, x.b_);
		add_rr(gt4, gt3, gt2, gt1, gt4, gt3, gt2, gt1);
		store_mr(t, gt4, gt3, gt2, gt1); // t = 2 * b

		// d0 = t[3..0] * a
		mul4x4(d0, t, x, gt10, gt9, gt8, gt7, gt6, gt5, gt4, gt3, gt2, gt1);

		mov(rax, (uint64_t)&s_pTbl[1]);

		load_add_rm(gt4, gt3, gt2, gt1, x.a_, rax, false); // t = a + p
		sub_rm(gt4, gt3, gt2, gt1, x.b_); // a + p - b
		store_mr(t, gt4, gt3, gt2, gt1); // t = a + p - b

		in_Fp_add_carry(z.a_, x.a_, x.b_, false); // z.a_ = a + b
#endif
		// d1 = (a + p - b)(a + b)
		mul4x4(d1, t, z.a_, gt10, gt9, gt8, gt7, gt6, gt5, gt4, gt3, gt2, gt1);

		lea(gp2, ptr [d1]);
//		mont_mod();
		call(p_FpDbl_mod);

		lea(gp2, ptr [d0]);
		add(gp1, 8 * 4);
//		mont_mod();
		call(p_FpDbl_mod);
		add(rsp, SS);
//end_clock();
	}
	/*
		square(Fp2& z, const Fp2& x)
		z = x * x
	*/
	void make_Fp2_square()
	{
		MakeStackFrame<> sf(this, 10);
		call(p_Fp2_square);
	}
	/*
		pz[7..0] -= px[7..0]
	*/
	void sub_Fp2Dbl_subNC(const RegExp& pz, const RegExp& px,
		const Reg64& t3, const Reg64& t2, const Reg64& t1, const Reg64& t0)
	{
		load_sub_rm(t3, t2, t1, t0, pz, px, false);
		store_mr(pz + 8 * 0, t3, t2, t1, t0);

		load_sub_rm(t3, t2, t1, t0, pz + sizeof(Fp), px + sizeof(Fp), true);
		store_mr(pz + sizeof(Fp), t3, t2, t1, t0);
	}

	/*
		destroy : rax, gt1, ..., gt7
		addNC(z, x, pN);
		subNC(z, z, y);
	*/
	void in_FpDbl_subOpt1(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		mov(rax, (uint64)&Fp::Dbl::pNTbl_[2]);
		load_rm(gt4, gt3, gt2, gt1, mx);
		// 192-bits lower value of pNTbl_[2] is zero
		add(gt4, ptr [rax + 8 * 3]); // add_rm(gt4, gt3, gt2, gt1, rax + 8 * 3);
		load_add_rm(rdx, gt7, gt6, gt5, mx + sizeof(Fp), rax + sizeof(Fp), true);
		sub_rm(gt4, gt3, gt2, gt1, my);
		store_mr(mz, gt4, gt3, gt2, gt1);
		sbb_rm(rdx, gt7, gt6, gt5, my + sizeof(Fp));
		store_mr(mz + 32, rdx, gt7, gt6, gt5);
	}

	// 359clk x 290
	void set_p_Fp2_mul()
	{
		align(16);
		p_Fp2_mul = (void*)const_cast<uint8_t*>(getCurr());
//begin_clock();

		const Ext2<Fp> z(gp1);
		const Ext2<Fp> x(gp2);
		const Ext2<Fp> y(gp3);

		const Ext1<Fp> s(rsp);
		const Ext1<Fp> t(rsp, s.next);
		const Ext1<FpDbl> d0(rsp, t.next);
		const Ext1<FpDbl> d1(rsp, d0.next);
		const Ext1<FpDbl> d2(rsp, d1.next);
		const int SS = d2.next;
		sub(rsp, SS);
		// x.a_ + x.b_
		in_Fp_addNC(s, x.a_, x.b_);
		// y.a_ + y.b_
		in_Fp_addNC(t, y.a_, y.b_);

		mul4x4(d0, s, t, gt9, gt8, gt7, gt6, gt5, gt4, gt3, gt2, gt1, gt10); // d0 = s * t
		mul4x4(d1, x.a_, y.a_, gt9, gt8, gt7, gt6, gt5, gt4, gt3, gt2, gt1, gt10); // d1 = x.a_ * y.a_
		mul4x4(d2, x.b_, y.b_, gt9, gt8, gt7, gt6, gt5, gt4, gt3, gt2, gt1, gt10); // d2 = x.b_ * y.b_

		// d0 -= d1
		sub_Fp2Dbl_subNC(d0, d1, gt3, gt2, gt1, gt10);
		// d0 -= d2
		sub_Fp2Dbl_subNC(d0, d2, gt3, gt2, gt1, gt10);

		sub_FpDbl_sub(d1, d1, d2);

		lea(gp2, ptr [d1]);
//		mont_mod();
		call(p_FpDbl_mod);

		lea(gp2, ptr [d0]);
		add(gp1, sizeof(Fp));
//		mont_mod();
		call(p_FpDbl_mod);
		add(rsp, SS);
//end_clock();
		ret();
	}

	// mul(Fp2T& z, const Fp2T& x, const Fp2T& y)
	void make_Fp2_mul()
	{
		MakeStackFrame<> sf(this, 10);
		call(p_Fp2_mul);
	}

	// uint64_t preInv(FpT& r, const FpT& x)
	void make_Fp_preInv()
	{
		MakeStackFrame<> sf(this, 10, 4);
		const Reg64& r = gp1;
		const Reg64& v0 = gp2;
		const Reg64& v1 = gp3;
		const Reg64& v2 = gt1;
		const Reg64& v3 = gt2;
		const Reg64& u0 = gt3;
		const Reg64& u1 = gt4;
		const Reg64& u2 = gt5;
		const Reg64& u3 = gt6;
		const Reg64& s0 = gt7;
		const Reg64& s1 = gt8;
		const Reg64& s2 = gt9;
		const Reg64& s3 = gt10;
		const Reg64& t = rdx;

		inLocalLabel();
		const Reg64& a = rax;
		const Xmm& k = xm4;
		const Xmm& one = xm5;
		const Xmm& xt0 = xm0;
		const Xmm& xt1 = xm1;
		const Xmm& xt2 = xm2;
		const Xmm& xt3 = xm3;
		mov(t, (uint64_t)&s_pTbl[1]);
		load_rm(u3, u2, u1, u0, t); // u = p
		mov(v3, ptr [v0 + 8 * 3]);
		mov(v2, ptr [v0 + 8 * 2]);
		mov(v1, ptr [v0 + 8 * 1]);
		mov(v0, ptr [v0 + 8 * 0]); // v = x
		xor_(s3, s3);
		lea(s0, ptr [s3 + 1]);
		mov(s1, s3);
		mov(s2, s3); // s[3:2:1:0] = 1

		// r = [r:a:rsp[1]:rsp[0]]
		mov(ptr [rsp + 8 * 0], s3);
		mov(ptr [rsp + 8 * 1], s3);
		mov(ptr [rsp + 8 * 2], r); // save r
		xor_(a, a);
		xor_(r, r);

		pxor(k, k); // k
		pxor(one, one);
		movq(one, s0);

		align(16);
	L(".lp");
		mov(t, v0);
		or_(t, v1);
		or_(t, v2);
		or_(t, v3);
		jz(".exit", T_NEAR);
		test(u0, 1);
		jz(".u_even", T_NEAR);
		test(v0, 1);
		jz(".v_even");
		movq(xt0, v0);
		movq(xt1, v1);
		movq(xt2, v2);
		movq(xt3, v3);
		sub_rr(v3, v2, v1, v0, u3, u2, u1, u0);
		jc(".next3");
		add(s0, ptr [rsp + 8 * 0]);
		adc(s1, ptr [rsp + 8 * 1]);
		adc(s2, a);
		adc(s3, r);
	L(".v_even");
		shr1(v3, v2, v1, v0);
		mov(t, ptr [rsp + 8 * 0]);
		add(ptr [rsp + 8 * 0], t);
		mov(t, ptr [rsp + 8 * 1]);
		adc(ptr [rsp + 8 * 1], t);
		adc(a, a);
		adc(r, r);
		paddd(k, one);
		jmp(".lp");
		align(16);
	L(".next3");
		movq(v0, xt0);
		movq(v1, xt1);
		movq(v2, xt2);
		movq(v3, xt3);
		sub_rr(u3, u2, u1, u0, v3, v2, v1, v0);
		add(ptr [rsp + 8 * 0], s0);
		adc(ptr [rsp + 8 * 1], s1);
		adc(a, s2);
		adc(r, s3);
	L(".u_even");
		shr1(u3, u2, u1, u0);
		shl1(s3, s2, s1, s0);
		paddd(k, one);
		jmp(".lp", T_NEAR);
		align(16);
	L(".exit");
		// r = 2p - r
		// if (r >= p) r -= p ; this is unnecessary because next function is mul
		mov(t, (uint64_t)&s_pTbl[2]);
		load_rm(s3, s2, s1, s0, t);
		sub(s0, ptr [rsp + 8 * 0]);
		sbb(s1, ptr [rsp + 8 * 1]);
		sbb(s2, a);
		sbb(s3, r);
		mov(r, ptr [rsp + 8 * 2]);
		store_mr(r, s3, s2, s1, s0);
		movq(rax, k);

		outLocalLabel();
	}

	void begin_clock()
	{
		mov(gt1, (size_t)&sclk);
		rdtsc();
		sub(ptr [gt1], eax);
		sbb(ptr [gt1 + 4], edx);
	}
	void end_clock()
	{
		mov(gt1, (size_t)&sclk);
		rdtsc();
		add(ptr [gt1], eax);
		adc(ptr [gt1 + 4], edx);
		inc(dword [gt1 + 8]);
	}
	/*
		mulOpt(Fp2Dbl& z, const Fp2T& x, const Fp2T& y);
		input : (pz, px, py) = (gp1, gp2, gp3)
		stack : 8 * 16
		202clk x 2058
	*/
	void sub_Fp2Dbl_mulOpt(int mode)
	{
		Ext2<FpDbl> z(gp1);
		Ext2<Fp> x(gp2);
		Ext2<Fp> y(gp3);
		// Fp s, t;
		// FpDbl d0;
		Ext1<Fp> s(rsp);
		Ext1<Fp> t(rsp, s.next);
		Ext1<FpDbl> d0(rsp, t.next);
		const int SS = d0.next;
		sub(rsp, SS);

		// x.a_ + x.b_
		in_Fp_addNC(s, x.a_, x.b_);
		// y.a_ + y.b_
		in_Fp_addNC(t, y.a_, y.b_);

		mul4x4(d0, x.b_, y.b_, gt9, gt8, gt7, gt6, gt5, gt4, gt3, gt2, gt1, gt10); // d2 = x.b_ * y.b_
		mul4x4(z.a_, x.a_, y.a_, gt9, gt8, gt7, gt6, gt5, gt4, gt3, gt2, gt1, gt10); // d1 = x.a_ * y.a_
		mul4x4(z.b_, s, t, gt9, gt8, gt7, gt6, gt5, gt4, gt3, gt2, gt1, gt10); // d0 = s * t

		// d0 -= d1(subNC)
		load_sub_rm(gt3, gt2, gt1, gt10, z.b_, z.a_, false);

		load_sub_rm(gt7, gt6, gt5, gt4, (RegExp)z.b_ + sizeof(Fp), (RegExp)z.a_ + sizeof(Fp), true);
		// d0 -= d2(subNC)
		sub_rm(gt3, gt2, gt1, gt10, d0);
		sbb_rm(gt7, gt6, gt5, gt4, (RegExp)d0 + sizeof(Fp));

		// set return value z.b_
		store_mr(z.b_, gt3, gt2, gt1, gt10);
		store_mr((RegExp)z.b_ + sizeof(Fp), gt7, gt6, gt5, gt4);

		if (mode == 1) {
			// call:606
			in_FpDbl_subOpt1(z.a_, z.a_, d0);
		} else {
			// call:1452
//			in_FpDbl_sub(z.a_, z.a_, d0);
			sub_FpDbl_sub(z.a_, z.a_, d0);
		}
		add(rsp, SS);
		ret();
	}
	void set_p_Fp2Dbl_mulOpt(int mode)
	{
		align(16);
		switch (mode) {
		case 1:
			p_Fp2Dbl_mulOpt1 = (void*)const_cast<uint8_t*>(getCurr());
			break;
		case 2:
			p_Fp2Dbl_mulOpt2 = (void*)const_cast<uint8_t*>(getCurr());
			break;
		default:
			printf("err set_p_Fp2Dbl_mulOpt mode=%d\n", mode);
		}
		sub_Fp2Dbl_mulOpt(mode);
	}
	void set_p_Fp2Dbl_mul_xi()
	{
		align(16);
		p_Fp2Dbl_mul_xi = (void*)const_cast<uint8_t*>(getCurr());
		mov(rax, (uint64_t)&s_pTbl[1]);
#ifdef BN_SUPPORT_SNARK
		in_FpDbl_add(gp1, gp2, gp2); // 2
		in_FpDbl_add(gp1, gp1, gp1); // 4
		in_FpDbl_add(gp1, gp1, gp1); // 8
		in_FpDbl_add(gp1, gp1, gp2); // 9
		sub_FpDbl_sub(gp1, gp1, gp2 + sizeof(FpDbl));

		in_FpDbl_add(gp1 + 64, gp2 + sizeof(FpDbl), gp2 + sizeof(FpDbl)); // 2
		in_FpDbl_add(gp1 + 64, gp1 + 64, gp1 + 64); // 4
		in_FpDbl_add(gp1 + 64, gp1 + 64, gp1 + 64); // 8
		in_FpDbl_add(gp1 + 64, gp1 + 64, gp2 + sizeof(FpDbl)); // 9
		in_FpDbl_add(gp1 + 64, gp1 + 64, gp2);
#else
		sub_FpDbl_sub(gp1, gp2, gp2 + sizeof(FpDbl));
		in_FpDbl_add(gp1 + 64, gp2 + sizeof(FpDbl), gp2);
#endif
		ret();
	}

	// Fp2::Dbl::mulOpt1(Dbl &z, const Fp2T &x, const Fp2T &y) h = 2
	void make_Fp2Dbl_mulOpt(int mode)
	{
		MakeStackFrame<> sf(this, 10);
		if (mode == 1) {
			call(p_Fp2Dbl_mulOpt1);
		} else {
			call(p_Fp2Dbl_mulOpt2);
		}
	}

	/*
		Fp6::mul(Fp6Dbl& z, const Fp6T& x, const Fp6T& y);
		input (z, x, y) = (xm3, xm4, xm5)
		ca::194
	*/
	void set_p_Fp6Dbl_mul()
	{
		align(16);
		p_Fp6Dbl_mul = (void*)const_cast<uint8_t*>(getCurr());

		// Fp2 t0, t1;
		// Fp2Dbl T0, T1, T2;

		const Ext6<FpDbl> z(gt8);
		const Ext6<Fp> x(gt9);
		const Ext6<Fp> y(gt10);
		const Ext2<Fp> t0(rsp);
		const Ext2<Fp> t1(rsp, t0.next);
		const Ext2<FpDbl> T0(rsp, t1.next);
		const Ext2<FpDbl> T1(rsp, T0.next);
		const Ext2<FpDbl> T2(rsp, T1.next);
		const int SS = T2.next;

		sub(rsp, SS);
		const Xmm& zsave = xm3;
		const Xmm& xsave = xm4;
		const Xmm& ysave = xm5;
		movq(z.r_, zsave);
		movq(x.r_, xsave);
		movq(y.r_, ysave);

		// Fp2Dbl::mulOpt1(T0, x.a_, y.a_);
		lea(gp1, ptr [T0]);
		lea(gp2, ptr [x.a_]);
		lea(gp3, ptr [y.a_]);
		call(p_Fp2Dbl_mulOpt1);

		// Fp2Dbl::mulOpt1(T1, x.b_, y.b_);
		movq(x.r_, xsave);
		movq(y.r_, ysave);
		lea(gp1, ptr [T1]);
		lea(gp2, ptr [x.b_]);
		lea(gp3, ptr [y.b_]);
		call(p_Fp2Dbl_mulOpt1);

		// Fp2Dbl::mulOpt1(T2, x.c_, y.c_);
		movq(x.r_, xsave);
		movq(y.r_, ysave);
		lea(gp1, ptr [T2]);
		lea(gp2, ptr [x.c_]);
		lea(gp3, ptr [y.c_]);
		call(p_Fp2Dbl_mulOpt1);

		// Fp2::addNC(t0, x.b_, x.c_);
		movq(x.r_, xsave);
		movq(y.r_, ysave);
		in_Fp2_addNC(t0, x.b_, x.c_);
		// Fp2::addNC(t1, y.b_, y.c_);
		in_Fp2_addNC(t1, y.b_, y.c_);

		// Fp2Dbl::mulOpt2(z.c_, t0, t1);
		movq(z.r_, zsave);
		lea(gp1, ptr [z.c_]);
		lea(gp2, ptr [t0]);
		lea(gp3, ptr [t1]);
		call(p_Fp2Dbl_mulOpt2);

		// Fp2Dbl::addNC(z.b_, T1, T2);
		movq(z.r_, zsave);
		movq(x.r_, xsave);
		movq(y.r_, ysave);
		in_FpDbl_addNC(2, z.b_, T1, T2);

		// FpDbl::sub(z.c_.a_, z.c_.a_, z.b_.a_);
		in_FpDbl_sub(z.c_.a_, z.c_.a_, z.b_.a_);

		// FpDbl::subNC(z.c_.b_, z.c_.b_, z.b_.b_);
		in_FpDbl_subNC(z.c_.b_, z.c_.b_, z.b_.b_);

		// Fp2Dbl::mul_xi(z.b_, z.c_);
		in_Fp2Dbl_mul_xi(z.b_, z.c_);

		// Fp2Dbl::add(z.a_, z.b_, T0);
		in_Fp2Dbl_add(z.a_, z.b_, T0);

		// Fp2::addNC(t0, x.a_, x.b_);
		in_Fp2_addNC(t0, x.a_, x.b_);

		// Fp2::addNC(t1, y.a_, y.b_);
		in_Fp2_addNC(t1, y.a_, y.b_);

		// Fp2Dbl::mulOpt2(z.c_, t0, t1);
		lea(gp1, ptr [z.c_]);
		lea(gp2, ptr [t0]);
		lea(gp3, ptr [t1]);
		call(p_Fp2Dbl_mulOpt2);

		movq(z.r_, zsave);
		movq(x.r_, xsave);
		movq(y.r_, ysave);

		// Fp2Dbl::addNC(z.b_, T0, T1);
		in_FpDbl_addNC(2, z.b_, T0, T1);

		// FpDbl::sub(z.c_.a_, z.c_.a_, z.b_.a_);
		in_FpDbl_sub(z.c_.a_, z.c_.a_, z.b_.a_);

		// FpDbl::subNC(z.c_.b_, z.c_.b_, z.b_.b_);
		in_FpDbl_subNC(z.c_.b_, z.c_.b_, z.b_.b_);

		// FpDbl::subOpt1(z.b_.a_, T2.a_, T2.b_);
#ifdef BN_SUPPORT_SNARK
		in_Fp2Dbl_mul_xi(z.b_, T2);
#else
		in_FpDbl_subOpt1(z.b_.a_, T2.a_, T2.b_);

		// FpDbl::add(z.b_.b_, T2.a_, T2.b_);
		in_FpDbl_add(z.b_.b_, T2.a_, T2.b_);

#endif
		// Fp2Dbl::add(z.b_, z.b_, z.c_);
		in_Fp2Dbl_add(z.b_, z.b_, z.c_);

		// Fp2::addNC(t0, x.a_, x.c_);
		in_Fp2_addNC(t0, x.a_, x.c_);

		// Fp2::addNC(t1, y.a_, y.c_);
		in_Fp2_addNC(t1, y.a_, y.c_);

		// Fp2Dbl::mulOpt2(z.c_, t0, t1);
		lea(gp1, ptr [z.c_]);
		lea(gp2, ptr [t0]);
		lea(gp3, ptr [t1]);
		call(p_Fp2Dbl_mulOpt2);

		movq(z.r_, zsave);

		// Fp2Dbl::addNC(T2, T2, T0);
		in_FpDbl_addNC(2, T2, T2, T0);

		// FpDbl::sub(z.c_.a_, z.c_.a_, T2.a_);
		in_FpDbl_sub(z.c_.a_, z.c_.a_, T2.a_);

		// FpDbl::add(z.c_.a_, z.c_.a_, T1.a_);
		in_FpDbl_add(z.c_.a_, z.c_.a_, T1.a_);

#if 0
		load_sub_rm(gt4, gt3, gt2, gt1, z.c_.b_, T2.b_, false);
		load_sub_rm(rdx, rax, gt6, gt5, (RegExp)z.c_.b_ + sizeof(Fp), (RegExp)T2.b_ + sizeof(Fp), true);
		add_rm(gt4, gt3, gt2, gt1, T1.b_);
		adc_rm(rdx, rax, gt6, gt5, (RegExp)T1.b_ + sizeof(Fp));
		store_mr(z.c_.b_, gt4, gt3, gt2, gt1);
		store_mr((RegExp)z.c_.b_ + sizeof(Fp), rdx, rax, gt6, gt5);
#else
		// FpDbl::subNC(z.c_.b_, z.c_.b_, T2.b_);
		in_FpDbl_subNC(z.c_.b_, z.c_.b_, T2.b_);

		// FpDbl::addNC(z.c_.b_, z.c_.b_, T1.b_);
		in_FpDbl_addNC(z.c_.b_, z.c_.b_, T1.b_);
#endif
		add(rsp, SS);
		ret();
	}
	/*
		Fp6::Dbl::mul(Dbl& z, const Fp6T& x, const Fp6T& y);
	*/
	void make_Fp6Dbl_mul()
	{
		MakeStackFrame<> sf(this, 10);
		movq(xm3, gp1);
		movq(xm4, gp2);
		movq(xm5, gp3);
		call(p_Fp6Dbl_mul);
	}
	/*
		(z, x, y) = (gp1, gp2, gp3)
	*/
	void set_p_Fp6_mul()
	{
		align(16);
		p_Fp6_mul = (void*)const_cast<uint8_t*>(getCurr());

		const int SS = sizeof(Fp6Dbl);
		sub(rsp, SS);
		movq(xm2, gp1);
		movq(xm3, rsp);
		movq(xm4, gp2);
		movq(xm5, gp3);
		call(p_Fp6Dbl_mul);

		for (int i = 0; i < 6; i++) {
			movq(gp1, xm2);
			if (i == 0) {
				mov(gp2, rsp);
			} else {
				add(gp1, 32 * i);
				lea(gp2, ptr [rsp + 64 * i]);
			}
			call(p_FpDbl_mod);
		}
		add(rsp, SS);
		ret();
	}
	/*
		Fp6::mul(Fp6& z, const Fp6T& x, const Fp6T& y);
	*/
	void make_Fp6_mul()
	{
		MakeStackFrame<> sf(this, 10);
		call(p_Fp6_mul);
	}
	// for debug
	void debug_save_buf(const RegExp& m, int n)
	{
		static uint64 save[3];

		// don't change rsp
		push(rcx);
		mov(rcx, (size_t)save);
		mov(ptr [rcx], rax);
		mov(ptr [rcx + 8], rdx);
		mov(ptr [rcx + 16], rbx);
		pop(rcx);

		mov(rdx, (size_t)debug_buf);
		lea(rbx, ptr [m]);
		for (int i = 0; i < n; i++) {
			mov(rax, ptr [rbx + i * 8]);
			mov(ptr [rdx + i * 8], rax);
		}
		push(rcx);
		mov(rcx, (size_t)save);
		mov(rax, ptr [rcx]);
		mov(rdx, ptr [rcx + 8]);
		mov(rbx, ptr [rbx + 16]);
		pop(rcx);
	}
	void debug_count_inc()
	{
		push(rax);
		mov(rax, (size_t)&debug_counter);
		add(dword [rax], 1);
		pop(rax);
	}
	/*
		Compress::square_n(Compress& z, int n);
		input : gp1 = pointer to z.z_
	*/
	void make_Compress_square_n()
	{
		// Fp2 t0, t1, t2;
		// Fp2Dbl T0, T1, T2, T3;
		const Ext2<Fp> t0(rsp);
		const Ext2<Fp> t1(rsp, t0.next);
		const Ext2<Fp> t2(rsp, t1.next);
		const Ext2<FpDbl> T0(rsp, t2.next);
		const Ext2<FpDbl> T1(rsp, T0.next);
		const Ext2<FpDbl> T2(rsp, T1.next);
		const Ext2<FpDbl> T3(rsp, T2.next);
		const int nsave = T3.next;
		const int SS = nsave + 8;

		MakeStackFrame<> sf(this, 10, SS / 8);
		const Xmm& zsave = xm3;
		const Reg64& z = gt10;
//		const int g1 = sizeof(Fp2) * 4;
		const int g2 = sizeof(Fp2) * 3;
		const int g3 = sizeof(Fp2) * 2;
		const int g4 = sizeof(Fp2) * 1;
		const int g5 = sizeof(Fp2) * 5;
		mov(z, ptr [gp1]);
		mov(ptr [rsp + nsave], gp2);
		movq(zsave, z);

		inLocalLabel();
	L(".lp");

		// Fp2Dbl::square(T0, z.g4_);
		lea(gp1, ptr [T0]);
		lea(gp2, ptr [z + g4]);
		call(p_Fp2Dbl_square);

		// Fp2Dbl::square(T1, z.g5_);
		lea(gp1, ptr [T1]);
		movq(gp2, zsave);
		add(gp2, g5);
		call(p_Fp2Dbl_square);

		// Fp2Dbl::mul_xi(T2, T1);
		in_Fp2Dbl_mul_xi(T2, T1);

		// T2 += T0;
		in_Fp2Dbl_add(T2, T2, T0);

		// Fp2Dbl::mod(t2, T2);
		lea(gp1, ptr [t2]);
		lea(gp2, ptr [T2]);
		in_Fp2Dbl_mod();

		// Fp2::add(t0, z.g4_, z.g5_);
		movq(z, zsave);
		in_Fp2_add(t0, z + g4, z + g5);

		// Fp2Dbl::square(T2, t0);
		lea(gp1, ptr [T2]);
		lea(gp2, ptr [t0]);
		call(p_Fp2Dbl_square);

//		T0 += T1;
		// Fp2Dbl::addNC(T0, T0, T1); // QQQ : OK?
		movq(z, zsave);
		in_FpDbl_add(2, T0, T0, T1);

		// T2 -= T0;
		in_Fp2Dbl_sub(T2, T2, T0);

		// Fp2Dbl::mod(t0, T2);
		lea(gp1, ptr [t0]);
		lea(gp2, ptr [T2]);
		in_Fp2Dbl_mod();

		// Fp2::add(t1, z.g2_, z.g3_);
		movq(z, zsave);
		in_Fp2_add(t1, z + g2, z + g3);

		// Fp2Dbl::square(T3, t1);
		lea(gp1, ptr [T3]);
		lea(gp2, ptr [t1]);
		call(p_Fp2Dbl_square);

		// Fp2Dbl::square(T2, z.g2_);
		movq(z, zsave);
		lea(gp1, ptr [T2]);
		lea(gp2, ptr [z + g2]);
		call(p_Fp2Dbl_square);

		// Fp2::mul_xi(t1, t0);
		in_Fp2_mul_xi(t1, t0);

#if 1
		lea(gp1, ptr [z + g2]);
		lea(gp2, ptr [t1]);
		call(p_Fp2_2z_add_3x);
#else
		// z.g2_ += t1;
		in_Fp2_add(z + g2, z + g2, t1);

		// z.g2_ += z.g2_;
		in_Fp2_add(z + g2, z + g2, z + g2);

		// z.g2_ += t1;
		in_Fp2_add(z + g2, z + g2, t1);
#endif

		// Fp2::sub(t1, t2, z.g3_);
		in_Fp2_sub(t1, t2, z + g3);

		// t1 += t1;
		in_Fp2_add(t1, t1, t1);

		// Fp2Dbl::square(T1, z.g3_);
		lea(gp1, ptr [T1]);
		lea(gp2, ptr [z + g3]);
		call(p_Fp2Dbl_square);

		// Fp2::add(z.g3_, t1, t2);
		movq(z, zsave);
		in_Fp2_add(z + g3, t1, t2);

		// Fp2Dbl::mul_xi(T0, T1);
		in_Fp2Dbl_mul_xi(T0, T1);


//		T0 += T2;
		// Fp2Dbl::addNC(T0, T0, T2); // QQQ : OK?
		in_FpDbl_add(2, T0, T0, T2);

		// Fp2Dbl::mod(t0, T0);
		lea(gp1, ptr [t0]);
		lea(gp2, ptr [T0]);
		in_Fp2Dbl_mod();

#if 1
		movq(z, zsave);
		for (int i = 0; i < 2; i++) {
			mov(rax, (uint64_t)&s_pTbl[1]);
			load_add_rm(gt4, gt3, gt2, gt1, (RegExp)t0 + sizeof(Fp) * i, rax, false);
			sub_rm(gt4, gt3, gt2, gt1, z + g4 + sizeof(Fp) * i);
			add_rr(gt4, gt3, gt2, gt1, gt4, gt3, gt2, gt1);
			add_rm(gt4, gt3, gt2, gt1, (RegExp)t0 + sizeof(Fp) * i);
			fast_modp(gt4, gt3, gt2, gt1, gp1, gp2, gp3, gt5);
			store_mr(z + g4 + sizeof(Fp) * i, gt4, gt3, gt2, gt1);
		}
#else
		// Fp2::sub(z.g4_, t0, z.g4_);
		movq(z, zsave);
		in_Fp2_sub(z + g4, t0, z + g4);

		// z.g4_ += z.g4_;
		in_Fp2_add(z + g4, z + g4, z + g4);

		// z.g4_ += t0;
		in_Fp2_add(z + g4, z + g4, t0);
#endif

		// Fp2Dbl::addNC(T2, T2, T1);
		in_FpDbl_addNC(2, T2, T2, T1);

		// T3 -= T2;
		in_Fp2Dbl_sub(T3, T3, T2);

		// Fp2Dbl::mod(t0, T3);
		lea(gp1, ptr [t0]);
		lea(gp2, ptr [T3]);
		in_Fp2Dbl_mod();

		// z.g5_ += t0;
		movq(z, zsave);
#if 1
		lea(gp1, ptr [z + g5]);
		lea(gp2, ptr [t0]);
		call(p_Fp2_2z_add_3x);
#else
		in_Fp2_add(z + g5, z + g5, t0);

		// z.g5_ += z.g5_;
		in_Fp2_add(z + g5, z + g5, z + g5);
		// z.g5_ += t0; // # 18
		in_Fp2_add(z + g5, z + g5, t0);
#endif

		sub(qword [rsp + nsave], 1);
		jnz(".lp", T_NEAR);
		outLocalLabel();
	}
	/*
		input (z, x) = (gp1, gp2)
		mz = 2mz + 3mx
		destroy : gp3, gt1, .., gt7, rax, rdx
	*/
	void in_Fp_2z_add_3x(const RegExp& mz, const RegExp& mx)
	{
		load_add_rm(gt4, gt3, gt2, gt1, mz, mx, false);
		add_rr(gt4, gt3, gt2, gt1, gt4, gt3, gt2, gt1);
		add_rm(gt4, gt3, gt2, gt1, mx);
		fast_modp(gt4, gt3, gt2, gt1, gp3, gt5, gt6, gt7);
		store_mr(mz, gt4, gt3, gt2, gt1);
	}
	/*
		input (z, x) = (gp1, gp2)
		mz = 2mz + 3mx
		destroy : gp3, gt1, .., gt7, rax, rdx
	*/
	void set_p_Fp2_2z_add_3x()
	{
		align(16);
		p_Fp2_2z_add_3x = (void*)const_cast<uint8_t*>(getCurr());
		in_Fp_2z_add_3x(gp1, gp2);
		in_Fp_2z_add_3x(gp1 + sizeof(Fp), gp2 + sizeof(Fp));
		ret();
	}
	void sub_Fp2_mul_gamma_add(const RegExp& mz, const RegExp& mx, const RegExp& my)
	{
		const int a = 0;
		const int b = sizeof(Fp2);
		const int c = sizeof(Fp2) * 2;
		in_Fp2_mul_xi(mz + a, mx + c);
		in_Fp2_add(mz + a, mz + a, my + a);
		in_Fp2_add(mz + b, mx + a, my + b);
		in_Fp2_add(mz + c, mx + b, my + c);
	}
	// Fp12::square(Fp12& z);
	void make_Fp12_square()
	{
		// Fp6 t0, t1;
		const Ext6<Fp> t0(rsp);
		const Ext6<Fp> t1(rsp, t0.next);
		const int zsave = t1.next;
		const int SS = zsave + 8;
		const Ext12<Fp> z(gt10);
		MakeStackFrame<> sf(this, 10, SS / 8);

		mov(z.r_, gp1);
		mov(ptr [rsp + zsave], gp1);
		lea(gp1, ptr [t0]);
		lea(gp2, ptr [z.a_]);
		lea(gp3, ptr [z.b_]);
		call(p_Fp6_add);

		sub_Fp2_mul_gamma_add(t1, z.b_, z.a_);

		lea(gp1, ptr [z.b_]);
		mov(gp2, gp1);
		mov(gp3, z.r_);
		call(p_Fp6_mul);
		mov(gp1, ptr [rsp + zsave]);
		lea(gp2, ptr [t0]);
		lea(gp3, ptr [t1]);
		call(p_Fp6_mul);

		mov(z.r_, ptr [rsp + zsave]);
		sub_Fp2_mul_gamma_add(t1, z.b_, z.b_);

		mov(z.r_, ptr [rsp + zsave]);
		mov(gp1, z.r_);
		mov(gp2, z.r_);
		lea(gp3, ptr [t1]);
		call(p_Fp6_sub);

		lea(gp1, ptr [z.b_]);
		mov(gp2, gp1);
		mov(gp3, gp1);
		call(p_Fp6_add);
	}
	// Fp12::mul(Fp12& z, const Fp12& x, const Fp12& y);
	void make_Fp12_mul()
	{
		const Ext12<Fp> z(gt8);
		const Ext12<Fp> x(gt9);
		const Ext12<Fp> y(gt10);

		const Ext6<Fp> t0(rsp);
		const Ext6<Fp> t1(rsp, t0.next);
		const Ext6<FpDbl> T0(rsp, t1.next);
		const Ext6<FpDbl> T1(rsp, T0.next);
		const Ext6<FpDbl> T2(rsp, T1.next);
		const Ext12<FpDbl> zd(rsp, T2.next);
		const Ext1<uint64> zsave(rsp, zd.next);
		const Ext1<uint64> xsave(rsp, zsave.next);
		const Ext1<uint64> ysave(rsp, xsave.next);
		const int SS = ysave.next;
		MakeStackFrame<> sf(this, 10, SS / 8);
		mov(ptr [zsave], gp1);
		mov(ptr [xsave], gp2);
		mov(ptr [ysave], gp3);

		// Fp6Dbl::mul(T0, x.a_, y.a_); // QQQ
		lea(gp1, ptr [T0]);
		movq(xm3, gp1);
		movq(xm4, gp2);
		movq(xm5, gp3);
		call(p_Fp6Dbl_mul);

//		Fp6Dbl::mul(T1, x.b_, y.b_);
		mov(x.r_, ptr [xsave]);
		mov(y.r_, ptr [ysave]);

		lea(gp1, ptr [T1]);
		lea(gp2, ptr [x.b_]);
		lea(gp3, ptr [y.b_]);
		movq(xm3, gp1);
		movq(xm4, gp2);
		movq(xm5, gp3);
		call(p_Fp6Dbl_mul);

//		Fp6::add(t0, x.a_, x.b_);
		mov(x.r_, ptr [xsave]);
		lea(gp1, ptr [t0]);
		lea(gp2, ptr [x.a_]);
		lea(gp3, ptr [x.b_]);
		call(p_Fp6_add);

		// Fp6::add(t1, y.a_, y.b_);
		mov(y.r_, ptr [ysave]);
		lea(gp1, ptr [t1]);
		lea(gp2, ptr [y.a_]);
		lea(gp3, ptr [y.b_]);
		call(p_Fp6_add);

		// Fp6Dbl::mul(zd.a_, t0, t1);
		lea(gp1, ptr [zd.a_]);
		lea(gp2, ptr [t0]);
		lea(gp3, ptr [t1]);
		movq(xm3, gp1);
		movq(xm4, gp2);
		movq(xm5, gp3);
		call(p_Fp6Dbl_mul);

		// Fp6Dbl::add(T2, T0, T1);
		in_FpDbl_add(6, T2, T0, T1);

		// Fp6Dbl::sub(zd.b_, zd.a_, T2);
		in_FpDbl_sub(6, zd.b_, zd.a_, T2);

		// mul_gamma_add<Fp6Dbl, Fp2Dbl>(zd.a_, T1, T0);
		in_Fp2Dbl_mul_xi(zd.a_.a_, T1.c_);
		in_FpDbl_add(2, zd.a_.a_, zd.a_.a_, T0.a_);
		in_FpDbl_add(2, zd.a_.b_, T1.a_, T0.b_);
		in_FpDbl_add(2, zd.a_.c_, T1.b_, T0.c_);

		// Dbl::mod(z, zd);
		for (int i = 0; i < 12; i++) {
			mov(gp1, ptr [zsave]);
			if (i > 0) add(gp1, sizeof(Fp) * i);
			lea(gp2, ptr [(RegExp)zd + sizeof(FpDbl) * i]);
			call(p_FpDbl_mod);
		}
	}
	// static void mul_Fp2_024C(Fp12T &z, const Fp6& x)
	void make_Fp12Dbl_mul_Fp2_024()
	{
		// Fp2 t0, t1, t2, t4;
		// Fp2Dbl T2, T3;
		// Fp2Dbl X0T0, X2T2, X4T4;
		// Fp2Dbl ACC;
		const Ext2<Fp> t0(rsp);
		const Ext2<Fp> t1(rsp, t0.next);
		const Ext2<Fp> t2(rsp, t1.next);
		const Ext2<Fp> t4(rsp, t2.next);
		const Ext2<FpDbl> T2(rsp, t4.next);
		const Ext2<FpDbl> T3(rsp, T2.next);
		const Ext2<FpDbl> X0T0(rsp, T3.next);
		const Ext2<FpDbl> X2T2(rsp, X0T0.next);
		const Ext2<FpDbl> X4T4(rsp, X2T2.next);
		const Ext2<FpDbl> ACC(rsp, X4T4.next);
		const int SS = ACC.next;
		const Ext12<Fp> z(gt9);
		const Ext6<Fp> x(gt10);

		MakeStackFrame<> sf(this, 10, SS / 8);
		const Xmm& zsave = xm3;
		const Xmm& xsave = xm4;
		mov(z.r_, gp1);
		mov(x.r_, gp2);
		movq(zsave, z.r_);
		movq(xsave, x.r_);

		// Fp2Dbl::mulOpt2(X0T0, z.a_.a_, x.a_);
		lea(gp1, ptr [X0T0]);
		mov(gp2, z.r_);
		mov(gp3, x.r_);
		call(p_Fp2Dbl_mulOpt2);

		// Fp2Dbl::mulOpt2(X2T2, z.a_.c_, x.c_);
		movq(z.r_, zsave);
		movq(x.r_, xsave);
		lea(gp1, ptr [X2T2]);
		lea(gp2, ptr [z.a_.c_]);
		lea(gp3, ptr [x.c_]);
		call(p_Fp2Dbl_mulOpt2);

		// Fp2Dbl::mulOpt2(X4T4, z.b_.b_, x.b_);
		movq(z.r_, zsave);
		movq(x.r_, xsave);
		lea(gp1, ptr [X4T4]);
		lea(gp2, ptr [z.b_.b_]);
		lea(gp3, ptr [x.b_]);
		call(p_Fp2Dbl_mulOpt2);

		// Fp2::add(t2, z.a_.a_, z.b_.b_);
		movq(z.r_, zsave);
		in_Fp2_add(t2, z.a_.a_, z.b_.b_);

		// Fp2::add(t1, z.a_.a_, z.a_.c_);
		in_Fp2_add(t1, z.a_.a_, z.a_.c_);

		// Fp2::add(t4, z.a_.b_, z.b_.a_);
		in_Fp2_add(t4, z.a_.b_, z.b_.a_);

		// t4 += z.b_.c_;
		in_Fp2_add(t4, t4, z.b_.c_);

		// Fp2Dbl::mulOpt2(ACC, z.a_.b_, x.c_);
		movq(x.r_, xsave);
		lea(gp1, ptr [ACC]);
		lea(gp2, ptr [z.a_.b_]);
		lea(gp3, ptr [x.c_]);
		call(p_Fp2Dbl_mulOpt2);

		// Fp2Dbl::add(T2, ACC, X4T4);
		in_Fp2Dbl_add(T2, ACC, X4T4);

		//Fp2Dbl::mul_xi(T3, T2);
		in_Fp2Dbl_mul_xi(T3, T2);

		// T3 += X0T0;
		in_Fp2Dbl_add(T3, T3, X0T0);

		// Fp2Dbl::mod(z.a_.a_, T3);
		movq(z.r_, zsave);
		lea(gp1, ptr [z.a_.a_]);
		lea(gp2, ptr [T3]);
		in_Fp2Dbl_mod();

		// Fp2Dbl::mulOpt2(T2, z.b_.c_, x.b_);
		movq(z.r_, zsave);
		movq(x.r_, xsave);
		lea(gp1, ptr [T2]);
		lea(gp2, ptr [z.b_.c_]);
		lea(gp3, ptr [x.b_]);
		call(p_Fp2Dbl_mulOpt2);

		// ACC += T2;
		in_Fp2Dbl_add(ACC, ACC, T2);

		// T2 += X2T2;
		in_Fp2Dbl_add(T2, T2, X2T2);

		// Fp2Dbl::mul_xi(T3, T2);
		in_Fp2Dbl_mul_xi(T3, T2);

		// Fp2Dbl::mulOpt2(T2, z.a_.b_, x.a_);
		movq(z.r_, zsave);
		movq(x.r_, xsave);
		lea(gp1, ptr [T2]);
		lea(gp2, ptr [z.a_.b_]);
		lea(gp3, ptr [x.a_]);
		call(p_Fp2Dbl_mulOpt2);

		// ACC += T2;
		in_Fp2Dbl_add(ACC, ACC, T2);

		// T3 += T2;
		in_Fp2Dbl_add(T3, T3, T2);

		// Fp2Dbl::mod(z.a_.b_, T3);
		movq(z.r_, zsave);
		lea(gp1, ptr [z.a_.b_]);
		lea(gp2, ptr [T3]);
		in_Fp2Dbl_mod();

		// Fp2::add(t0, x.a_, x.c_);
		movq(x.r_, xsave);
		in_Fp2_add(t0, x.a_, x.c_);

		// Fp2Dbl::mulOpt2(T2, t1, t0);
		lea(gp1, ptr [T2]);
		lea(gp2, ptr [t1]);
		lea(gp3, ptr [t0]);
		call(p_Fp2Dbl_mulOpt2);

		// T2 -= X0T0;
		in_Fp2Dbl_sub(T2, T2, X0T0);

		// T2 -= X2T2;
		in_Fp2Dbl_sub(T2, T2, X2T2);

		// Fp2Dbl::mulOpt2(T3, z.b_.a_, x.b_);
		movq(z.r_, zsave);
		movq(x.r_, xsave);
		lea(gp1, ptr [T3]);
		lea(gp2, ptr [z.b_.a_]);
		lea(gp3, ptr [x.b_]);
		call(p_Fp2Dbl_mulOpt2);

		// ACC += T3;
		in_Fp2Dbl_add(ACC, ACC, T3);

		// T2 += T3;
		in_Fp2Dbl_add(T2, T2, T3);

		// Fp2::add(t0, z.a_.c_, z.b_.b_);
		movq(z.r_, zsave);
		in_Fp2_add(t0, z.a_.c_, z.b_.b_);

		// Fp2Dbl::mod(z.a_.c_, T2);
		lea(gp1, ptr [z.a_.c_]);
		lea(gp2, ptr [T2]);
		in_Fp2Dbl_mod();

		movq(x.r_, xsave);
		// Fp2::add(t1, x.c_, x.b_);
		in_Fp2_add(t1, x.c_, x.b_);

		// Fp2Dbl::mulOpt2(T2, t0, t1);
		lea(gp1, ptr [T2]);
		lea(gp2, ptr [t0]);
		lea(gp3, ptr [t1]);
		call(p_Fp2Dbl_mulOpt2);


		// T2 -= X2T2;
		in_Fp2Dbl_sub(T2, T2, X2T2);

		// T2 -= X4T4;
		in_Fp2Dbl_sub(T2, T2, X4T4);

		// Fp2Dbl::mul_xi(T3, T2);
		in_Fp2Dbl_mul_xi(T3, T2);

		// Fp2Dbl::mulOpt2(T2, z.b_.a_, x.a_);
		movq(z.r_, zsave);
		movq(x.r_, xsave);
		lea(gp1, ptr [T2]);
		lea(gp2, ptr [z.b_.a_]);
		mov(gp3, x.r_);
		call(p_Fp2Dbl_mulOpt2);

		// ACC += T2;
		in_Fp2Dbl_add(ACC, ACC, T2);

		// T3 += T2;
		in_Fp2Dbl_add(T3, T3, T2);
//		in_FpDbl_addNC(2, T3, T3, T2); // RRR?

		// Fp2Dbl::mod(z.b_.a_, T3);
		movq(z.r_, zsave);
		lea(gp1, ptr [z.b_.a_]);
		lea(gp2, ptr [T3]);
		in_Fp2Dbl_mod();

		// Fp2Dbl::mulOpt2(T2, z.b_.c_, x.c_);
		movq(z.r_, zsave);
		movq(x.r_, xsave);
		lea(gp1, ptr [T2]);
		lea(gp2, ptr [z.b_.c_]);
		lea(gp3, ptr [x.c_]);
		call(p_Fp2Dbl_mulOpt2);

		// ACC += T2;
		in_Fp2Dbl_add(ACC, ACC, T2);

		// Fp2Dbl::mul_xi(T3, T2);
		in_Fp2Dbl_mul_xi(T3, T2);

		// Fp2::add(t0, x.a_, x.b_);
		movq(x.r_, xsave);
		in_Fp2_add(t0, x.a_, x.b_);

		// Fp2Dbl::mulOpt2(T2, t2, t0);
		lea(gp1, ptr [T2]);
		lea(gp2, ptr [t2]);
		lea(gp3, ptr [t0]);
		call(p_Fp2Dbl_mulOpt2);

		// T2 -= X0T0;
		in_Fp2Dbl_sub(T2, T2, X0T0);

		// T2 -= X4T4;
		in_Fp2Dbl_sub(T2, T2, X4T4);

		// T3 += T2;
		in_Fp2Dbl_add(T3, T3, T2);

		// Fp2Dbl::mod(z.b_.b_, T3);
		movq(z.r_, zsave);
		lea(gp1, ptr [z.b_.b_]);
		lea(gp2, ptr [T3]);
		in_Fp2Dbl_mod();

		// Fp2::add(t0, x.a_, x.c_);
		movq(x.r_, xsave);
		in_Fp2_add(t0, x.a_, x.c_);

		// t0 += x.b_;
		in_Fp2_add(t0, t0, x.b_);

		// Fp2Dbl::mulOpt2(T2, t4, t0);
		lea(gp1, ptr [T2]);
		lea(gp2, ptr [t4]);
		lea(gp3, ptr [t0]);
		call(p_Fp2Dbl_mulOpt2);

		// T2 -= ACC;
		movq(z.r_, zsave);
		in_Fp2Dbl_sub(T2, T2, ACC);

		// Fp2Dbl::mod(z.b_.c_, T2);
		lea(gp1, ptr [z.b_.c_]);
		lea(gp2, ptr [T2]);
		in_Fp2Dbl_mod();
	}

	/*
		input (pz, px) = (gp1, gp2)
		use gt1, .., gt9
	*/
	void set_p_Fp2Dbl_square()
	{
		align(16);
		p_Fp2Dbl_square = (void*)const_cast<uint8_t*>(getCurr());

		const Ext2<FpDbl> z(gp1);
		const Ext2<Fp> x(gp2);
		// Fp t0, t1
		const Ext1<Fp> t0(rsp);
		const Ext1<Fp> t1(rsp, t0.next);
		const int SS = t1.next;

		const Reg64& gt0 = gp3;
		const Reg64& a = rax;

		sub(rsp, SS);

		load_rm(gt3, gt2, gt1, gt0, x.b_);
		add_rr(gt3, gt2, gt1, gt0, gt3, gt2, gt1, gt0);
		store_mr(t0, gt3, gt2, gt1, gt0);

		mul4x4(z.b_, t0, x.a_, gt9, gt8, gt7, gt6, gt5, gt4, gt3, gt2, gt1, gt0);
		// d0 = t[3..0] * a_

		mov(a, (uint64_t)&s_pTbl[1]);

		load_add_rm(gt3, gt2, gt1, gt0, x.a_, a, false); // t = a + p
		sub_rm(gt3, gt2, gt1, gt0, x.b_); // a + p - b
		store_mr(t1, gt3, gt2, gt1, gt0); // t = a + p - b

		// Fp::addNC(t0, x.a_, x.b_);
		in_Fp_addNC(t0, x.a_, x.b_);
		// FpDbl::mul(z.a_, t0, t1);
		mul4x4(z, t0, t1, gt9, gt8, gt7, gt6, gt5, gt4, gt3, gt2, gt1, gt0);
		add(rsp, SS);
		ret();
	}
	/*
		square(Dbl& z, const Fp2& x)
		z = x * x
	*/
	void make_Fp2Dbl_square()
	{
		MakeStackFrame<> sf(this, 9);
		call(p_Fp2Dbl_square);
	}
	// void pointDblLineEval(Fp6T<Fp2>& l, Fp2 *R, const typename Fp2::Fp *P);
	void make_pointDblLineEval(bool withoutP)
	{
		// Fp2 t0, t1, t2, t3, t4, t5;
		// Fp2Dbl T0, T1, T2;
		const Ext2<Fp> t0(rsp);
		const Ext2<Fp> t1(rsp, t0.next);
		const Ext2<Fp> t2(rsp, t1.next);
		const Ext2<Fp> t3(rsp, t2.next);
		const Ext2<Fp> t4(rsp, t3.next);
		const Ext2<Fp> t5(rsp, t4.next);
		const Ext2<FpDbl> T0(rsp, t5.next);
		const Ext2<FpDbl> T1(rsp, T0.next);
		const Ext2<FpDbl> T2(rsp, T1.next);
		const int SS = T2.next;
		const Ext6<Fp> l(gt8);
		const Reg64& R = gt9;
		const Reg64& P = gt10;

		MakeStackFrame<> sf(this, 10, SS / 8);
		const Xmm& lsave = xm3;
		const Xmm& Rsave = xm4;
		const Xmm& Psave = xm5;
		mov(l.r_, gp1);
		mov(R, gp2);
		movq(lsave, gp1);
		movq(Rsave, gp2);
		movq(Psave, gp3);

		// Fp2::square(t0, R[2]);
		lea(gp1, ptr [t0]);
		lea(gp2, ptr [R + sizeof(Fp2) * 2]);
		call(p_Fp2_square);

		// Fp2::mul(t4, R[0], R[1]);
		movq(R, Rsave);
		lea(gp1, ptr [t4]);
		lea(gp2, ptr [R + sizeof(Fp2) * 0]);
		lea(gp3, ptr [R + sizeof(Fp2) * 1]);
		call(p_Fp2_mul);

		// Fp2::square(t1, R[1]);
		movq(R, Rsave);
		lea(gp1, ptr [t1]);
		lea(gp2, ptr [R + sizeof(Fp2) * 1]);
		call(p_Fp2_square);

		// Fp2::add(t3, t0, t0);
		in_Fp2_add(t3, t0, t0);

		// Fp2::divBy2(t4, t4);
		lea(gp1, ptr [t4]);
		mov(gp2, gp1);
		call(p_Fp2_divBy2);

		// Fp2::add(t5, t0, t1);
		in_Fp2_add(t5, t0, t1);

		// t0 += t3;
		in_Fp2_add(t0, t0, t3);

#ifdef BN_SUPPORT_SNARK
		// (a + bu) * binv_xi
		if (ParamT<Fp2>::b == 82) {
			// (a + bu) * (9 - u) = (9a + b) + (9b - a)u
			in_Fp_mul_xi_addsub(t2, t0, t0 + 32, true);
			in_Fp_mul_xi_addsub(t2 + 32, t0 + 32, t0, false);
		} else {
			lea(gp1, ptr [t2]);
			lea(gp2, ptr [t0]);
			mov(gp3, (size_t)&ParamT<Fp2>::b_invxi);
			call(p_Fp2_mul);
		}
#else
		// Fp::add(t2.a_, t0.a_, t0.b_);
		in_Fp_add(t2.a_, t0.a_, t0.b_);

		// Fp::sub(t2.b_, t0.b_, t0.a_);
		in_Fp_sub(t2.b_, t0.b_, t0.a_);
#endif

		// Fp2::square(t0, R[0]);
		lea(gp1, ptr [t0]);
		movq(gp2, Rsave);
		call(p_Fp2_square);

		// Fp2::add(t3, t2, t2);
		in_Fp2_add(t3, t2, t2);

		// t3 += t2;
		in_Fp2_add(t3, t3, t2);

		// Fp2::addNC(l.c_, t0, t0);
		movq(l.r_, lsave);
		in_Fp2_addNC(l.c_, t0, t0);

		// Fp2::sub(R[0], t1, t3);
		movq(R, Rsave);
		in_Fp2_sub(R, t1, t3);

		// Fp2::addNC(l.c_, l.c_, t0);
		in_Fp2_addNC(l.c_, l.c_, t0);

		// t3 += t1;
		in_Fp2_add(t3, t3, t1);

		// R[0] *= t4;
		mov(gp1, R);
		mov(gp2, gp1);
		lea(gp3, ptr [t4]);
		call(p_Fp2_mul);

		// Fp2::divBy2(t3, t3);
		lea(gp1, ptr [t3]);
		mov(gp2, gp1);
		call(p_Fp2_divBy2);

		// Fp2Dbl::square(T0, t3);
		lea(gp1, ptr [T0]);
		lea(gp2, ptr [t3]);
		call(p_Fp2Dbl_square);

		// Fp2Dbl::square(T1, t2);
		lea(gp1, ptr [T1]);
		lea(gp2, ptr [t2]);
		call(p_Fp2Dbl_square);

		// Fp2Dbl::addNC(T2, T1, T1);
		in_FpDbl_addNC(2, T2, T1, T1);

		// Fp2::add(t3, R[1], R[2]);
		movq(R, Rsave);
		in_Fp2_add(t3, R + sizeof(Fp2) * 1, R + sizeof(Fp2) * 2);

		// Fp2Dbl::addNC(T2, T2, T1);
#ifdef BN_SUPPORT_SNARK
		in_FpDbl_add(2, T2, T2, T1);
#else
		in_FpDbl_addNC(2, T2, T2, T1);
#endif

		// Fp2::square(t3, t3);
		lea(gp1, ptr [t3]);
		mov(gp2, gp1);
		call(p_Fp2_square);

		// t3 -= t5;
		in_Fp2_sub(t3, t3, t5);

		// T0 -= T2;
		in_FpDbl_sub(2, T0, T0, T2);

		// Fp2Dbl::mod(R[1], T0);
		movq(R, Rsave);
		lea(gp1, ptr [R + sizeof(Fp2) * 1]);
		lea(gp2, ptr [T0]);
		in_Fp2Dbl_mod();

		// Fp2::mul(R[2], t1, t3);
		movq(R, Rsave);
		lea(gp1, ptr [R + sizeof(Fp2) * 2]);
		lea(gp2, ptr [t1]);
		lea(gp3, ptr [t3]);
		call(p_Fp2_mul);

		// t2 -= t1;
		in_Fp2_sub(t2, t2, t1);

		// Fp2::mul_xi(l.a_, t2);
		movq(l.r_, lsave);
		in_Fp2_mul_xi(l, t2);

		// Fp2::neg(t3, t3);
		movq(l.r_, lsave);
		in_Fp2_neg(l.b_, t3);
		if (withoutP) return;

		// Fp2::mul_Fp_0(l.c_, l.c_, P[0]);
		lea(gp1, ptr [l.c_]);
		mov(gp2, gp1);
		movq(gp3, Psave);
		call(p_Fp_mul);
		movq(l.r_, lsave);
		lea(gp1, ptr [l.c_.b_]);
		mov(gp2, gp1);
		movq(gp3, Psave);
		call(p_Fp_mul);

		// # 17
		// Fp2::mul_Fp_0(l.b_, l.b_, P[1]);
		movq(l.r_, lsave);
		movq(P, Psave);
		lea(gp1, ptr [l.b_]);
		mov(gp2, gp1);
		lea(gp3, ptr [P + sizeof(Fp) * 1]);
		call(p_Fp_mul);
		movq(l.r_, lsave);
		movq(P, Psave);
		lea(gp1, ptr [l.b_.b_]);
		mov(gp2, gp1);
		lea(gp3, ptr [P + sizeof(Fp) * 1]);
		call(p_Fp_mul);

	}

	PairingCode(size_t size, void *userPtr)
		: Xbyak::CodeGenerator(size, userPtr)
		, pp_(0)
		, gtn_(0)
		, a(rax)
		, d(rdx)
#ifdef _WIN32
		, gp1(rcx)
		, gp2(r9) // rdx => r9
		, gp3(r8)
		, gt1(r10)
		, gt2(r11)
		, gt3(rdi) // must be saved if used
		, gt4(rsi)
#else
		, gp1(rdi)
		, gp2(rsi)
		, gp3(r9) // rdx => r9
		, gt1(r8)
		, gt2(rcx)
		, gt3(r10)
		, gt4(r11)
#endif
		, gt5(r12) // must be saved if used
		, gt6(r13)
		, gt7(r14)
		, gt8(r15)
		, gt9(rbp)
		, gt10(rbx)
	{
	}
	/*
		utility function for many register
		you can use gt1, ..., gtn and rax, rdx
		gp0 : 1st parameter
		gp1 : 2nd parameter
		gp2 : 3rd parameter
		gtn : max gtn
		numQword : alloca stack if necessary
			rsp[0..8 * numQrod - 1] are available
	*/
	int storeReg(int gtn, int numQword = 0)
	{
		const Reg64 tbl[] = {
			gt3, gt4, gt5, gt6, gt7, gt8, gt9, gt10
		};
		assert(0 <= gtn && gtn <= 10);
		gtn_ = gtn;
#ifdef _WIN32
		const int P = 8 * (std::max(0, gtn - 6) + numQword);
		if (P > 0) sub(rsp, P);
		for (int i = 3; i <= std::min(gtn, 6); i++) {
			mov(ptr [rsp + P + (i - 2) * 8], tbl[i - 3]);
		}
		for (int i = 7; i <= gtn; i++) {
			mov(ptr [rsp + P - 8 * (i - 6)], tbl[i - 3]);
		}
#else
		const int P = 8 * (std::max(0, gtn - 4) + numQword);
		if (P > 0) sub(rsp, P);
		for (int i = 5; i <= gtn; i++) {
			mov(ptr [rsp + P - 8 * (i - 4)], tbl[i - 3]);
		}
#endif
		mov(r9, rdx);
		return P;
	}
	/*
		specify P as the return value of storeReg
	*/
	void restoreReg(int P)
	{
		const Reg64 tbl[] = {
			gt3, gt4, gt5, gt6, gt7, gt8, gt9, gt10
		};
		assert(0 <= gtn_ && gtn_ <= 10);
#ifdef _WIN32
		for (int i = 3; i <= std::min(gtn_, 6); i++) {
			mov(tbl[i - 3], ptr [rsp + P + (i - 2) * 8]);
		}
		for (int i = 7; i <= gtn_; i++) {
			mov(tbl[i - 3], ptr [rsp + P - 8 * (i - 6)]);
		}
#else
		for (int i = 5; i <= gtn_; i++) {
			mov(tbl[i - 3], ptr [rsp + P - 8 * (i - 4)]);
		}
#endif
		if (P > 0) add(rsp, P);
	}
	void init(const mie::Vuint& p, int mode, bool useMulx)
	{
		detectCpu(mode, useMulx);

		// make some parameters for mulmod and Fp_mul
		const size_t N = 64;
		typedef mie::ZmZ<mie::Vuint, PairingCode> Z;
		Z::setModulo(mie::Vuint(1) << N);
		Z x(p);
		x = -x;
		x.inverse();
		pp_ = x[0];

		// generate code
		set_p_Fp_mul();
		set_p_Fp2_neg();
		set_p_Fp2_add();
		set_p_Fp2_sub();
		set_p_Fp2_addNC();
		set_p_FpDbl_mod();
		set_p_Fp2_square();
		set_p_Fp2_mul();
		set_p_Fp2_divBy2();
		set_p_Fp2_2z_add_3x();
		set_p_FpDbl_add();
		set_p_FpDbl_sub();
		set_p_FpDbl_addNC();
		set_p_FpDbl_subNC();
		set_p_Fp2Dbl_mul_xi();
		set_p_Fp2Dbl_mulOpt(1);
		set_p_Fp2Dbl_mulOpt(2);
		set_p_Fp2Dbl_square();
		set_p_Fp6_add();
		set_p_Fp6_sub();
		set_p_Fp6Dbl_mul();
		set_p_Fp6_mul();

		// Fp
		typedef void (*opFpx2)(Fp&, const Fp&);
		typedef void (*opFpx3)(Fp&, const Fp&, const Fp&);

		Fp::add = getCurr<opFpx3>();
		make_Fp_add(1);

		align(16);
		Fp::sub = getCurr<opFpx3>();
		make_Fp_sub(1);

		align(16);
		Fp::addNC = getCurr<opFpx3>();
		make_Fp_addNC(1);

		align(16);
		Fp::subNC = getCurr<opFpx3>();
		make_Fp_subNC();

		align(16);
		Fp::neg = getCurr<opFpx2>();
		make_Fp_neg();

		align(16);
		Fp::shr1 = getCurr<opFpx2>();
		make_Fp_shr(1);

		align(16);
		Fp::shr2 = getCurr<opFpx2>();
		make_Fp_shr(2);
		align(16);
		Fp::mul = getCurr<opFpx3>();
		make_Fp_mul();

		align(16);
		Fp::preInv = getCurr<int (*)(Fp&, const Fp&)>();
		make_Fp_preInv();

		// setup FpDbl

		align(16);
		FpDbl::add = getCurr<FpDbl::bin_op*>(); // QQQ
		make_FpDbl_add(1);

		align(16);
		FpDbl::addNC = getCurr<FpDbl::bin_op*>();
		make_FpDbl_addNC(1);

		align(16);
		FpDbl::neg = getCurr<FpDbl::uni_op*>();
		make_FpDbl_neg();

		align(16);
		FpDbl::sub = getCurr<FpDbl::bin_op*>();
		make_FpDbl_sub(1);

		align(16);
		FpDbl::subNC = getCurr<FpDbl::bin_op*>();
		make_FpDbl_subNC(1);

		align(16);
		FpDbl::mul = getCurr<void (*)(FpDbl &, const Fp &, const Fp &)>();
		make_FpDbl_mul();

		align(16);
		Fp::Dbl::mod = getCurr<void (*)(Fp &, const FpDbl &)>(); // QQQ
		make_FpDbl_mod();

		// setup Fp2
		typedef void (*opFp2x2)(Fp2&, const Fp2&);
		typedef void (*opFp2x3)(Fp2&, const Fp2&, const Fp2&);

		align(16);
		Fp2::add = getCurr<opFp2x3>();
		make_Fp_add(2);

		align(16);
		Fp2::addNC = getCurr<opFp2x3>();
		make_Fp_addNC(2);

		align(16);
		Fp2::sub = getCurr<opFp2x3>();
		make_Fp_sub(2);

		align(16);
		Fp2::mul = getCurr<opFp2x3>();
		make_Fp2_mul();

		align(16);
		Fp2::mul_xi = getCurr<opFp2x2>();
		make_Fp2_mul_xi();

		align(16);
		Fp2::square = getCurr<opFp2x2>();
		make_Fp2_square();

		align(16);
		Fp2::mul_Fp_0 = getCurr<void (*)(Fp2&, const Fp2&, const Fp&)>();
		make_Fp2_mul_Fp_0();

		align(16);
		Fp2::divBy2 = getCurr<opFp2x2>();
		make_Fp2_divBy2();

		// setup Fp2::Dbl

		align(16);
		Fp2Dbl::add = getCurr<Fp2Dbl::bin_op*>();
		make_FpDbl_add(2);

		align(16);
		Fp2Dbl::addNC = getCurr<Fp2Dbl::bin_op*>();
		make_FpDbl_addNC(2);

		align(16);
		Fp2Dbl::neg = getCurr<Fp2Dbl::uni_op*>();
		make_Fp2Dbl_neg();

		align(16);
		Fp2Dbl::sub = getCurr<Fp2Dbl::bin_op*>();
		make_FpDbl_sub(2);

		align(16);
		Fp2Dbl::subNC = getCurr<Fp2Dbl::bin_op*>();
		make_FpDbl_subNC(2);

		align(16);
		Fp2Dbl::mulOpt1 = getCurr<void (*)(Fp2Dbl &, const Fp2 &, const Fp2 &)>();
		make_Fp2Dbl_mulOpt(1);

		align(16);
		Fp2Dbl::mulOpt2 = getCurr<void (*)(Fp2Dbl &, const Fp2 &, const Fp2 &)>();
		make_Fp2Dbl_mulOpt(2);

		align(16);
		Fp2Dbl::square = getCurr<void (*)(Fp2Dbl &, const Fp2 &)>();
		make_Fp2Dbl_square();

		align(16);
		Fp2Dbl::mod = getCurr<void (*)(Fp2 &, const Fp2Dbl &)>();
		make_Fp2Dbl_mod();

		align(16);
		Fp2Dbl::mul_xi = getCurr<void (*)(Fp2Dbl &, const Fp2Dbl &)>();
		make_Fp2Dbl_mul_xi();

		// setup Fp6
		typedef void (*opFp6x3)(Fp6&, const Fp6&, const Fp6&);

		align(16);
		Fp6::add = getCurr<opFp6x3>();
		make_Fp6_add();

		align(16);
		Fp6::sub = getCurr<opFp6x3>();
		make_Fp6_sub();

		align(16);
		Fp6::pointDblLineEval = getCurr<void (*)(Fp6&, Fp2*, const Fp*)>();
		make_pointDblLineEval(false);
		align(16);
		Fp6::pointDblLineEvalWithoutP = getCurr<void (*)(Fp6&, Fp2 *)>();
		make_pointDblLineEval(true);

		align(16);
		Fp6Dbl::mul = getCurr<void (*)(Fp6Dbl&, const Fp6&, const Fp6&)>();
		make_Fp6Dbl_mul();

		align(16);
		Fp6::mul = getCurr<opFp6x3>();
		make_Fp6_mul();

		align(16);
		Compress::square_n = getCurr<void (*)(Compress&, int n)>();
		make_Compress_square_n();

		align(16);
		Fp12::square = getCurr<void (*)(Fp12& z)>();
		make_Fp12_square();

		align(16);
		Fp12::mul = getCurr<void (*)(Fp12& z, const Fp12& x, const Fp12& y)>();
		make_Fp12_mul();

		align(16);
		Fp12Dbl::mul_Fp2_024 = getCurr<void (*)(Fp12 &x, const Fp6& y)>();
		make_Fp12Dbl_mul_Fp2_024();

//		printf("jit code size=%d\n", (int)getSize());
	}
	bool isRaxP_; // true if rax is set to a pointer to p
	uint64_t pp_; // for Fp_mul
	void *p_Fp_mul;
	void *p_Fp2_neg;
	void *p_Fp2_add;
	void *p_Fp2_sub;
	void *p_Fp2_square;
	void *p_Fp2_mul;
	void *p_Fp2_divBy2;
	void *p_Fp2_addNC;
	void *p_Fp2_2z_add_3x;
	void *p_FpDbl_add;
	void *p_FpDbl_sub;
	void *p_FpDbl_addNC;
	void *p_FpDbl_subNC;
	void *p_FpDbl_mod;
	void *p_Fp2Dbl_mulOpt1;
	void *p_Fp2Dbl_mulOpt2;
	void *p_Fp2Dbl_square;
	void *p_Fp2Dbl_mul_xi;
	void *p_Fp6_add;
	void *p_Fp6_sub;
	void *p_Fp6_mul;
	void *p_Fp6Dbl_mul;
	int gtn_;
	const Reg64& a;
	const Reg64& d;
	const Reg64& gp1;
	const Reg64& gp2;
	const Reg64& gp3;
	const Reg64& gt1;
	const Reg64& gt2;
	const Reg64& gt3;
	const Reg64& gt4;
	const Reg64& gt5;
	const Reg64& gt6;
	const Reg64& gt7;
	const Reg64& gt8;
	const Reg64& gt9;
	const Reg64& gt10;
};
#endif // MIE_USE_X64ASM

void Fp::setTablesForDiv(const mie::Vuint& p)
{
	// for divBy2
	assert((p[0] & 0x1) == 1);
	halfTbl_[0].clear();
	Fp::setDirect(halfTbl_[1], (p+1)>>1);

	// for divBy4
	assert((p[0] & 0x3) == 3);
	quarterTbl_[0].clear();
	mie::Vuint quarter = (p+1)>>2;
	Fp::setDirect(quarterTbl_[1], quarter);
	Fp::setDirect(quarterTbl_[2], quarter*2);
	Fp::setDirect(quarterTbl_[3], quarter*3);
}

void Fp::setModulo(const mie::Vuint& p, int mode, bool useMulx, bool definedBN_SUPPORT_SNARK)
{
#ifdef DEBUG_COUNT
	puts("DEBUG_COUNT mode on!!!");
#endif
#ifdef BN_SUPPORT_SNARK
	const bool scipr = true;
#else
	const bool scipr = false;
#endif
	if (scipr != definedBN_SUPPORT_SNARK) {
		fprintf(stderr, "use -DBN_SUPPORT_SNARK for all sources\n");
		exit(1);
	}
	static bool init = false;
	if (init) return;
	init = true;
	if (p.size() != Fp::N) {
		mie::local::errExit("not support p for Fp::setModulo");
	}
	p_ = p;

	// Fp_mul
	{
		typedef mie::ZmZ<Vuint, MontgomeryTest> ZN;
		ZN::setModulo(Vuint(1) << (sizeof(Unit) * 8));
		ZN t(p);
		t = -t;
		t.inverse();
		pp_mont = t[0];
		pN = p << 256;
		p_add1_div4_ = (p + 1) / 4;
	}

	// we can't use Fp before setting Fp_mul* variables!!!
	montgomeryR_ = (Vuint(1) << 256) % p;
	{
		typedef mie::ZmZ<mie::Vuint, MontgomeryDummy> Z;
		Z::setModulo(p);
		Z t(montgomeryR_);
		Fp::setDirect(montgomeryR2_, t * t);
	}
	one_.clear();
	one_[0] = 1;

	Fp_emu::setModulo(p);
	try {
		// setup code and data area
		const int PageSize = 4096;
		const size_t codeSize = PageSize * 9;
		const size_t dataSize = PageSize * 1;

		static std::vector<Xbyak::uint8> buf;
		buf.resize(codeSize + dataSize + PageSize);
		Xbyak::uint8 *const codeAddr = Xbyak::CodeArray::getAlignedAddress(&buf[0], PageSize);
		Xbyak::CodeArray::protect(codeAddr, codeSize, true);
		s_data = Xbyak::CastTo<Data*>(codeAddr + codeSize);

//		printf("codeAddr=%p, dataAddr=%p\n", codeAddr, s_data);
		if ((size_t)codeAddr & 0xffffffff00000000ULL || (size_t)s_data & 0xffffffff00000000ULL) {
			// printf("\naddress of code and data is over 4GB!!!\n");
		}

		// setup data
		s_pTbl = s_data->pTbl;
		Fp::halfTbl_ = s_data->halfTbl;
		Fp::quarterTbl_ = s_data->quarterTbl;
		bn::FpDbl::pNTbl_ = s_data->pNTbl;

		for (size_t i = 0; i < pTblSize; i++) {
			Fp::setDirect(s_pTbl[i], p * int(i));
		}
		/*
			for option1
			lower 192-bits of pNTbl_[1] = 0
			lower 192-bits of pNTbl_[2] = 0
		*/
		Fp::Dbl::pNTbl_[0].setDirect(pN);
		for (size_t h = 1; h < pNtblSize; ++h) {
			Fp::Dbl::pNTbl_[h].setDirect(pN >> h);
		}
		setTablesForDiv(p);

		// setup code
		static PairingCode code(codeSize, codeAddr);
		code.init(p_, mode, useMulx);
		{
			Fp t(2);
			for (int i = 0; i < 512; i++) {
				invTbl_[511 - i] = t;
				t += t;
			}
		}
		return;
	} catch (std::exception& e) {
		fprintf(stderr, "setModulo ERR:%s\n", e.what());
	}
	::exit(1);
}

