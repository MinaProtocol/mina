#include <stdio.h>
#include <memory.h>
#ifndef XBYAK_NO_OP_NAMES
	#define XBYAK_NO_OP_NAMES
#endif
#include "xbyak/xbyak_util.h"
extern Xbyak::util::Clock sclk;
#include "bn.h"
#include <iostream>
#include "util.h"
#include <cybozu/benchmark.hpp>
#include "test_point.hpp"

#define NUM_OF_ARRAY(x) (sizeof(x) / sizeof(*x))

using namespace bn;
using namespace ecop;

static int s_errNum = 0;
static int s_testNum = 0;

#define TEST_EQUAL(x, y) { s_testNum++; if (x != y) { s_errNum++; printf("%s(%d): err %s != %s\n", __FILE__, __LINE__, #x, #y); std::cout << "lhs=" << (x) << "\nrhs=" << (y) << std::endl; } }
#define TEST_ASSERT(x) { s_testNum++; if (!(x)) { s_errNum++; printf("%s(%d): err assert %s\n", __FILE__, __LINE__, #x); } }

#define FATAL_EXIT(msg) { printf("%s(%d): err %s\n", __FILE__, __LINE__, msg); exit(1); }

const mie::Vuint& p = Param::p;
const mie::Vuint& r = Param::r;

void benchFp()
{
	Fp x("1234566239428049280498203948209482039482");
	Fp y("999999999999999999999999999999999999999");
	Fp::Dbl d;
	CYBOZU_BENCH("Fp::add   ", Fp::add, x, x, y);
	CYBOZU_BENCH("Fp::sub   ", Fp::sub, x, x, y);
	CYBOZU_BENCH("Fp::neg   ", Fp::neg, x, x);
	CYBOZU_BENCH("Fp::mul   ", Fp::mul, x, x, y);
	CYBOZU_BENCH("Fp::inv   ", Fp::inv, x, x);
	CYBOZU_BENCH("mul256    ", Fp::Dbl::mul, d, x, y);
	CYBOZU_BENCH("mod512    ", Fp::Dbl::mod, x, d);
	CYBOZU_BENCH("Fp::divBy2", Fp::divBy2, x, x);
	CYBOZU_BENCH("Fp::divBy4", Fp::divBy4, x, x);
}
void benchFp2()
{
	Fp2 x, y;
	x.a_.set("4");
	x.b_.set("464652165165");
	y = x * x;
	CYBOZU_BENCH("Fp2::add     ", Fp2::add, x, x, y);
	CYBOZU_BENCH("Fp2::addNC   ", Fp2::addNC, x, x, y);
	CYBOZU_BENCH("Fp2::sub     ", Fp2::sub, x, x, y);
	CYBOZU_BENCH("Fp2::neg     ", Fp2::neg, x, x);
	CYBOZU_BENCH("Fp2::mul     ", Fp2::mul, x, x, y);
	CYBOZU_BENCH("Fp2::inverse ", x.inverse);
	CYBOZU_BENCH("Fp2::square  ", Fp2::square, x, x);
	CYBOZU_BENCH("Fp2::mul_xi  ", Fp2::mul_xi, x, x);
	CYBOZU_BENCH("Fp2::mul_Fp_0", Fp2::mul_Fp_0, x, x, Param::half);
	CYBOZU_BENCH("Fp2::mul_Fp_1", Fp2::mul_Fp_1, x, Param::half);
	CYBOZU_BENCH("Fp2::divBy2  ", Fp2::divBy2, x, x);
	CYBOZU_BENCH("Fp2::divBy4  ", Fp2::divBy4, x, x);
}

void test_multi(const bn::CurveParam& cp)
{
	puts(__FUNCTION__);
	const Point& pt = selectPoint(cp);
	const Fp2 g2[3] = {
		Fp2(Fp(pt.g2.aa), Fp(pt.g2.ab)),
		Fp2(Fp(pt.g2.ba), Fp(pt.g2.bb)),
		Fp2(1, 0),
	};
	const Fp g1[3] = { pt.g1.a, pt.g1.b, 1 };
	Fp12 e;
	benchFp();
	benchFp2();
	CYBOZU_BENCH("finalexp", e.final_exp);
	CYBOZU_BENCH("pairing", opt_atePairingJac<Fp>, e, g2, g1);

	Fp12 e2;
	std::vector<Fp6> Qcoeff;
	Fp2 precQ[3];
	bn::components::precomputeG2(Qcoeff, precQ, g2);
	Fp precP[3];
	bn::ecop::NormalizeJac(precP, g1);
	bn::components::millerLoop(e2, Qcoeff, precP);
	e2.final_exp();
	TEST_EQUAL(e, e2);
	CYBOZU_BENCH("precomp   ", bn::components::precomputeG2, Qcoeff, precQ, g2);
	CYBOZU_BENCH("millerLoop", bn::components::millerLoop, e2, Qcoeff, precP);
}

#ifdef BN_SUPPORT_SNARK

int main(int argc, char *argv[])
{
	int b = 3;
	if (argc >= 2) {
		b = atoi(argv[1]);
		if (b != 3 && b != 82) {
			printf("not support b=%d\n", b);
			return 1;
		}
	}
	printf("SNARK b = %d\n", b);
	bn::CurveParam cp = bn::CurveSNARK1;
	cp.b = b;
	bn::Param::init(cp);
	test_multi(cp);
	if (sclk.getCount()) printf("sclk:%.2fclk(%dtimes)\n", sclk.getClock() / double(sclk.getCount()), sclk.getCount());
	printf("err=%d(test=%d)\n", s_errNum, s_testNum);
}
#else
/*
	generate a value of the X-coordinate of P
*/
const Fp genPx()
{
	const Fp Px = Fp(2);
	return Px;
}
/*
	generate a value of the Y-coordinate of P
*/
const Fp genPy()
{
	const Fp Py = Fp("16740896641879863340107777353588575149660814923656713498672603551465628253431");
	return Py;
}

/*
	generate a value of the X-coordinate of [2]P
*/
const Fp genP2x()
{
	const Fp P2x = Fp("13438486984812665827952643313785387127911349697151255879146972340858203091778");
	return P2x;
}
/*
	generate a value of the Y-coordinate of [2]P
*/
const Fp genP2y()
{
	const Fp P2y = Fp("12741389316352206200828479361093127917015298445269456291074734498988157668221");
	return P2y;
}

template<class F>
void SetJacobi(F out[3], const F* in)
{
	copy(out, in);
	const int z = 123;
	out[0] *= z * z;
	out[1] *= z * z * z;
	out[2] *= z;
}

void testECDouble()
{
	puts(__FUNCTION__);
	const Fp P[] = { genPx(), genPy(), Fp(1) };
	const Fp P2[] = { genP2x(), genP2y(), Fp(1) };
	const Fp Zero[] = { 1, 1, 0 };
	const struct {
		const Fp* ok; // ok = 2x
		const Fp* x;
	} tbl[] = {
		{ P2, P },
		{ Zero, Zero },
	};

	for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
		Fp x[3];
		SetJacobi(x, tbl[i].x);
		const Fp* ok = tbl[i].ok;

		for (int m = 0; m < 2; m++) {
			Fp out[3];

			if (m == 0) {
				// dst != src
				ECDouble(out, x);
			} else {
				out[0] = x[0];
				out[1] = x[1];
				out[2] = x[2];
				// dst != src
				ECDouble(out, out);
			}

			TEST_ASSERT(isOnECJac3(out));
			NormalizeJac(out, out);
			TEST_ASSERT(isOnECJac3(out));

			if (ok[2] != 0) {
				TEST_EQUAL(out[0], ok[0]);
				TEST_EQUAL(out[1], ok[1]);
			}

			TEST_EQUAL(out[2], ok[2]);
		}
	}
}

void testECAdd()
{
	puts(__FUNCTION__);
	const Fp P[] = { genPx(), genPy(), Fp(1) };
	const Fp negP[] = { genPx(), -genPy(), Fp(1) };
	const Fp P2[] = { genP2x(), genP2y(), Fp(1) };
	const Fp P3[] = {
		Fp("933228262834212904718933563457318550549399284524392769385206412559597436928"),
		Fp("13081617668227268048378253503661144166646030151223471427486357073175298320248"),
		Fp(1),
	};
	const Fp Zero[] = { 1, 1, 0 };
	{
		const struct {
			const Fp* ok; // ok = x + y
			const Fp* x;
			const Fp* y;
		} tbl[] = {
			{ P3, P, P2 },
			{ P3, P2, P },
			{ P2, P, P },
			{ Zero, P, negP },
			{ Zero, negP, P },

			{ P, P, Zero },
			{ P, Zero, P },
			{ Zero, Zero, Zero },
		};

		for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
			Fp x[3]; SetJacobi(x, tbl[i].x);
			Fp y[3]; SetJacobi(y, tbl[i].y);
			const Fp* ok = tbl[i].ok;

			for (int m = 0; m < 3; m++) {
				Fp out[3];

				if (m == 0) { // z <- (x, y)
					ECAdd(out, x, y);
				} else if (m == 1) { // x <- (x, y)
					copy(out, x);
					ECAdd(out, out, y);
				} else { // y <- (x, y)
					copy(out, y);
					ECAdd(out, x, out);
				}

				TEST_ASSERT(isOnECJac3(out));
				NormalizeJac(out, out);
				TEST_ASSERT(isOnECJac3(out));

				if (ok[2] != 0) {
					TEST_EQUAL(out[0], ok[0]);
					TEST_EQUAL(out[1], ok[1]);
				}

				TEST_EQUAL(out[2], ok[2]);
			}
		}
	}
	{
		const struct {
			const Fp* ok; // ok = 2x
			const Fp* x;
		} tbl[] = {
			{ P2, P },
			{ Zero, Zero },
		};

		for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
			Fp x[3]; SetJacobi(x, tbl[i].x);
			const Fp* ok = tbl[i].ok;

			for (int m = 0; m < 2; m++) {
				Fp out[3];

				if (m == 0) { // z <- (x, x)
					ECAdd(out, x, x);
				} else {
					copy(out, x);
					ECAdd(out, out, out); // x <- (x, x)
				}

				TEST_ASSERT(isOnECJac3(out));
				NormalizeJac(out, out);
				TEST_ASSERT(isOnECJac3(out));

				if (ok[2] != 0) {
					TEST_EQUAL(out[0], ok[0]);
					TEST_EQUAL(out[1], ok[1]);
				}

				TEST_EQUAL(out[2], ok[2]);
			}
		}
	}
}

