/*
	a new api of pairing for Java
*/
#include "../java/bn254_if.hpp"
#include <iostream>

#undef PUT
#define PUT(x) std::cout << #x "\t=" << (x).toString() << std::endl

static int errNum = 0;

void assertBool(const char *msg, bool b)
{
	if (b) {
		printf("%s : ok\n", msg);
	} else {
		printf("%s : ng\n", msg);
		errNum++;
	}
}

template<class T, class S>
void assertEqual(const char *msg, const T& a, const S& b)
{
	if (a.equals(b)) {
		printf("%s : ok\n", msg);
	} else {
		PUT(a);
		PUT(b);
		errNum++;
	}
}

struct G2 {
	const char *aa;
	const char *ab;
	const char *ba;
	const char *bb;
} g2c = {
	"12723517038133731887338407189719511622662176727675373276651903807414909099441",
	"4168783608814932154536427934509895782246573715297911553964171371032945126671",
	"13891744915211034074451795021214165905772212241412891944830863846330766296736",
	"7937318970632701341203597196594272556916396164729705624521405069090520231616",
};

int main()
{
	SystemInit();
	const Ec1 g1(-1, 1);
	const Ec2 g2(
		Fp2(Fp(g2c.aa), Fp(g2c.ab)),
		Fp2(Fp(g2c.ba), Fp(g2c.bb))
	);
	// assertBool g2 and g1 on curve
	assertBool("g1 is on EC", g1.isValid());
	assertBool("g2 is on twist EC", g2.isValid());
	puts("order of group");
	const Mpz& r = GetParamR();
	PUT(r);
	{
		Ec1 t = g1;
		t.mul(r);
		assertBool("orgder of g1 == r", t.isZero());
	}
	{
		Ec2 t = g2;
		t.mul(r);
		assertBool("order of g2 == r", t.isZero());
	}
	const Mpz a("123456789012345");
	const Mpz b("998752342342342342424242421");

	// scalar-multiplication sample
	{
		Mpz c = a;
		c.add(b);
		Ec1 Pa = g1; Pa.mul(a);
		Ec1 Pb = g1; Pb.mul(b);
		Ec1 Pc = g1; Pc.mul(c);
		Ec1 out = Pa;
		out.add(Pb);

		assertEqual("check g1 * c = g1 * a + g1 * b", Pc, out);
	}

	Fp12 e;
	// calc e : G2 x G1 -> G3 pairing
	e.pairing(g2, g1); // e = e(g2, g1)
	PUT(e);
	{
		Fp12 t = e;
		t.power(r);
		assertEqual("order of e == r", t, Fp12(1));
	}
	Ec2 g2a = g2;
	g2a.mul(a);
	Fp12 ea1;
	ea1.pairing(g2a, g1);
	Fp12 ea2 = e;
	ea2.power(a); // ea2 = e^a
	assertEqual("e(g2 * a, g1) = e(g2, g1)^a", ea1, ea2);

	Ec1 g1b = g1;
	g1b.mul(b);
	Fp12 eb1;
	eb1.pairing(g2, g1b); // eb1 = e(g2, g1b)
	Fp12 eb2 = e;
	eb2.power(b); // eb2 = e^b
	assertEqual("e(g2a, g1 * b) = e(g2, g1)^b", eb1, eb2);

	Ec1 q1 = g1;
	q1.mul(12345);
	assertBool("q1 is on EC", q1.isValid());
	Fp12 e1, e2;
	e1.pairing(g2, g1); // e1 = e(g2, g1)
	e2.pairing(g2, q1); // e2 = e(g2, q1)
	Ec1 q2 = g1;
	q2.add(q1);
	e.pairing(g2, q2); // e = e(g2, q2)
	e1.mul(e2);
	assertEqual("e = e1 * e2", e, e1);
	/*
		reduce one copy as the following
	*/
	g2a = g2;
	g2a.mul(a);
	g1b = g1;
	g1b.mul(b);
	Ec2 g2at = g2; g2at.mul(a);
	Ec1 g1bt = g1; g1bt.mul(b);
	assertEqual("g2a == g2 * a", g2a, g2at);
	assertEqual("g1b == g1 * b", g1b, g1bt);
	printf("errNum = %d\n", errNum);
}
