/*
	loop test
*/
#include "bn.h"
#include "test_point.hpp"

using namespace bn;
using namespace ecop;

int main()
{
#ifdef BN_SUPPORT_SNARK
	puts("snark");
	bn::CurveParam cp = bn::CurveSNARK1;
#else
	puts("fp254BNb");
	bn::CurveParam cp = bn::CurveFp254BNb;
#endif
	// init my library
	Param::init();
	// prepair a generator
	const Point& pt = selectPoint(cp);
	const Ec2 g2(
		Fp2(Fp(pt.g2.aa), Fp(pt.g2.ab)),
		Fp2(Fp(pt.g2.ba), Fp(pt.g2.bb))
	);
	const Ec1 g1(pt.g1.a, pt.g1.b);
	Fp12 e, ea, ea1, ea2;
	Ec2 g2a;
	Ec1 g1a;
	// calc e : G2 x G1 -> G3 pairing
	opt_atePairing(e, g2, g1); // e = e(g2, g1)
	mie::Vuint a("0x18b48dddfb2f81cc829b4b9acd393ccb1e90909aabe126bcdbe6a96438eaf313");
	for (int i = 0; i < 3000; i++) {
		ea = power(e, a);
		g1a = g1 * a;
		g2a = g2 * a;
		opt_atePairing(ea1, g2, g1a); // ea1 = e(g2, g1a)
		opt_atePairing(ea2, g2a, g1); // ea2 = e(g2a, g1)
		if (ea != ea1 || ea != ea2) {
			printf("ERR i=%d\n", i);
			PUT(a);
			PUT(ea);
			PUT(ea1);
			PUT(ea2);
			exit(1);
		}
		a -= 1;
	}
	puts("ok");
}