void testECOperationsG1(bool allBench)
{
	puts(__FUNCTION__);
	const Fp P[] = { genPx(), genPy(), Fp(1) };
	TEST_ASSERT(isOnECJac3(P));
	const Fp R[] = {
		Fp("13444485882265322272857095018562747159513775856924555608551532122942502696033"),
		Fp("11811997307285544251176681325629039017467625014708607213193666012921830535998"),
		Fp(1),
	};
	TEST_ASSERT(isOnECJac3(R));
	const Fp P2_ok[] = { genP2x(), genP2y(), Fp(1) };
	TEST_ASSERT(isOnECJac3(P2_ok));
	const Fp P3_ok[] = {
		Fp("933228262834212904718933563457318550549399284524392769385206412559597436928"),
		Fp("13081617668227268048378253503661144166646030151223471427486357073175298320248"),
		Fp(1),
	};
	TEST_ASSERT(isOnECJac3(P3_ok));
	const Fp PR_ok[] = {
		Fp("5029559281027098065112074313654538061170641740632027092904459697655977527307"),
		Fp("8600928869174184710378059261155172010154737801304483073001259795547035852644"),
		Fp(1),
	};
	TEST_ASSERT(isOnECJac3(PR_ok));
	const std::string m_str("9347746330740818252600716999005395295745642941583534686803606077666502");
	const Fp Pm_ok[] = {
		Fp("8336933749104329731435220896541057907796368507118046070748143351359530106012"),
		Fp("4188048486869311245492662268177668835013141885357103548787568172806640854865"),
		Fp(1),
	};
	TEST_ASSERT(isOnECJac3(Pm_ok));
	{
		Fp P2[3];
		ECDouble(P2, P);
		TEST_ASSERT(isOnECJac3(P2));
		NormalizeJac(P2, P2);
		TEST_ASSERT(isOnECJac3(P2));
		TEST_EQUAL(P2[0], P2_ok[0]);
		TEST_EQUAL(P2[1], P2_ok[1]);
		TEST_EQUAL(P2[2], P2_ok[2]);
		if (allBench) CYBOZU_BENCH("ECDouble", ECDouble<Fp>, P2, P);
	}
	{
		Fp P3[] = { P[0], P[1], P[2], };
		Fp PR[] = { P[0], P[1], P[2], };
		ECAdd(P3, P3, P2_ok);
		ECAdd(PR, PR, R);
		TEST_ASSERT(isOnECJac3(P3));
		TEST_ASSERT(isOnECJac3(PR));
		NormalizeJac(P3, P3);
		NormalizeJac(PR, PR);
		TEST_ASSERT(isOnECJac3(P3));
		TEST_ASSERT(isOnECJac3(PR));
		TEST_EQUAL(P3[0], P3_ok[0]);
		TEST_EQUAL(P3[1], P3_ok[1]);
		TEST_EQUAL(P3[2], P3_ok[2]);
		TEST_EQUAL(PR[0], PR_ok[0]);
		TEST_EQUAL(PR[1], PR_ok[1]);
		TEST_EQUAL(PR[2], PR_ok[2]);
		if (allBench) CYBOZU_BENCH("ECAdd", ECAdd<Fp>, PR, P, R);
	}
	{
		mie::Vuint m;
		Fp Pm[3], Pm_norm[3];
		m = 0;
		ScalarMult(Pm, P, m);
		TEST_ASSERT(isOnECJac3(Pm));
		TEST_EQUAL(Pm[2], 0);
		NormalizeJac(Pm_norm, Pm);
		TEST_ASSERT(isOnECJac3(Pm_norm));
		TEST_EQUAL(Pm_norm[2], 0);

		m = 1;
		ScalarMult(Pm, P, m);
		TEST_ASSERT(isOnECJac3(Pm));
		NormalizeJac(Pm_norm, Pm);
		TEST_ASSERT(isOnECJac3(Pm_norm));
		TEST_EQUAL(Pm_norm[0], P[0]);
		TEST_EQUAL(Pm_norm[1], P[1]);
		TEST_EQUAL(Pm_norm[2], P[2]);

		m = 2;
		ScalarMult(Pm, P, m);
		TEST_ASSERT(isOnECJac3(Pm));
		NormalizeJac(Pm_norm, Pm);
		TEST_ASSERT(isOnECJac3(Pm_norm));
		TEST_EQUAL(Pm_norm[0], P2_ok[0]);
		TEST_EQUAL(Pm_norm[1], P2_ok[1]);
		TEST_EQUAL(Pm_norm[2], P2_ok[2]);

		m = 3;
		ScalarMult(Pm, P, m);
		TEST_ASSERT(isOnECJac3(Pm));
		NormalizeJac(Pm_norm, Pm);
		TEST_ASSERT(isOnECJac3(Pm_norm));
		TEST_EQUAL(Pm_norm[0], P3_ok[0]);
		TEST_EQUAL(Pm_norm[1], P3_ok[1]);
		TEST_EQUAL(Pm_norm[2], P3_ok[2]);

		m.set(m_str);
		ScalarMult(Pm, P, m);
		TEST_ASSERT(isOnECJac3(Pm));
		NormalizeJac(Pm, Pm);
		TEST_ASSERT(isOnECJac3(Pm));
		TEST_EQUAL(Pm[0], Pm_ok[0]);
		TEST_EQUAL(Pm[1], Pm_ok[1]);
		TEST_EQUAL(Pm[2], Pm_ok[2]);

		if (allBench) CYBOZU_BENCH("ScalarMult", (ScalarMult<Fp, mie::Vuint>), Pm, P, m);
	}
	{
		const mie::Vuint& r = Param::r;
		Fp Pz[3], Rz[3];
		ScalarMult(Pz, P, r);
		ScalarMult(Rz, R, r);
		TEST_ASSERT(Pz[2].isZero());
		TEST_ASSERT(Rz[2].isZero());
	}
}

void testFp2()
{
	puts(__FUNCTION__);
	Fp2 x, y, z;
	x.a_ = 1;
	x.b_ = 2;
	y.a_ = 3;
	y.b_ = 4;
	Fp2::mul(z, x, y);
	x.a_.set("1");
	x.b_.set("0");
	z = x * x;
	PUT(x);
	Fp2::square(y, x);
	TEST_EQUAL(z, y);
	x.a_.set("4");
	x.b_.set("464652165165");
	z.a_.set("16798108731015832284940804142231733909889187121439069633032080833550314387514");
	z.b_.set("3717217321320");
	y = x * x;
	Fp2::square(x, x);
	TEST_EQUAL(x, z);
	TEST_EQUAL(y, z);
	{
		std::ostringstream oss;
		oss << x;
		std::istringstream iss(oss.str());
		Fp2 w;
		iss >> w;
		TEST_EQUAL(x, w);
	}
	y = mie::power(x, p * p);
	TEST_EQUAL(y, x);
	y = x;
	y.inverse();
	x *= y;
	TEST_EQUAL(x, Fp2(1));
	{
		Fp c1 = x.a_ / Fp(2);
		Fp c2 = x.a_;
		Fp::divBy2(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp c1 = x.b_ / Fp(2);
		Fp c2 = x.b_;
		Fp::divBy2(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp c1 = y.a_ / Fp(2);
		Fp c2 = y.a_;
		Fp::divBy2(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp c1 = y.b_ / Fp(2);
		Fp c2 = y.b_;
		Fp::divBy2(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp c1 = z.a_ / Fp(2);
		Fp c2 = z.a_;
		Fp::divBy2(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp c1 = z.b_ / Fp(2);
		Fp c2 = z.b_;
		Fp::divBy2(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp c1 = x.a_ / Fp(4);
		Fp c2 = x.a_;
		Fp::divBy4(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp c1 = x.b_ / Fp(4);
		Fp c2 = x.b_;
		Fp::divBy4(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp c1 = y.a_ / Fp(4);
		Fp c2 = y.a_;
		Fp::divBy4(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp c1 = y.b_ / Fp(4);
		Fp c2 = y.b_;
		Fp::divBy4(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp c1 = z.a_ / Fp(4);
		Fp c2 = z.a_;
		Fp::divBy4(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp c1 = z.b_ / Fp(4);
		Fp c2 = z.b_;
		Fp::divBy4(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	Fp2 r2(Fp(2), Fp(0));
	r2.inverse();
	{
		Fp2 c1 = x * r2;// Fp2(Fp(2), Fp(0));
		Fp2 c2 = x;
		Fp2::divBy2(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp2 c1 = y * r2;/// Fp2(Fp(2), Fp(0));
		Fp2 c2 = y;
		Fp2::divBy2(c2, c2);
		TEST_EQUAL(c2, c1);
	}
	{
		Fp2 c1 = z * r2;/// Fp2(Fp(2), Fp(0));
		Fp2 c2 = z;
		Fp2::divBy2(c2, c2);
		TEST_EQUAL(c2, c1);
	}
}

/*
	generate a value of the X-coordinate of Q
*/
const Fp2& genQx()
{
	static const Fp2 Qx = Fp2(
		Fp("13234664681033688271405396239524358974366484883419628236101274746557464997054"),
		Fp("11347691494386824311357230151706543132011346014309658325337514955760433353199")
	);
	return Qx;
}
/*
	generate a value of the Y-coordinate of Q
*/
const Fp2& genQy()
{
	static const Fp2 Qy = Fp2(
		Fp("9427224573130940705767837740977388851395498800066112237265227139877389298881"),
		Fp("8452141316509224651353689669356928563000175149166480473836682926961687453514")
	);
	return Qy;
}

/*
	generate a value of the X-coordinate of [2]Q
*/
const Fp2& genQ2x()
{
	static const Fp2 Q2x = Fp2(
		Fp("5299180442706306781938040029147283818308705141288620744338313273731299805815"),
		Fp("15797930548095856607649462137302524883761892212429298307727251696384886639045")
	);
	return Q2x;
}
/*
	generate a value of the Y-coordinate of [2]Q
*/
const Fp2& genQ2y()
{
	static const Fp2 Q2y = Fp2(
		Fp("14682155566465612687855553028405011181016442868657350988232774125667855691350"),
		Fp("16774596877583816470230777985570065066758171976339091353731418650582998086894")
	);
	return Q2y;
}

void testECOperationsG2()
{
	puts(__FUNCTION__);
	const Fp2 P[] = { genQx(), genQy(), Fp2(Fp(1), Fp(0)) };
	TEST_ASSERT(isOnTwistECJac3(P));
	/*
		R = [m]P,
		m = 5966028534901141772758784140942452307515635636755408154850488537894844702903
	*/
	const Fp2 R[] = {
		Fp2(Fp("11704862095684563340633177014105692338896570212191553344841646079297773588350"),
			Fp("8109660419091099176077386016058664786484443690836266670000859598224113683590")),
		Fp2(Fp("13675004707765291840926741134330657174325775842323897203730447415462283202661"),
			Fp("6686821593302402098300348923000142044418144174058402521315042066378362212321")),
		Fp2(Fp(1), Fp(0)),
	};
	TEST_ASSERT(isOnTwistECJac3(R));
	/*
		P2 = P + P
	*/
	const Fp2 P2_ok[] = { genQ2x(), genQ2y(), Fp2(Fp(1), Fp(0)) };
	TEST_ASSERT(isOnTwistECJac3(P2_ok));
	/*
		P3 = P + P + P
	*/
	const Fp2 P3_ok[] = {
		Fp2(Fp("5041208034834306969246893597801606913952969715168759592126996067188338654460"),
			Fp("4745545055096211316438209286296610929317392331700796959265362461502810670741")),
		Fp2(Fp("4448845430036386900904134218385919238634516280940850750340057793276116990520"),
			Fp("5381197710638591824110650873873102215710463161465576982098481156644922737066")),
		Fp2(Fp(1), Fp(0)),
	};
	TEST_ASSERT(isOnTwistECJac3(P3_ok));
	/*
	  PR = P + R
	*/
	const Fp2 PR_ok[] = {
		Fp2(Fp("4101018695001932981939478048097100312454053747763620019092459247845054185862"),
			Fp("11837424651832479256515762856497142957022424405035735958314961199911873048158")),
		Fp2(Fp("4188277960223912253520496835244041970690458283101292677577969922331161931355"),
			Fp("6626563699999679639856135562000857142994474772523438562835858347560344528530")),
		Fp2(Fp(1), Fp(0)),
	};
	TEST_ASSERT(isOnTwistECJac3(PR_ok));
	const std::string m_str("9347746330740818252600716999005395295745642941583534686803606077666502");
	const Fp2 Pm_ok[] = {
		Fp2(Fp("10441210346477881509066116513368913513335705597787319222238764774307447511387"),
			Fp("14433824588814776544086946350203752791948488948859728417684455048057787177915")),
		Fp2(Fp("5562925282053339482485224304075873800061135879275456976861613117140339306723"),
			Fp("4780189879307383623106336041945958171623286554407266664048019152689513531681")),
		Fp2(Fp(1), Fp(0)),
	};
	TEST_ASSERT(isOnTwistECJac3(Pm_ok));
	{
		Fp2 P2[3];
		ECDouble(P2, P);
		TEST_ASSERT(isOnTwistECJac3(P2));
		Fp2 P2_norm[3];
		NormalizeJac(P2_norm, P2);
		TEST_ASSERT(isOnTwistECJac3(P2_norm));
		TEST_EQUAL(P2_norm[0], P2_ok[0]);
		TEST_EQUAL(P2_norm[1], P2_ok[1]);
		TEST_EQUAL(P2_norm[2], P2_ok[2]);
	}
	{
		Fp2 P3[3], PR[3];
		ECAdd(P3, P, P2_ok);
		ECAdd(PR, P, R);
		TEST_ASSERT(isOnTwistECJac3(P3));
		TEST_ASSERT(isOnTwistECJac3(PR));
		Fp2 P3_norm[3], PR_norm[3];
		NormalizeJac(P3_norm, P3);
		NormalizeJac(PR_norm, PR);
		TEST_ASSERT(isOnTwistECJac3(P3_norm));
		TEST_ASSERT(isOnTwistECJac3(PR_norm));
		TEST_EQUAL(P3_norm[0], P3_ok[0]);
		TEST_EQUAL(P3_norm[1], P3_ok[1]);
		TEST_EQUAL(P3_norm[2], P3_ok[2]);
		TEST_EQUAL(PR_norm[0], PR_ok[0]);
		TEST_EQUAL(PR_norm[1], PR_ok[1]);
		TEST_EQUAL(PR_norm[2], PR_ok[2]);
	}
	{
		mie::Vuint m;
		Fp2 Pm[3], Pm_norm[3];
		{
			m = 0;
			ScalarMult(Pm, P, m);
			TEST_ASSERT(isOnTwistECJac3(Pm));
			TEST_EQUAL(Pm[2], 0);
			NormalizeJac(Pm_norm, Pm);
			TEST_ASSERT(isOnTwistECJac3(Pm_norm));
			TEST_EQUAL(Pm_norm[2], 0);
		}
		{
			m = 1;
			ScalarMult(Pm, P, m);
			TEST_ASSERT(isOnTwistECJac3(Pm));
			NormalizeJac(Pm_norm, Pm);
			TEST_ASSERT(isOnTwistECJac3(Pm_norm));
			TEST_EQUAL(Pm_norm[0], P[0]);
			TEST_EQUAL(Pm_norm[1], P[1]);
			TEST_EQUAL(Pm_norm[2], P[2]);
		}
		{
			m = 2;
			ScalarMult(Pm, P, m);
			TEST_ASSERT(isOnTwistECJac3(Pm));
			NormalizeJac(Pm_norm, Pm);
			TEST_ASSERT(isOnTwistECJac3(Pm_norm));
			TEST_EQUAL(Pm_norm[0], P2_ok[0]);
			TEST_EQUAL(Pm_norm[1], P2_ok[1]);
			TEST_EQUAL(Pm_norm[2], P2_ok[2]);
		}
		{
			m = 3;
			ScalarMult(Pm, P, m);
			TEST_ASSERT(isOnTwistECJac3(Pm));
			NormalizeJac(Pm_norm, Pm);
			TEST_ASSERT(isOnTwistECJac3(Pm_norm));
			TEST_EQUAL(Pm_norm[0], P3_ok[0]);
			TEST_EQUAL(Pm_norm[1], P3_ok[1]);
			TEST_EQUAL(Pm_norm[2], P3_ok[2]);
		}
		m.set(m_str);
		ScalarMult(Pm, P, m);
		TEST_ASSERT(isOnTwistECJac3(Pm));
		NormalizeJac(Pm_norm, Pm);
		TEST_ASSERT(isOnTwistECJac3(Pm_norm));
		TEST_EQUAL(Pm_norm[0], Pm_ok[0]);
		TEST_EQUAL(Pm_norm[1], Pm_ok[1]);
		TEST_EQUAL(Pm_norm[2], Pm_ok[2]);
	}
	{
		const mie::Vuint& r = Param::r;
		Fp2 Pz[3], Rz[3];
		ScalarMult(Pz, P, r);
		ScalarMult(Rz, R, r);
		TEST_ASSERT(Pz[2].isZero());
		TEST_ASSERT(Rz[2].isZero());
	}
}

void testFp6()
{
	puts(__FUNCTION__);
	Fp6 x, y, z;

	for (int i = 0; i < 6; i++) {
		x.get()[i] = i * i + 3;
	}

	y = x * Fp6(2);
	x = x + x;
	TEST_EQUAL(x, y);
	x *= x;
	Fp6::square(z, y);
	TEST_EQUAL(x, z);
#ifdef MIE_ATE_USE_GMP
	mpz_class p6(p.toStr());
	p6 *= p6;
	p6 = p6 * p6 * p6;
	y = mie::power(x, p6);
	TEST_EQUAL(y, x);
#endif
	y = x; y.inverse();
	x *= y;
	TEST_EQUAL(x, Fp6(1));
	{
		std::ostringstream oss;
		oss << y;
		std::istringstream iss(oss.str());
		iss >> x;
		TEST_EQUAL(x, y);
	}
	{
		Fp2 t(Fp("50"), Fp("25"));
		Fp6 x(t, t, t);
		Fp6 inv_x = x; inv_x.inverse();
		x *= inv_x;
		TEST_EQUAL(x, 1);
	}
}

void testFp6Dbl()
{
	puts(__FUNCTION__);
	const Fp6 a(
		Fp2(Fp("12962627302162075398060982177087436574303347298537835668202414221253817262982"),
			Fp("138260844306952217670025767932179019912073169546101859135312230638880521223")),
		Fp2(Fp("15137160497776903814679214726809029070339754602997091488396727793679994724725"),
			Fp("14585393257630973637130780517598702183004769121002667593088137712456098389147")),
		Fp2(Fp("11656022636984400462137420855351583248422833051633377387451406154513829093114"),
			Fp("14215712895255419029580702653008196543286207503420913686381671784091829605544")));
	const Fp6Dbl ad(
		"1593170926598915345387635677083748286590764833236455841205970156921632690659321696124459206976218892050264244158092130253877279907839544343324979280024170",
		"1179973114230341892737360925692630156593789184269536881494768733457774943578761248088761269289336962320683158703377660715101868763181549734994595794867496",
		"730145342724752832742804498354752537572280628992449438960103160339237082085998618512864763426475086477471191730731012602806937310004548457512536010563048",
		"678118683224664762511490289199702755525092922001331540945747396044828904358828485331396580462479434002293484047506951365087686946333164073941237815303466",
		"1696690105116639227371389908462484956149748096108668929604390112965542312011722226936838080163446882161586173219949938265621015171049147844994233756309066",
		"67733454177668654989670636173597892971566229940879910979133487599488650994140729503900163935167021366038874739997773956034575689900205013416256257888322");
	const Fp6 b(
		Fp2(Fp("13266032064412835795130953448702250621050762510696965292045893361178860841079"),
			Fp("2457069570102593370680131966272186058752442119075136300728910430721054975883")),
		Fp2(Fp("2761323283613335519656714595170176518640718973086035562998271277678441691369"),
			Fp("9282239544249417776161170354699989681427448957391036300962080470210029743316")),
		Fp2(Fp("4725335130491002940371667092034595414883167034697622603206446595963780685950"),
			Fp("2979604114551910299899042707207603351108418195709860388438523763202896562826")));
	const Fp6Dbl bd(
		"1475839844663843322570757741744775997036014731165662766646651170904291281982509370757030826186551260691254724613316384521255185802946693994015137182068602",
		"1095370597739171250835471130891927869346414000670922062465412467538839645554804526075383358963227758462571697459677545719232104735169846503013457660892884",
		"536047623091184724949149589675730696115091482580183754959193574690322789326610874996202176921473611369946983196347243075470791570525589963488361345383304",
		"567095369910236561517167429427649270237483207499847850016456655352630986857858611181208043791533419484288551607360907558060915416405739300095090914524646",
		"1628045414693061051387160519487414991569044842223778536119706327028677432835046952047761290724596114203937423373736927070986873116393928193270995863382370",
		"113601886886856063908255915522830311745119439542360068010955258226612862901220453756679629604364967513217403777663391468064348420745734171787344796709574");
	{
		Fp6 t;
		Fp6Dbl::mod(t, ad);
		TEST_EQUAL(t, a);
		Fp6Dbl::mod(t, bd);
		TEST_EQUAL(t, b);
	}
	{
		const Fp6 c = a + b;
		const Fp6Dbl cd = ad + bd;
		Fp6 t;
		Fp6Dbl::mod(t, cd);
		TEST_EQUAL(t, c);
	}
	{
		const Fp6 c = -a;
		const Fp6Dbl cd = -ad;
		Fp6 t;
		Fp6Dbl::mod(t, cd);
		TEST_EQUAL(t, c);
	}
	{
		const Fp6 c = a - b;
		const Fp6Dbl cd = ad - bd;
		Fp6 t;
		Fp6Dbl::mod(t, cd);
		TEST_EQUAL(t, c);
	}
	{
		const Fp6 c = a * b;
		Fp6Dbl cd;
		Fp6Dbl::mul(cd, a, b);
		Fp6 t;
		Fp6Dbl::mod(t, cd);
		TEST_EQUAL(t, c);
	}
}

void testFp12()
{
	puts(__FUNCTION__);
	TEST_EQUAL(sizeof(Fp12), sizeof(Fp) * 12);
	Fp12 x, y;

	for (int i = 0; i < 12; i++) {
		x.get()[i] = i + 3;
	}

	y = x * Fp12(2);
	x = x + x;
	TEST_EQUAL(x, y);
	x *= x;
	Fp12::square(y);
	TEST_EQUAL(x, y);

	for (int i = 0; i < 12; i++) {
		TEST_EQUAL(x.get()[i], y.get()[i]);
	}

#ifdef MIE_ATE_USE_GMP
	mpz_class p12(p.toStr());
	p12 *= p12;
	p12 *= p12;
	p12 = p12 * p12 * p12;
	y = mie::power(x, p12);
	TEST_EQUAL(y, x);
#endif
	y = x; y.inverse();
	x *= y;
	TEST_EQUAL(x, Fp12(1));
	{
		std::ostringstream oss;
		oss << y;
		std::istringstream iss(oss.str());
		iss >> x;
		TEST_EQUAL(x, y);
	}
}

void test_final_exp()
{
	puts(__FUNCTION__);
	/*
	  @note: Large exponent can not be used. Fix mie::Vuint.
	*/
	std::string x_ok[] = {
		"11740569797851521013113382206139723952380476000114006726254700017011388077491",
		"11620869091920297152310912851876223249241005004927120638208161874259694264776",
		"14319816424335732586640646744712820835577263950059423761702049659454143614010",
		"8979195516353115834499099104570340580610233612320353839807503737299124538894",
		"3889724809319970439398470559040488185853720726993744629936064081043226370937",
		"8413606802647893249443694454915434425270568587052196647221488597304121045130",
		"14595160807872212739731328980223779718645553907712177545489677083052892894971",
		"14502774460357020920607411114414652729864247679483682272558415181562578814999",
		"10561873726035110127922260604858986830025105803068865817827274807245635306750",
		"7550390871387103641373102946170924993232803081589755675446081315707092125599",
		"6140564006391685719531664678338338121143689549850528456971885232802932902162",
		"15817781432103820015704945553128688539437475919918982282164580563407301207430",
	};
	Fp12 z;

	for (int i = 0; i < 12; i++) {
		z.get()[i] = Fp(x_ok[i]);
	}

	Fp12 x;

	for (int i = 0; i < 12; i++) {
		x.get()[i] = i + 3;
	}

	{
		x.final_exp();
		const mie::Vsint& zi = bn::Param::z;
		mie::Vsint d_prime = (2 * zi) * (6 * zi * zi + 3 * zi + 1);
		mie::Vuint d_abs;
		mie::Vsint::absolute(d_abs, d_prime);
		z = mie::power(z, d_abs);

		if (d_prime.isNegative()) {
			z.inverse();
		}

#if 0// QQQ old_exp
		for (size_t i = 0; i < 12; i++) {
			TEST_EQUAL(x.get()[i], z.get()[i]);
		}
#endif
	}

	{
		Fp12 xt = mie::power(x, Param::r);
		TEST_EQUAL(xt, Fp12(1));
		Fp12 zt = mie::power(z, Param::r);
		TEST_EQUAL(zt, Fp12(1));
	}
	CYBOZU_BENCH("final_exp", x.final_exp);
}

void test_pointDblLineEval(bool allBench)
{
	puts(__FUNCTION__);
	Fp2 Q[] = { genQx(), genQy(), Fp2(Fp(1), Fp(0)) };
	TEST_ASSERT(isOnTwistECHom3(Q));
	Fp P[3] = { genPx(), genPy(), Fp(1) };
	TEST_ASSERT(isOnECHom3(P));
	Fp::neg(P[2], P[1]); // @note: For the assumption of pointDblLineEval
	const Fp2 Q2_ok[] = { genQ2x(), genQ2y(), Fp2(Fp(1), Fp(0)) };
	TEST_ASSERT(isOnTwistECHom3(Q2_ok));
	const Fp2 l00_ok(
		Fp("1218653166067285584538203738497237160646510048316462546675922230477971988366"),
		Fp("13444680966039708564821554178786623445404802733727517756140842427775282241991"));
	const Fp2 l02_ok(
		Fp("14669021325553969631665050171167465779242435633491920423094037145439504174348"),
		Fp("771665946433473991711581179554051515057882422398978711857886722975787742693"));
	const Fp2 l11_ok(
		Fp("5083654211557558794221004641727153878275981283694826539168100383303202382274"),
		Fp("6366225659089551329035322836142125548492356702076290974152251785589487583351"));
	Fp2 Q2[] = { Q[0], Q[1], Q[2], };
	Fp6 l;
	Fp2& l00 = l.a_;
	Fp2& l02 = l.c_;
	Fp2& l11 = l.b_;
	Fp6::pointDblLineEval(l, Q2, P);
	TEST_ASSERT(isOnTwistECHom3(Q2));
	NormalizeHom(Q2, Q2);
	TEST_ASSERT(isOnTwistECHom3(Q2));
	TEST_EQUAL(Q2[0], Q2_ok[0]);
	TEST_EQUAL(Q2[1], Q2_ok[1]);
	TEST_EQUAL(Q2[2], Q2_ok[2]);
	TEST_EQUAL(l00, l00_ok);
	TEST_EQUAL(l02, l02_ok);
	TEST_EQUAL(l11, l11_ok);
	if (allBench) CYBOZU_BENCH("pointDblLineEval", Fp6::pointDblLineEval, l, Q2, P);
}

void test_pointAddLineEval(bool allBench)
{
	puts(__FUNCTION__);
	Fp2 Q[] = { genQx(), genQy(), Fp2(Fp(1), Fp(0)) };
	TEST_ASSERT(isOnTwistECHom3(Q));
	const Fp P[] = { genPx(), genPy(), Fp(1) };
	TEST_ASSERT(isOnECHom3(P));
	/*
		R = [m]Q
		where m = 8983814277390549953271767160356356855324831094607072139965475719941358715055
	*/
	const Fp2 R[] = {
		Fp2(Fp("538403429049656139897565072692893539987872088302878297862474357627057534036"),
			Fp("9360831036830943010552886973925002873262696706980698595440552561606683082311")),
		Fp2(Fp("4602226271967538444445722209125398887820203020623789000433097490686198967692"),
			Fp("10027082368454222153717339435200994429592852929609246856551738735310444995281")),
		Fp2(Fp(1), Fp(0)),
	};
	TEST_ASSERT(isOnTwistECHom3(R));
	/*
		RQ = R + Q
	*/
	const Fp2 RQ_ok[] = {
		Fp2(Fp("14462635707798746157040779719592332683099281599171708385749388482446745043127"),
			Fp("5086071869627888235657453291665320777682769673183769388625923076659929904768")),
		Fp2(Fp("16071875127812105172451027231039463141848166104557696531987123967356838839389"),
			Fp("15279844061281116178616101791776992126994407482416317579299271742300496066177")),
		Fp2(Fp(1), Fp(0)),
	};
	TEST_ASSERT(isOnTwistECHom3(RQ_ok));
	const Fp2 l00_ok(Fp("10013952835140506910916067999531081753178250370402232448154990388205483309972"),
		Fp("4926609310552091279051699015655777273195016616696233579052261219295065454280"));
	const Fp2 l02_ok(Fp("9649996602326804522644231063703979927150591558884646473664259298382380662378"),
		Fp("13648226627125837280213504610543602176703831560553537083503603809375238781189"));
	const Fp2 l11_ok(Fp("10422676207793898611344309297861346302460414709615008088696917811505787281979"),
		Fp("7036010756497237943264447921878652888644981129674790435334341908753079422899"));
	Fp2 RQ[] = { R[0], R[1], R[2], };
	Fp6 l;
	Fp2& l00 = l.a_;
	Fp2& l02 = l.c_;
	Fp2& l11 = l.b_;
	Fp6::pointAddLineEval(l, RQ, Q, P);
	TEST_ASSERT(isOnTwistECHom3(RQ));
	NormalizeHom(RQ, RQ);
	TEST_ASSERT(isOnTwistECHom3(RQ));
	TEST_EQUAL(RQ[0], RQ_ok[0]);
	TEST_EQUAL(RQ[1], RQ_ok[1]);
	TEST_EQUAL(RQ[2], RQ_ok[2]);
	TEST_EQUAL(l00, l00_ok);
	TEST_EQUAL(l02, l02_ok);
	TEST_EQUAL(l11, l11_ok);
	if (allBench) CYBOZU_BENCH("pointAddLineEval", Fp6::pointAddLineEval, l, RQ, Q, P);
}

void test_compression(bool allBench)
{
	puts(__FUNCTION__);
	Fp12 a;

	for (int i = 0; i < 12; ++i) {
		a.get()[i] = i;
	}

	Fp12 aa;
	a.mapToCyclo(aa);
	a = aa;
	Fp12 c;
	Compress b(c, a);
	TEST_EQUAL(intptr_t(&b.z_), intptr_t(&c));
	TEST_EQUAL(b.z_, c);
	TEST_EQUAL(b.g1_, c.getFp2()[4]);
	TEST_EQUAL(b.g2_, c.getFp2()[3]);
	TEST_EQUAL(b.g3_, c.getFp2()[2]);
	TEST_EQUAL(b.g4_, c.getFp2()[1]);
	TEST_EQUAL(b.g5_, c.getFp2()[5]);
	if (allBench) {
		CYBOZU_BENCH_C("decompress", 10000, b.decompress);
		TEST_EQUAL(a, c);
	}
}

void test_compressed_square(bool allBench)
{
	puts(__FUNCTION__);
	Fp12 a;

	for (int i = 0; i < 12; ++i) {
		a.get()[i] = i;
	}

	Fp12 aa;
	a.mapToCyclo(aa);
	a = aa;
	Fp12 d;
	Compress b(d, a);
	a *= a;
	Fp12 d2;
	Compress c(d2, b);
	Compress::square_n(c, 1);
	c.decompress();
	TEST_EQUAL(a, d2);
	Compress::square_n(b, 1);
	b.decompress();
	TEST_EQUAL(a, d);
	if (allBench) CYBOZU_BENCH("Compress::square", Fp12::square, a);
}

void test_compressed_fixed_power(bool allBench)
{
	puts(__FUNCTION__);
	Fp12 a;

	for (int i = 0; i < 12; ++i) {
		a.get()[i] = i;
	}

	Fp12 aa;
	a.mapToCyclo(aa);
	a = aa;
	Fp12 b;
	Compress::fixed_power(b, a);
	Fp12 c = mie::power(a, Param::z.get());
	TEST_EQUAL(b, c);
	if (allBench) CYBOZU_BENCH("Compress::fixed_power", Compress::fixed_power, b, a);
}

void test_sqru(bool allBench)
{
	puts(__FUNCTION__);
	{
		Fp12 a;

		for (int i = 0; i < 12; ++i) {
			a.get()[i] = i;
		}
		Fp12 aa;
		a.mapToCyclo(aa);
		a = aa;
		Fp12 b, c = a;
		b = a;
		b.sqru();
		Fp12::square(c);
		TEST_EQUAL(b, c);
		if (allBench) {
			CYBOZU_BENCH("Fp12::sqru  ", a.sqru);
			CYBOZU_BENCH("Fp12::square", Fp12::square, a);
			CYBOZU_BENCH("Fp12::mul   ", Fp12::mul, a, a, b);
		}
	}
}

void test_FrobEndOnTwist_1(bool allBench)
{
	puts(__FUNCTION__);
	Fp2 Q[] = { genQx(), genQy() };
	TEST_ASSERT(isOnTwistECHom2(Q));
	const Fp2 Qp[] = {
		Fp2(Fp("2056759109515975861665426147192151608007308721500683629663464772885511939168"),
			Fp("10296094419291805247741898368672988774667071764149880389566192920518825046253")),
		Fp2(Fp("15318789889948026269195465641311637076887470214980886516517795245676250468201"),
			Fp("16086843419903922136591069704206201345656058171834106763866049911942744484945")),
	};
	TEST_ASSERT(isOnTwistECHom2(Qp));
	FrobEndOnTwist_1(Q, Q);
	TEST_EQUAL(Q[0], Qp[0]);
	TEST_EQUAL(Q[1], Qp[1]);

	for (size_t i = 1; i < 12; ++i) {
		FrobEndOnTwist_1(Q, Q);
	}

	{
		Fp2 Q1[] = { genQx(), genQy() };
		TEST_EQUAL(Q[0], Q1[0]);
		TEST_EQUAL(Q[1], Q1[1]);
	}

	if (allBench) CYBOZU_BENCH("FrobEndTwist_1", FrobEndOnTwist_1<Fp>, Q, Q);
}

void test_FrobEndOnTwist_2(bool allBench)
{
	puts(__FUNCTION__);
	Fp2 Q[] = { genQx(), genQy() };
	TEST_ASSERT(isOnTwistECHom2(Q));
	const Fp2 Qp2_ok[] = {
		Fp2(Fp("10065458361706171050734313676266120070744817595308631072199963185069217686139"),
			Fp("3393658127113032111918147843333039169870532385628727893932735697426808572356")),
		Fp2(Fp("7370884157884891579172966401254345058493688321372957611668488286195364565842"),
			Fp("8345967414506607633587114472874805346889011972272589375097032499111066411209")),
	};
	TEST_ASSERT(isOnTwistECHom2(Qp2_ok));
	FrobEndOnTwist_2(Q, Q);
	TEST_EQUAL(Q[0], Qp2_ok[0]);
	TEST_EQUAL(Q[1], Qp2_ok[1]);

	for (size_t i = 1; i < 6; ++i) {
		FrobEndOnTwist_2(Q, Q);
	}

	{
		Fp2 Q1[] = { genQx(), genQy() };
		TEST_EQUAL(Q[0], Q1[0]);
		TEST_EQUAL(Q[1], Q1[1]);
	}
	if (allBench) CYBOZU_BENCH("FrobEndTwist_2", FrobEndOnTwist_2<Fp>, Q, Q);
}

void testPairing()
{
	puts(__FUNCTION__);
	const Fp P[] = { genPx(), genPy() };
	TEST_ASSERT(isOnECHom2(P));
	const Fp P2[] = { genP2x(), genP2y() };
	TEST_ASSERT(isOnECHom2(P2));
	const Fp2 Q[] = { genQx(), genQy() };
	TEST_ASSERT(isOnTwistECHom2(Q));
	const Fp2 Q2[] = { genQ2x(), genQ2y() };
	TEST_ASSERT(isOnTwistECHom2(Q2));
	Fp12 e, e21, e22;
	opt_atePairing<Fp>(e, Q, P);
	opt_atePairing<Fp>(e21, Q, P2);
	opt_atePairing<Fp>(e22, Q2, P);
	TEST_EQUAL(e * e, e21);
	TEST_EQUAL(e * e, e22);
	for (int j = 0; j < 4; j++) {
		double begin = GetCurrTime();
		Xbyak::util::Clock clk;
		const int N = 10000;
		clk.begin();

		for (int i = 0; i < N; i++) {
			opt_atePairing<Fp>(e, Q, P);
		}

		clk.end();
		double end = GetCurrTime();
		printf("opt_ate:%.2fclk(N=%d) ", clk.getClock() / double(N), N);
		printf("%.3fmsec\n", (end - begin) * 1e3 / N);
	}
}

void testFp()
{
	puts(__FUNCTION__);
	Fp x, y;
	TEST_EQUAL(sizeof(Fp), Fp::N * sizeof(mie::Unit));
	TEST_EQUAL((void*)&x, (void*)&x[0]);
	x = 123;
	y = 456;
	x += y;
	TEST_EQUAL(x, Fp("579"));
	x = 0x123;
	y = 0x456;
	x *= y;
	TEST_EQUAL(x, Fp("0x4EDC2"));
	x.set("123");
	y.set("456");
	x += y;
	TEST_EQUAL(x, Fp("579"));
	x -= Fp("580");
	TEST_EQUAL(x, Fp(Fp::getModulo() - 1));
	x.set("13235535167791909954945079826683319167288269422503395778717464766711290103089");
	y.set("12009422934659625156361067360716584218353200927749721008493193292779219981220");
	x *= x;
	TEST_EQUAL(x, y);
	{
		Fp x, y;
		mie::ZmZ<mie::Vuint, Fp> z, w;
		x.set("3");
		z.set("3");

		for (int i = 0; i < 100000; i++) {
			y = x;
			w = z;
			x *= x;
			z *= z;
			x -= y;
			z -= w;

			if (x.toString() != z.toString()) {
				printf("err %d\n", i);
				std::cout << "x=" << y << std::endl;
				std::cout << "1=" << x << std::endl;
				std::cout << "2=" << z << std::endl;
				exit(1);
			}
		}
	}
	x = 3;
	y = power(x, Fp::getModulo() - 1);
	TEST_EQUAL(y, 1);
	y = x;
	y.inverse();
	x *= y;
	TEST_EQUAL(x, 1);
}

void testFp_add_sub()
{
	puts(__FUNCTION__);
	Fp x, y, z;
	const struct {
		const char* x;
		const char* y;
		const char* z;
	} tbl[] = {
		{ "0", "0", "0" },
		{ "12345", "6789", "19134" },
		{ "0x2523648240000001ba344d80000000086121000000000013a700000000000012", "1", "0" },
		{ "0x2523648240000001ba344d80000000086121000000000013a700000000000012", "2", "1" },
		{ "0x2523648240000001ba344d80000000086121000000000013a700000000000012", "0x2000000000000000000000000000000000000000000000000000000000000000", "0x1fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" },
		{ "0x2523648240000001ba344d80000000086121000000000013a700000000000012", "0x2523648240000001ba344d80000000086121000000000013a700000000000012", "0x2523648240000001ba344d80000000086121000000000013a700000000000011" },
	};

	for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
		x.set(tbl[i].x);
		y.set(tbl[i].y);
		z.set(tbl[i].z);
		TEST_EQUAL(x + y, z);
		TEST_EQUAL(z - x, y);
		TEST_EQUAL(z - y, x);
	}
}

struct MontgomeryTest {};

void montgomery(mie::Vuint& z, const mie::Vuint& x, const mie::Vuint& y)
{
	mie::Vuint c = 0;
	const mie::Vuint p = Fp::getModulo();
	const size_t UnitLen = sizeof(mie::Unit) * 8;
	static mie::Unit pp;
	static bool isFirst = true;

	if (isFirst) {
		typedef mie::ZmZ<mie::Vuint, MontgomeryTest> ZN;
		ZN::setModulo(mie::Vuint(1) << UnitLen);
		ZN t(p);
		t = -t;
		t.inverse();
		pp = t[0];
		isFirst = false;
	}

#if 1
	c = x * y;
	const size_t n = 256 / UnitLen;

	for (size_t i = 0; i < n; i++) {
		mie::Unit u = c[0];
		mie::Unit q = u * pp;
		c += q * p;
		c >>= UnitLen;
	}

#else
	const size_t n = 256 / UnitLen;

	for (size_t i = 0; i < n; i++) {
		Unit t = y.size() > i ? y[i] : 0;
		c += x * t;
		Unit u = c[0];
		Unit q = u * pp;
		c += q * p;
		c >>= UnitLen;
	}

#endif

	if (c >= p) {
		c -= p;
	}

	z = c;
}

void testDbl()
{
	puts(__FUNCTION__);
	FpDbl dummy;
	TEST_EQUAL(sizeof(dummy), FpDbl::SIZE);
	TEST_EQUAL(uintptr_t(&dummy), uintptr_t(&dummy[0]));
	{
		Fp x, y;
		mie::Vuint t;
		t = p - 1;
		Fp::setDirect(x, t);
		t = p - 2;
		Fp::setDirect(y, t);
		FpDbl zd;
		FpDbl::mul(zd, x, y);
		t = (p - 1) * (p - 2);
		mie::Vuint tzd = zd.getDirect();
		TEST_EQUAL(t, tzd);
		Fp z, zmod;
		z = x * y;
		FpDbl::mod(zmod, zd);
		TEST_EQUAL(z, zmod);
	}
	{
		const struct {
			const char* a;
			const char* b;
		} tbl[] = {
			{
				"0x10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001",
				"0x000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001",
			},
			{
				"0x2370fb049d410fbe4e761a9886e502417d023f40180000017e805370fb049d410fbe4e761a9886e50241370fb049d410fbe4e761a9886e502410000000003334",
				"0x2370fb049d410fbe4e761a9886e502417d01a9886e502417d023f40180000017e805370fb049d410fbe4e761a9886e50241370fb049d410fbe4e761a9886e502",
			},
			{
				"0x70fb049d410fbe4e761a9886e502417d023f40180000017e805370fb049d410fbe4e761a9886e50241370fb049d410fbe4e761a9886e502410000000003334",
				"0x70fb049d410fbe4e761a9886e502417d01a9886e502417d023f40180000017e805370fb049d410fbe4e761a9886e50241370fb049d410fbe4e761a9886e502",
			},
		};
		mie::Vuint pm = Fp::getModulo() * (mie::Vuint(1) << 256);

		for (size_t i = 0; i < NUM_OF_ARRAY(tbl); i++) {
			mie::Vuint x(tbl[i].a), y(tbl[i].b);
			FpDbl s, t;
			s.setDirect(x);
			t.setDirect(y);
			x = (x + y) % pm;
			s += t;
			y.set(s.const_ptr(), Fp::N * 2);
			TEST_EQUAL(x, y);
		}
	}
}

void testDbl_add_sub()
{
	puts(__FUNCTION__);
	const char* as = "0x826db9eced02a46cccc83dd73d7ee9a1ac44da788daff6d90f91e0a49dfcd5e";
	const char* ads = "0x10e6616f9d658d62913a152516a1930d3b95eb1c4f69dd334c286bf2e322e34fab44d283e8ef4e6491c7fef40ca63362182fb3be3aad38785109f6b1a568c24";
	const char* bs = "0xbb4674a8b1fc189e5402353d6d991585e9a93a1fccb6bb48991033aa064661f";
	const char* bds = "0x18440289e040f84f0f8bb27b1f5607ad646bfeccbd737684bfdfeae964fd3bb4c5bb9f032044cb265788331de43a90e842b3b1e88eb9817676c8fe4934a8632";
	const Fp one(1);
	mie::Vuint ai(as), bi(bs);
	Fp a, b;
	Fp::setDirect(a, ai);
	Fp::setDirect(b, bi);
	const FpDbl ad(ads);
	const FpDbl bd(bds);
	{
		Fp t;
		FpDbl::mod(t, ad);
		TEST_EQUAL(t, a);
		FpDbl::mod(t, bd);
		TEST_EQUAL(t, b);
	}
	{
		const char* cs = "0x13db42e959efebd0b20ca7314ab17ff2795ee14985a66b221a8a2144ea44337d";
		const char* cds = "0x292a63f97da685b1a0c5c7a035f79abaa001e9e90cdd53b80c0856dc48201f04710071870934198ae9503211f0e0c44a5ae365a6c966b9eec7d2f4fada11256";
		FpDbl ad(ads);
		const FpDbl bd(bds);
		const FpDbl cd(cds);
		mie::Vuint ci(cs);
		Fp c, ct;
		Fp::setDirect(c, ci);
		FpDbl::mod(ct, cd);
		TEST_EQUAL(c, ct);
		FpDbl::add(ad, ad, bd);
		TEST_EQUAL(ad, cd);
	}
	{
		const char* a2s = "0x104db73d9da0548d999907bae7afdd3435889b4f11b5fedb21f23c1493bf9abc";
		const char* a2ds = "0x21ccc2df3acb1ac522742a4a2d43261a772bd6389ed3ba669850d7e5c645c69f5689a507d1de9cc9238ffde8194c66c4305f677c755a70f0a213ed634ad1848";
		FpDbl ad(ads);
		const FpDbl a2d(a2ds);
		mie::Vuint a2i(a2s);
		Fp a2, a2t;
		Fp::setDirect(a2, a2i);
		FpDbl::mod(a2t, a2d);
		TEST_EQUAL(a2, a2t);
		FpDbl::add(ad, ad, ad);
		TEST_EQUAL(ad, a2d);
	}
	{
		FpDbl ad, bd;
		const Fp c = a + b;
		Fp ct;
		FpDbl::mul(ad, a, one);
		FpDbl::mul(bd, b, one);
		FpDbl::add(ad, ad, bd);
		FpDbl::mod(ct, ad);
		TEST_EQUAL(ct, c);
	}
	{
		FpDbl ad;
		const Fp c = a + a;
		Fp ct;
		FpDbl::mul(ad, a, one);
		FpDbl::add(ad, ad, ad);
		FpDbl::mod(ct, ad);
		TEST_EQUAL(ct, c);
	}
	{
		const char* cds = "0x2414fe6b4629a72b9120ac2dae95e6d78d67a14e3b096240723d7940d1cdd1de054bb2d7c1710b19b6e38010bf359cc9de7d04c41c552c787aef6094e5a973dc";
		FpDbl ad(ads);
		const FpDbl cd(cds);
		FpDbl::neg(ad, ad);
		TEST_EQUAL(ad, cd);
	}
	{
		FpDbl ad;
		const Fp c = -a;
		Fp ct;
		FpDbl::mul(ad, a, one);
		FpDbl::neg(ad, ad);
		FpDbl::mod(ct, ad);
		TEST_EQUAL(ct, c);
	}
	{
		FpDbl ad, bd;
		const Fp c = a - b;
		Fp ct;
		FpDbl::mul(ad, a, one);
		FpDbl::mul(bd, b, one);
		FpDbl::sub(ad, ad, bd);
		FpDbl::mod(ct, ad);
		TEST_EQUAL(ct, c);
	}
}

void testFpDbl_mul_mod()
{
	puts(__FUNCTION__);
	const char* as = "121311891827543957596909773033357421921766710831251548159956972926334483720";
	const char* bs = "4250864531853689066995024032521947485438864668614304877798137152237875276659";
	const char* cs = "6130604890643875446660330430071165035373943332034046310134586930404838747383";
	const char* cds = "515680418261778013941729031428717927558491170998041032206579966438977948938767928415397290640890254719024071470552752738210640396059153581666931491480";
	{
		mie::Vuint ai(as), bi(bs), ci(cs);
		Fp x, y, z, zt;
		Fp::setDirect(x, ai);
		Fp::setDirect(y, bi);
		Fp::setDirect(z, ci);
		zt = x * y;
		FpDbl w, zd(cds);
		FpDbl::mul(w, x, y);
		TEST_EQUAL(w, zd);
		Fp s;
		FpDbl::mod(s, w);
		TEST_EQUAL(z, s);
		TEST_EQUAL(zt, s);
	}
}

void testFp2Dbl()
{
	puts(__FUNCTION__);
	Fp2Dbl dummy;
	TEST_EQUAL(sizeof(dummy), Fp2Dbl::SIZE);
	TEST_EQUAL(uintptr_t(&dummy), uintptr_t(&dummy.a_));
	const Fp2 a(
		Fp("11670776793662220163659381041821071042189526350599853354176183114948400476854"),
		Fp("16720058771622958239847090974706681762823587016948988460920422070188238301920"));
	const Fp2Dbl ad(
		"43365626183362451296144273927903491721178106337019849480533874426567558421999199112585229298328261724838400974530624189976754698034274243846379138263798",
		"146841205705169330240495767599698200797060877501089277217144673667296710106404940569619328012833781922979497600339156163032435697636816808188620084421142");
	{
		Fp2 at;
		Fp2Dbl::mod(at, ad);
		TEST_EQUAL(at, a);
	}
	{
		const Fp2 a(Fp("0"), Fp("1"));
		const Fp2 b(Fp("0"), Fp("1"));
		Fp2 c, ct;
		Fp2Dbl cd;
		c = a * b;
		Fp2Dbl::mulOpt2(cd, a, b);
		Fp2Dbl::mod(ct, cd);
		TEST_EQUAL(c, ct);
	}
	{
		const Fp2 b(Fp("123"), Fp("456"));
		Fp2 c, ct;
		Fp2Dbl cd;
		c = a * b;
		Fp2Dbl::mulOpt2(cd, a, b);
		Fp2Dbl::mod(ct, cd);
		TEST_EQUAL(c, ct);
	}
}

void testFp2Dbl_add_sub(bool allBench)
{
	puts(__FUNCTION__);
	const Fp2 one(Fp("1"), Fp("0"));
	const Fp2 a(
		Fp("0x19cd6cf2a9dc668d011b54f13a92591457dcdd5b946cf92af95ca820077972b6"),
		Fp("0x24f737c85b07fa5103d2dfa5a44d0a9c2ee6138de25c709cdd2f526dab19eae0"));
	const Fp2Dbl ad(
		"0xd3f77def5c0d18d7f1449afb9c117dfeb51c1fe1208d056ad21c679c5ec71c4642b58a8c4f44ce7ed74f49cf92ae8428d5741cc65ee00bf090ec506c952af6",
		"0x2cdbeaf4c89f0e69e52a72dddfc13f8ca9ee571933484140d9e3c395bf9056b44719b54117e71bb62f41ed10ccec31240535f52ea74b4829c2a5fded0e52216");
	const Fp2 b(
		Fp("0x26dbd9018fa1dc1a7b555a80895ba00a4fbfb7ba8bcf7d3deb53452d65180c0"),
		Fp("0x20618bd9d595b08223a03e66294e8a4a10e688a696c0af9daca0faa041d884a7"));
	const Fp2Dbl bd(
		"0x2dfa943203451554f15ba5a92717a16a0f9a97dbec7d0dae70dc2ea57ff90d04e8c9f1ebfa99415ad41e9ac35c33b297b9fb4da61ff1b550dfc28c584e912d8",
		"0x23f0eb05bb2bc09bd2f9b1a71d6e2b94b28a4d1b6321dcfd44e8e72c1d7a992ad361a7b73aaf1cf5feca656ac0bddf20f549594ae1e65e9e567839d4f482176");
	{
		Fp2 at;
		Fp2Dbl::mod(at, ad);
		TEST_EQUAL(at, a);
		Fp2 bt;
		Fp2Dbl::mod(bt, bd);
		TEST_EQUAL(bt, b);
	}
	{
		mie::Vuint t0, t1;
		Fp2Dbl ad, bd, cd;
		t0 = 1; t1 = 2;
		ad.setDirect(t0, t1);
		t0 = 3; t1 = 4;
		bd.setDirect(t0, t1);
		t0 = 4; t1 = 6;
		cd.setDirect(t0, t1);
		Fp2Dbl td;
		Fp2Dbl::add(td, ad, bd);
		TEST_EQUAL(td, cd);
	}
	{
		const Fp2 c = a + b;
		const Fp2 cc(
			Fp("12769297135811847170252627178279277434270214741555565448692771341243685466998"),
			Fp("14568310576098881131032985368780468502614655635084870456076855826537822449524"));
		TEST_EQUAL(c, cc);
		Fp2 ct;
		Fp2Dbl adt(ad);
		Fp2Dbl::add(adt, adt, bd);
		Fp2Dbl::mod(ct, adt);
		TEST_EQUAL(ct, c);
		TEST_EQUAL(ct, cc);
	}
	{
		const Fp2 c = a - b;
		Fp2 ct;
		Fp2Dbl adt(ad);
		Fp2Dbl::sub(adt, adt, bd);
		Fp2Dbl::mod(ct, adt);
		TEST_EQUAL(ct, c);
	}
	{
		const Fp2 a(Fp("1"), Fp("0"));
		Fp2 c; Fp2::mul_xi(c, a);
		Fp2 ct;
		Fp2Dbl ad, cd;
		Fp2Dbl::mulOpt2(ad, a, one);
		Fp2Dbl::mul_xi(cd, ad);
		Fp2Dbl::mod(ct, cd);
		TEST_EQUAL(ct, c);
	}
	{
		Fp2 c; Fp2::mul_xi(c, a);
		Fp2 ct;
		Fp2Dbl ad, cd;
		Fp2Dbl::mulOpt2(ad, a, one);
		Fp2Dbl::mul_xi(cd, ad);
		Fp2Dbl::mod(ct, cd);
		TEST_EQUAL(ct, c);
	}
	if (allBench) {
		Fp2Dbl cd;
		CYBOZU_BENCH("Fp2Dbl::add    ", Fp2Dbl::add, cd, ad, bd);
		CYBOZU_BENCH("Fp2Dbl::sub    ", Fp2Dbl::sub, cd, ad, bd);
		CYBOZU_BENCH("Fp2Dbl::addNC  ", Fp2Dbl::addNC, cd, ad, bd);
		CYBOZU_BENCH("Fp2Dbl::subNC  ", Fp2Dbl::subNC, cd, ad, bd);
		CYBOZU_BENCH("Fp2Dbl::neg    ", Fp2Dbl::neg, cd, ad);
		CYBOZU_BENCH("Fp2Dbl::mul_xi ", Fp2Dbl::mul_xi, cd, ad);
		CYBOZU_BENCH("Fp2Dbl::mulOpt1", Fp2Dbl::mulOpt1, cd, a, b);
		CYBOZU_BENCH("Fp2Dbl::mulOpt2", Fp2Dbl::mulOpt2, cd, a, b);
		CYBOZU_BENCH("Fp2Dbl::square ", Fp2Dbl::square, cd, a);
		Fp2 c;
		CYBOZU_BENCH("Fp2Dbl::mod    ", Fp2Dbl::mod, c, ad);
	}
}

void testFp2Dbl_mul_mod()
{
	puts(__FUNCTION__);
	const Fp2 a(
		Fp("0x19cd6cf2a9dc668d011b54f13a92591457dcdd5b946cf92af95ca820077972b6"),
		Fp("0x24f737c85b07fa5103d2dfa5a44d0a9c2ee6138de25c709cdd2f526dab19eae0"));
	const Fp2Dbl ad(
		"0xd3f77def5c0d18d7f1449afb9c117dfeb51c1fe1208d056ad21c679c5ec71c4642b58a8c4f44ce7ed74f49cf92ae8428d5741cc65ee00bf090ec506c952af6",
		"0x2cdbeaf4c89f0e69e52a72dddfc13f8ca9ee571933484140d9e3c395bf9056b44719b54117e71bb62f41ed10ccec31240535f52ea74b4829c2a5fded0e52216");
	const Fp2 b(
		Fp("0x26dbd9018fa1dc1a7b555a80895ba00a4fbfb7ba8bcf7d3deb53452d65180c0"),
		Fp("0x20618bd9d595b08223a03e66294e8a4a10e688a696c0af9daca0faa041d884a7"));
	const Fp2Dbl bd(
		"0x2dfa943203451554f15ba5a92717a16a0f9a97dbec7d0dae70dc2ea57ff90d04e8c9f1ebfa99415ad41e9ac35c33b297b9fb4da61ff1b550dfc28c584e912d8",
		"0x23f0eb05bb2bc09bd2f9b1a71d6e2b94b28a4d1b6321dcfd44e8e72c1d7a992ad361a7b73aaf1cf5feca656ac0bddf20f549594ae1e65e9e567839d4f482176");
	{
		Fp2 at;
		Fp2Dbl::mod(at, ad);
		TEST_EQUAL(at, a);
		Fp2 bt;
		Fp2Dbl::mod(bt, bd);
		TEST_EQUAL(bt, b);
	}
	{
		const Fp2 c = a * b;
		Fp2Dbl cd;
		Fp2Dbl::mulOpt2(cd, a, b);
		Fp2 ct;
		Fp2Dbl::mod(ct, cd);
		TEST_EQUAL(ct, c);
	}
	{
		const Fp2 c = a * a;
		Fp2Dbl cd;
		Fp2Dbl::square(cd, a);
		Fp2 ct;
		Fp2Dbl::mod(ct, cd);
		TEST_EQUAL(ct, c);
	}
}

void testParameters()
{
	puts(__FUNCTION__);
	{
		const mie::Vuint p_ok("16798108731015832284940804142231733909889187121439069848933715426072753864723");
		const mie::Vuint& p = Fp::getModulo();
		const mie::Vuint& param_p = Param::p;
		TEST_EQUAL(p, p_ok);
		TEST_EQUAL(param_p, p_ok);
	}
	{
		const mie::Vuint r_ok("16798108731015832284940804142231733909759579603404752749028378864165570215949");
		const mie::Vuint& r = Param::r;
		TEST_EQUAL(r, r_ok);
	}
	{
		const Fp Z_ok("1807136345283977465813277102364620289631804529403213381639");
		Fp t = Z_ok * Z_ok + Z_ok + 1;
		TEST_ASSERT(t.isZero());
		t = Z_ok * Z_ok * Z_ok;
		TEST_EQUAL(t, 1);
		const Fp& Z = Param::Z;
		t = Z * Z + Z + 1;
		TEST_ASSERT(t.isZero());
		t = Z * Z * Z;
		TEST_EQUAL(t, 1);
		TEST_EQUAL(Z, Z_ok);
	}
	{
		const Fp2 W2p_ok(
			Fp(0),
			Fp("16798108731015832283133667796947756444075910019074449559301910896669540483083"));
		const Fp2& W2p = Param::W2p;
		TEST_EQUAL(W2p, W2p_ok);
	}
	{
		const Fp2 W3p_ok(
			Fp("16226349498735898878582721725794281106152147739300925444201528929117996286405"),
			Fp("16226349498735898878582721725794281106152147739300925444201528929117996286405"));
		const Fp2& W3p = Param::W3p;
		TEST_EQUAL(W3p, W3p_ok);
	}
	struct Fp2_str {
		const char* a;
		const char* b;
	};
	{
#ifdef BN_SUPPORT_SNARK
		const Fp2 (&gammar)[6] = Param::gammar;
#else
		const Fp2 (&gammar)[5] = Param::gammar;
#endif
		const Fp2_str gammar_str[] = {
			{
				"12310438583873020660552735091161044116898065562217439662059245424880585960937",
				"4487670147142811624388069051070689792991121559221630186874470001192167903786"
			},
			{
				"0",
				"16798108731015832283133667796947756444075910019074449559301910896669540483083"
			},
			{
				"16226349498735898878582721725794281106152147739300925444201528929117996286405",
				"16226349498735898878582721725794281106152147739300925444201528929117996286405"
			},
			{
				"16798108731015832283133667796947756444075910019074449559301910896669540483084",
				"0"
			},
			{
				"11738679351593087254194652674723591313161026180079295257327058927925828382619",
				"5059429379422745030746151467508142596728160941359774591606656498146925482104"
			},
		};
		Fp2 gammar_ok[5];

		for (size_t i = 0; i < sizeof(gammar_ok) / sizeof(*gammar_ok); ++i) {
			gammar_ok[i].get()[0].set(gammar_str[i].a);
			gammar_ok[i].get()[1].set(gammar_str[i].b);

			if (gammar[i] != gammar_ok[i]) {
				PUT(i);
				TEST_EQUAL(gammar[i], gammar_ok[i]);
			}
		}
	}
	{
		const Fp2 (&gammar2)[5] = Param::gammar2;
		const Fp2_str gammar2_str[] = {
			{
				"1807136345283977465813277102364620289631804529403213381640", "0"
			},
			{
				"1807136345283977465813277102364620289631804529403213381639", "0"
			},
			{
				"16798108731015832284940804142231733909889187121439069848933715426072753864722", "0"
			},
			{
				"16798108731015832283133667796947756444075910019074449559301910896669540483083", "0"
			},
			{
				"16798108731015832283133667796947756444075910019074449559301910896669540483084", "0"
			},
		};
		Fp2 gammar2_ok[5];

		for (size_t i = 0; i < sizeof(gammar2_ok) / sizeof(*gammar2_ok); ++i) {
			gammar2_ok[i].get()[0].set(gammar2_str[i].a);
			gammar2_ok[i].get()[1].set(gammar2_str[i].b);

			if (gammar2[i] != gammar2_ok[i]) {
				PUT(i);
				TEST_EQUAL(gammar2[i], gammar2_ok[i]);
			}
		}
	}
	{
		const Fp2 (&gammar3)[5] = Param::gammar3;
		const Fp2_str gammar3_str[] = {
			{
				"571759232279933406358082416437452803737039382138144404732186496954757578318",
				"16226349498735898878582721725794281106152147739300925444201528929117996286405"
			},
			{ "0", "1" },
			{
				"571759232279933406358082416437452803737039382138144404732186496954757578318",
				"571759232279933406358082416437452803737039382138144404732186496954757578318"
			},
			{
				"16798108731015832284940804142231733909889187121439069848933715426072753864722", "0"
			},
			{
				"16226349498735898878582721725794281106152147739300925444201528929117996286405",
				"571759232279933406358082416437452803737039382138144404732186496954757578318"
			},
		};
		Fp2 gammar3_ok[5];

		for (size_t i = 0; i < sizeof(gammar3_ok) / sizeof(*gammar3_ok); ++i) {
			gammar3_ok[i].get()[0].set(gammar3_str[i].a);
			gammar3_ok[i].get()[1].set(gammar3_str[i].b);

			if (gammar3[i] != gammar3_ok[i]) {
				PUT(i);
				TEST_EQUAL(gammar3[i], gammar3_ok[i]);
			}
		}
	}
}

void testPairingJac()
{
	Fp2 g2[3] = {
		Fp2(
			Fp("12723517038133731887338407189719511622662176727675373276651903807414909099441"),
			Fp("4168783608814932154536427934509895782246573715297911553964171371032945126671")
		),
		Fp2(
			Fp("13891744915211034074451795021214165905772212241412891944830863846330766296736"),
			Fp("7937318970632701341203597196594272556916396164729705624521405069090520231616")
		),
		Fp2(Fp("1"), Fp("0"))
	};
	Fp g1[3] = {
		Fp("1674578968009266105367653690721407808692458796109485353026408377634195183292"),
		Fp("8299158460239932124995104248858950945965255982743525836869552923398581964065"),
		Fp("1")
	};
	Fp12 e;
	// opt_atePairingJac sample
	{
		Fp Zero[3];
		Zero[2] = 0;
		opt_atePairingJac<Fp>(e, g2, Zero);
		printf(" e(g2, 0) = 1 : %s\n", e == 1 ? "ok" : "ng");
	}
	{
		Fp2 Zero[3];
		Zero[2] = 0;
		opt_atePairingJac<Fp>(e, Zero, g1);
		printf(" e(0, g1) = 1 : %s\n", e == 1 ? "ok" : "ng");
	}
	{
		opt_atePairingJac<Fp>(e, g2, g1);
		// make unnormalized Jacobi
		{
			const int z = 17;
			g2[0] *= z * z;
			g2[1] *= z * z * z;
			g2[2] *= z;
		}
		{
			const int z = 13;
			g1[0] *= z * z;
			g1[1] *= z * z * z;
			g1[2] *= z;
		}
		Fp12 e1;
		opt_atePairingJac<Fp>(e1, g2, g1);
		printf(" e(g2, g1) : %s\n", e1 == e ? "ok" : "ng");
	}
	CYBOZU_BENCH("Fp12::mul", Fp12::mul, e, e, e);
}

void benchFpDbl()
{
	const char* ads = "0x10e6616f9d658d62913a152516a1930d3b95eb1c4f69dd334c286bf2e322e34fab44d283e8ef4e6491c7fef40ca63362182fb3be3aad38785109f6b1a568c24";
	const char* bds = "0x18440289e040f84f0f8bb27b1f5607ad646bfeccbd737684bfdfeae964fd3bb4c5bb9f032044cb265788331de43a90e842b3b1e88eb9817676c8fe4934a8632";
	FpDbl ad(ads), bd(bds);
	CYBOZU_BENCH("FpDbl::add  ", FpDbl::add, ad, ad, bd);
	CYBOZU_BENCH("FpDbl::sub  ", FpDbl::sub, ad, ad, bd);
	CYBOZU_BENCH("FpDbl::addNC", FpDbl::addNC, ad, ad, bd);
	CYBOZU_BENCH("FpDbl::subNC", FpDbl::subNC, ad, ad, bd);
	CYBOZU_BENCH("FpDbl::neg  ", FpDbl::neg, ad, ad);
}

void benchFp6()
{
	Fp6 x, y;

	for (int i = 0; i < 6; i++) {
		x.get()[i] = i * i + 3;
	}
	CYBOZU_BENCH("Fp6::add    ", Fp6::add, x, x, y);
	CYBOZU_BENCH("Fp6::sub    ", Fp6::sub, x, x, y);
	CYBOZU_BENCH("Fp6::mul    ", Fp6::mul, x, x, y);
	CYBOZU_BENCH("Fp6::inverse", x.inverse);
}
void benchFp12()
{
	Fp12 x, y;

	for (int i = 0; i < 12; i++) {
		x.get()[i] = i * i + 3;
	}
	CYBOZU_BENCH("Fp12::add    ", Fp12::add, x, x, y);
	CYBOZU_BENCH("Fp12::sub    ", Fp12::sub, x, x, y);
	CYBOZU_BENCH("Fp12::mul    ", Fp12::mul, x, x, y);
	CYBOZU_BENCH("Fp12::inverse", x.inverse);
}
void benchEcFp()
{
	const Fp P[] = { genPx(), genPy(), Fp(1) };
	const mie::Vuint m("9347746330740818252600716999005395295745642941583534686803606077666502");
	Fp Q[3];
	ECDouble(Q, P);
	CYBOZU_BENCH("G1:ECDouble  ", ECDouble<Fp>, Q, Q);
	CYBOZU_BENCH("G1:ECAdd     ", ECAdd<Fp>, Q, P, Q);
	CYBOZU_BENCH("G1:ScalarMult", (ScalarMult<Fp, mie::Vuint>), Q, P, m);
}
void benchEcFp2()
{
	const Fp2 P[] = { genQx(), genQy(), Fp2(Fp(1), Fp(0)) };
	const mie::Vuint m("9347746330740818252600716999005395295745642941583534686803606077666502");
	Fp2 Q[3];
	ECDouble(Q, P);
	CYBOZU_BENCH("G2:ECDouble  ", ECDouble<Fp2>, Q, Q);
	CYBOZU_BENCH("G2:ECAdd     ", ECAdd<Fp2>, Q, P, Q);
	CYBOZU_BENCH("G2:ScalarMult", (ScalarMult<Fp2, mie::Vuint>), Q, P, m);
}
void benchFp6Dbl()
{
	Fp6Dbl x("999111", "999222", "999333", "999444", "999555", "999666");
	Fp6Dbl y("1999111", "9919222", "9199333", "9919444", "9919555", "9919666");
	Fp6 a;
	for (int i = 0; i < 6; i++) {
		a.get()[i] = i * i + 3;
	}
	CYBOZU_BENCH("Fp6Dbl::add  ", Fp6Dbl::add, x, x, x);
	CYBOZU_BENCH("Fp6Dbl::sub  ", Fp6Dbl::sub, x, x, y);
	CYBOZU_BENCH("Fp6Dbl::mul  ", Fp6Dbl::mul, x, a, a);
	CYBOZU_BENCH("Fp6Dbl::mod  ", Fp6Dbl::mod, a, x);
	CYBOZU_BENCH("Fp6Dbl::addNC", Fp6Dbl::addNC, x, x, x);
	CYBOZU_BENCH("Fp6Dbl::subNC", Fp6Dbl::subNC, x, x, y);
	CYBOZU_BENCH("Fp6Dbl::neg  ", Fp6Dbl::neg, x, x);
}
void benchAll(bool benchAll)
{
	benchFp();
	if (!benchAll) return;
	benchFp2();
	benchFpDbl();
	benchFp6();
	benchFp12();
	benchFp6Dbl();
	benchEcFp();
	benchEcFp2();
}

void testSquareRoot()
{
	puts("squreRoot");
	Fp x = genPx();
	Fp yy = x * x * x + 2;
	Fp y;
	if (Fp::squareRoot(y, yy)) {
		if (y != genPy()) {
			y = -y;
		}
		TEST_EQUAL(y, genPy());
	} else {
		puts("no squareRoot");
	}
	for (int i = 1; i < 100; i++) {
		x = i;
		if (Fp::squareRoot(y, x)) {
			TEST_EQUAL(y * y, x);
		}
	}
}
int main(int argc, char* argv[]) try
{
	argc--, argv++;
	int mode = -1;
	bool useMulx = true;
	bool allBench = false;

	while (argc > 0) {
		if (argc > 1 && strcmp(*argv, "-m") == 0) {
			argc--, argv++;
			mode = atoi(*argv);
		} else
		if (argc > 1 && strcmp(*argv, "-mulx") == 0) {
			argc--, argv++;
			useMulx = atoi(*argv) == 1;
		} else
		if (strcmp(*argv, "-all") == 0) {
			allBench = true;
		} else
		{
			printf("bn [-m (0|1)][-mulx (0|1)][-all]\n");
			return 1;
		}
		argc--, argv++;
	}

	Param::init(mode, useMulx);
	testParameters();
	testFp();
	testFp_add_sub();
	testDbl();
	testDbl_add_sub();
	testFpDbl_mul_mod();
	testFp2();
	testFp2Dbl();
	testFp2Dbl_add_sub(allBench);
	testFp2Dbl_mul_mod();
	testFp6();
	testFp6Dbl();
	testFp12();
	test_pointDblLineEval(allBench);
	test_pointAddLineEval(allBench);
	test_compression(allBench);
	test_compressed_square(allBench);
	test_compressed_fixed_power(allBench);
	test_sqru(allBench);
	test_FrobEndOnTwist_1(allBench);
	test_FrobEndOnTwist_2(allBench);
	testECDouble();
	testECAdd();
	testSquareRoot();
	testECOperationsG1(allBench);
	testECOperationsG2();
	testFpDbl_mul_mod();
	testPairingJac();
	test_final_exp();
	testPairing();
	test_multi(bn::CurveFp254BNb);
	benchAll(allBench);

	if (sclk.getCount()) printf("sclk:%.2fclk(%dtimes)\n", sclk.getClock() / double(sclk.getCount()), sclk.getCount());

	printf("err=%d(test=%d)\n", s_errNum, s_testNum);
	return 0;

} catch (std::exception& e) {
	fprintf(stderr, "std::exception %s\n", e.what());
	return 1;
}

/*
  Local Variables:
  c-basic-offset: 4
  indent-tabs-mode: t
  tab-width: 4
  End:
*/
#endif
